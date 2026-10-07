#!/usr/bin/env python3
"""前台开发会话：监听源码、重新构建，并管理本会话启动的进程。"""

import argparse
import fcntl
import os
from pathlib import Path
import signal
import subprocess
import time


def message(text):
    print(text, flush=True)


class DevSession:
    def __init__(self, root, build_dir, watch, verbose):
        self.root = root
        self.build_dir = build_dir
        self.watch = watch
        self.verbose = verbose
        self.stopped = False
        self.child = None
        self.app = None
        self.app_log = None

    def request_stop(self, _number, _frame):
        self.stopped = True

    def snapshot(self):
        files = []
        for name in ("betteropen", "betteropenfinder", "betteropen.xcodeproj", "betteropen.xcworkspace"):
            files.extend((self.root / name).rglob("*"))
        files.extend(self.root / name for name in ("Build.xcconfig", "Package.swift", "build.sh"))
        result = {}
        for path in files:
            if "xcuserdata" in path.parts or path.name == ".DS_Store":
                continue
            try:
                if path.is_file():
                    stat = path.stat()
                    result[str(path)] = (stat.st_mtime_ns, stat.st_size)
            except FileNotFoundError:
                # 编辑器可能通过临时文件原子替换源码，下一轮会重新读取。
                continue
        return result

    @staticmethod
    def stop_process(process):
        if process is None:
            return
        # 每个子任务使用独立进程组，退出构建时一并清理编译器等后代。
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()

    def stop_app(self):
        self.stop_process(self.app)
        self.app = None
        if self.app_log is not None:
            self.app_log.close()
            self.app_log = None

    def run_command(self, command, output=None):
        if self.stopped:
            return False
        self.child = subprocess.Popen(
            command, cwd=self.root, start_new_session=True,
            stdout=output, stderr=subprocess.STDOUT,
        )
        while self.child.poll() is None and not self.stopped:
            time.sleep(0.1)
        if self.stopped:
            self.stop_process(self.child)
        succeeded = self.child.wait() == 0
        self.child = None
        return succeeded and not self.stopped

    def rebuild(self):
        self.stop_app()
        if not self.run_command([str(self.root / "build.sh"), "debug"]):
            return False
        app_path = self.build_dir / "DerivedData/Build/Products/Debug/BetterOpen Dev.app"
        # 注册本次构建，避免 Finder 继续加载旧的扩展产物。
        with (self.build_dir / "registration.log").open("w") as log:
            for command in (
                ["/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister", "-f", str(app_path)],
                ["pluginkit", "-a", str(app_path / "Contents/PlugIns/BetterOpenFinder.appex")],
            ):
                if not self.run_command(command, log):
                    if not self.stopped:
                        message(f"开发版注册失败，日志：{self.build_dir / 'registration.log'}")
                    return False
        if self.stopped:
            return False
        self.app_log = (self.build_dir / "dev.log").open("a")
        self.app = subprocess.Popen(
            [str(app_path / "Contents/MacOS/BetterOpen Dev"), "--preview", "--dev-session"],
            cwd=self.root, start_new_session=True,
            stdout=None if self.verbose else self.app_log, stderr=subprocess.STDOUT,
        )
        message(f"开发版已启动（PID {self.app.pid}），按 Ctrl+C 退出。")
        return True

    def run(self):
        previous = self.snapshot()
        succeeded = self.rebuild()
        if self.stopped:
            return 0
        if not succeeded and not self.watch:
            return 1
        if self.watch:
            message("正在监听 Swift、资源和项目配置；保存后自动构建重启。")
        pending_since = None
        while not self.stopped:
            if self.app is not None and self.app.poll() is not None:
                code = self.app.returncode
                self.stop_app()
                if not self.watch:
                    return code if code >= 0 else 1
                message(f"开发版已退出（状态 {code}）；保存源码后重新启动。运行日志：{self.build_dir / 'dev.log'}")
            if self.watch:
                current = self.snapshot()
                if current != previous:
                    previous = current
                    pending_since = time.monotonic()
                elif pending_since is not None and time.monotonic() - pending_since >= 0.4:
                    pending_since = None
                    message("检测到文件变更，正在重新构建…")
                    self.rebuild()
                    if not self.stopped:
                        message("继续监听文件变更。")
            time.sleep(0.2)
        return 0


def main():
    parser = argparse.ArgumentParser(description="前台运行 BetterOpen 开发版，保存源码后自动构建重启。", add_help=False)
    parser.add_argument("-h", "--help", action="help", help="显示帮助并退出")
    parser.add_argument("--no-watch", action="store_true", help="只构建并启动一次，不监听文件变更")
    parser.add_argument("--verbose", action="store_true", help="在终端显示完整构建输出和应用日志")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    build_dir = Path(os.environ.get("BETTEROPEN_BUILD_DIR", root / ".build-release")).resolve()
    build_dir.mkdir(parents=True, exist_ok=True)
    verbose = args.verbose or os.environ.get("BETTEROPEN_VERBOSE") == "1"
    if verbose:
        os.environ["BETTEROPEN_VERBOSE"] = "1"
    with (build_dir / "dev.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            message("此构建目录已有开发会话，请先在原终端按 Ctrl+C 退出。")
            return 1
        session = DevSession(root, build_dir, not args.no_watch, verbose)
        for number in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            signal.signal(number, session.request_stop)
        message(f"构建日志：{build_dir / 'build.log'}；运行日志：{build_dir / 'dev.log'}")
        try:
            return session.run()
        finally:
            session.stop_process(session.child)
            session.stop_app()
            message("开发会话已结束。")


if __name__ == "__main__":
    raise SystemExit(main())
