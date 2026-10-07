"""使用临时工程和模拟应用验证开发会话，不注册系统扩展或修改真实配置。"""

import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest


class DevSessionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="betteropen-dev-check-")
        self.root = Path(self.directory.name)
        (self.root / "Scripts").mkdir()
        shutil.copyfile(Path(__file__).resolve().parents[2] / "Scripts/dev.py", self.root / "Scripts/dev.py")
        (self.root / "betteropen").mkdir()
        self.source = self.root / "betteropen/Example.swift"
        self.source.write_text("// 初始源码\n")
        self.events = self.root / "events.log"
        self.output = (self.root / "session.log").open("w")
        self.process = None
        self.install_executable("build.sh", """
import pathlib, time
root = pathlib.Path.cwd()
with (root / 'events.log').open('a') as log:
    log.write('build\\n')
if (root / 'slow').exists():
    time.sleep(30)
raise SystemExit(1 if (root / 'fail').exists() else 0)
""")
        self.install_executable(".products/DerivedData/Build/Products/Debug/BetterOpen Dev.app/Contents/MacOS/BetterOpen Dev", """
import os, pathlib, signal, time
events = pathlib.Path.cwd() / 'events.log'
def record(text):
    with events.open('a') as log:
        log.write(text + '\\n')
def stop(number, frame):
    record('stop')
    raise SystemExit(0)
signal.signal(signal.SIGTERM, stop)
record('start:' + str(os.getpid()))
while True:
    time.sleep(0.1)
""")

    def tearDown(self):
        if self.process is not None and self.process.poll() is None:
            self.process.send_signal(signal.SIGTERM)
            self.process.wait(timeout=8)
        self.output.close()
        self.directory.cleanup()

    def install_executable(self, name, source):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"#!{sys.executable}\n" + source)
        path.chmod(0o755)

    def start(self, *args):
        # 仅替换系统扩展注册；构建、应用、监听和信号均使用真实子进程。
        driver = """
import importlib.util, sys
spec = importlib.util.spec_from_file_location('development', 'Scripts/dev.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
original = module.DevSession.run_command
def command(self, argv, output=None):
    return original(self, argv, output) if argv[0].endswith('build.sh') else True
module.DevSession.run_command = command
raise SystemExit(module.main())
"""
        self.process = subprocess.Popen(
            [sys.executable, "-c", driver, *args], cwd=self.root,
            env={**os.environ, "BETTEROPEN_BUILD_DIR": str(self.root / ".products")},
            stdout=self.output, stderr=subprocess.STDOUT, start_new_session=True,
        )

    def lines(self):
        return self.events.read_text().splitlines() if self.events.exists() else []

    def wait_for(self, predicate):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.05)
        self.fail((self.root / "session.log").read_text() + "\n" + str(self.lines()))

    def change_source(self):
        with self.source.open("a") as source:
            source.write("// 保存源码\n")

    def test_reload_failure_recovery_and_ctrl_c(self):
        self.start()
        self.wait_for(lambda: sum(line.startswith("start:") for line in self.lines()) == 1)
        (self.root / "fail").touch()
        self.change_source()
        self.wait_for(lambda: self.lines().count("build") == 2)
        self.assertIn("stop", self.lines())
        self.assertIsNone(self.process.poll())
        (self.root / "fail").unlink()
        self.change_source()
        self.wait_for(lambda: sum(line.startswith("start:") for line in self.lines()) == 2)
        self.process.send_signal(signal.SIGINT)
        self.assertEqual(self.process.wait(timeout=8), 0)
        self.assertEqual(self.lines().count("stop"), 2)

    def test_ctrl_c_during_build(self):
        (self.root / "slow").touch()
        self.start()
        self.wait_for(lambda: "build" in self.lines())
        self.process.send_signal(signal.SIGINT)
        self.assertEqual(self.process.wait(timeout=8), 0)
        self.assertFalse(any(line.startswith("start:") for line in self.lines()))

    def test_no_watch_waits_for_app_exit(self):
        self.start("--no-watch")
        self.wait_for(lambda: any(line.startswith("start:") for line in self.lines()))
        self.change_source()
        time.sleep(0.8)
        self.assertEqual(self.lines().count("build"), 1)
        self.assertIsNone(self.process.poll())
        app_pid = int(next(line.split(":")[1] for line in self.lines() if line.startswith("start:")))
        os.kill(app_pid, signal.SIGTERM)
        self.assertEqual(self.process.wait(timeout=8), 0)


if __name__ == "__main__":
    unittest.main()
