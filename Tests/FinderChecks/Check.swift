import AppKit

@main struct FinderCheck {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
        let application = directory.appendingPathComponent("Otty.app")
        let contents = application.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": "io.appmakes.otty", "CFBundleExecutable": "otty-cli",
                                   "CFBundleName": "Finder 隔离验证", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        let executable = contents.appendingPathComponent("MacOS/otty-cli")
        let log = directory.appendingPathComponent("arguments.txt")
        // 测试脚本只记录参数，不启动真实终端或执行路径中的内容。
        let script = "#!/bin/sh\noutput=\"$(dirname \"$0\")/../../../arguments.txt\"\nprintf '%s\\n' \"$@\" >> \"$output\"\n"
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let selected = directory.appendingPathComponent("中文 空格 &'\";$(touch 不应执行)")
        try FileManager.default.createDirectory(at: selected, withIntermediateDirectories: true)
        let first = selected.appendingPathComponent("first.swift")
        let second = selected.appendingPathComponent("second.swift")
        try Data().write(to: first)
        try Data().write(to: second)
        let app = FinderApplication(applicationURL: application, displayName: "隔离终端", bundleIdentifier: "io.appmakes.otty")
        var configuration = FinderConfiguration()
        configuration.terminal = app
        let service = FinderOpeningService(isApplicationRunning: { _ in false })
        let snapshot = directory.appendingPathComponent("snapshot.json")
        try service.publish(configuration, snapshotURL: snapshot)
        let published = try FinderConfigurationFile(url: snapshot).load()
        precondition(published == configuration, "共享菜单与选择不一致")
        let request = FinderIntegration.requestURL(action: .terminal, paths: [selected, first, second])!
        try await service.open(request, configuration: configuration)
        let arguments = try String(contentsOf: log, encoding: .utf8)
        precondition(arguments == "open\n\(selected.standardizedFileURL.path)\n", "目录参数错误或多选未去重")
        // 使用隔离 CLI 返回窗口列表，验证复用窗口、标签页目录和无窗口时的启动行为。
        let warmScript = "#!/bin/sh\nif [ \"$1\" = window ] && [ \"$2\" = list ]; then printf '%s' '{\"ok\":true,\"data\":[{\"id\":\"test-window\"}]}'; exit 0; fi\n" + script.split(separator: "\n").dropFirst().joined(separator: "\n") + "\n"
        try Data(warmScript.utf8).write(to: executable)
        let warmService = FinderOpeningService(isApplicationRunning: { _ in true })
        try await warmService.open(request, configuration: configuration, terminalMode: .newTab)
        let withTab = try String(contentsOf: log, encoding: .utf8)
        precondition(withTab == arguments + "tab\nnew\n--cwd\n\(selected.standardizedFileURL.path)\n--window\ntest-window\nwindow\nfocus\n--window\ntest-window\n", "已有窗口未使用标签页")
        try await warmService.open(request, configuration: configuration, terminalMode: .newWindow)
        let explicitWindow = try String(contentsOf: log, encoding: .utf8)
        precondition(explicitWindow == withTab + arguments, "新窗口选项仍使用了标签页")
        try Data(warmScript.replacingOccurrences(of: "[{\"id\":\"test-window\"}]", with: "[]").utf8).write(to: executable)
        try await warmService.open(request, configuration: configuration, terminalMode: .newTab)
        let withWindow = try String(contentsOf: log, encoding: .utf8)
        precondition(withWindow == explicitWindow + arguments, "无窗口时未创建首个窗口")
        configuration.terminal = nil
        try await service.open(request, configuration: configuration)
        let unchanged = try String(contentsOf: log, encoding: .utf8)
        precondition(unchanged == withWindow, "已关闭的菜单仍可打开应用")
        configuration.terminal = app
        let missing = FinderIntegration.requestURL(action: .terminal, paths: [directory.appendingPathComponent("missing")])!
        do {
            try await service.open(missing, configuration: configuration)
            preconditionFailure("缺失路径未被拒绝")
        } catch FinderOpeningError.pathUnavailable {}
        try Data("#!/bin/sh\nexit 7\n".utf8).write(to: executable)
        do {
            try await service.open(request, configuration: configuration)
            preconditionFailure("终端执行错误未被报告")
        } catch FinderOpeningError.commandFailed(let status) { precondition(status == 7) }
        let editor = directory.appendingPathComponent("Code.app")
        let editorContents = editor.appendingPathComponent("Contents")
        let editorCLI = editorContents.appendingPathComponent("Resources/app/bin/code")
        try FileManager.default.createDirectory(at: editorCLI.deletingLastPathComponent(), withIntermediateDirectories: true)
        let editorPlist: [String: Any] = ["CFBundleIdentifier": "com.microsoft.VSCode", "CFBundleExecutable": "code", "CFBundleName": "隔离编辑器", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: editorPlist, format: .xml, options: 0).write(to: editorContents.appendingPathComponent("Info.plist"))
        let editorLog = editorContents.appendingPathComponent("editor-arguments.txt")
        let editorScript = "#!/bin/sh\noutput=\"$(dirname \"$0\")/../../../editor-arguments.txt\"\nprintf '%s\\n' \"$@\" >> \"$output\"\n"
        try Data(editorScript.utf8).write(to: editorCLI)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: editorCLI.path)
        configuration.editor = FinderApplication(applicationURL: editor, displayName: "隔离编辑器", bundleIdentifier: "com.microsoft.VSCode")
        let editorRequest = FinderIntegration.requestURL(action: .editor, paths: [first])!
        try await service.open(editorRequest, configuration: configuration, editorMode: .currentWindow)
        try await service.open(editorRequest, configuration: configuration, editorMode: .newWindow)
        let editorArguments = try String(contentsOf: editorLog, encoding: .utf8)
        precondition(editorArguments == "--reuse-window\n--\n\(first.path)\n--new-window\n--\n\(first.path)\n", "编辑器选项或特殊文件路径未正确传递")
        print("通过：隔离菜单发布、特殊路径、多选去重、复用标签页、终端新窗口、编辑器当前窗口与新窗口、无窗口启动、关闭菜单、缺失路径与终端执行错误")
    }
}
