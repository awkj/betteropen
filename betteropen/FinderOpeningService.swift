import AppKit

@MainActor
final class FinderOpeningService {
    private let isApplicationRunning: (String) -> Bool

    init(isApplicationRunning: @escaping (String) -> Bool = { identifier in
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == identifier }
    }) {
        self.isApplicationRunning = isApplicationRunning
    }

    private struct OttyWindows: Decodable {
        struct Window: Decodable { let id: String; let focused: Bool? }
        let ok: Bool
        let data: [Window]
    }

    func publish(_ configuration: FinderConfiguration, snapshotURL: URL? = nil) throws {
        if let snapshotURL {
            try FinderConfigurationFile(url: snapshotURL).save(configuration)
            return
        }
        try FinderSharedConfiguration.save(configuration)
    }

    func open(_ request: URL, configuration: FinderConfiguration,
              editorMode: FinderOpeningMode = .automatic, terminalMode: FinderOpeningMode = .automatic) async throws {
        guard let request = FinderIntegration.parseRequest(request), configuration.actions.contains(request.action) else { return }
        guard request.paths.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) else {
            throw FinderOpeningError.pathUnavailable
        }
        if request.action == .copyPath {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(request.paths.map(\.path).joined(separator: "\n"), forType: .string)
            return
        }
        guard let app = configuration.application(for: request.action),
              let bundle = Bundle(url: app.applicationURL), bundle.bundleIdentifier == app.bundleIdentifier else {
            throw FinderOpeningError.applicationUnavailable
        }
        let requestedMode = request.action == .editor ? editorMode : terminalMode
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let mode = FinderOpeningMode.available(for: app.bundleIdentifier, version: version).contains(requestedMode) ? requestedMode : .automatic
        var hasExistingWindow = isApplicationRunning(app.bundleIdentifier)
        var ottyWindowID: String?
        if app.bundleIdentifier == "io.appmakes.otty", mode == .newTab, isApplicationRunning(app.bundleIdentifier) {
            let data = try await Self.run(app.applicationURL.appendingPathComponent("Contents/MacOS/otty-cli"),
                                          arguments: ["window", "list", "--json"])
            let windows = try JSONDecoder().decode(OttyWindows.self, from: data)
            hasExistingWindow = windows.ok && !windows.data.isEmpty
            ottyWindowID = windows.data.first(where: { $0.focused == true })?.id ?? windows.data.first?.id
        }
        let plans = FinderLaunchPlan.make(application: app.applicationURL, bundleIdentifier: bundle.bundleIdentifier,
                                          paths: request.paths, mode: mode, hasExistingWindow: hasExistingWindow) {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        for plan in plans {
            switch plan {
            case .documents(let urls):
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                _ = try await NSWorkspace.shared.open(urls, withApplicationAt: app.applicationURL, configuration: configuration)
            case .command(let executable, let arguments):
                var commandArguments = arguments
                let ottyTab = app.bundleIdentifier == "io.appmakes.otty" && arguments.starts(with: ["tab", "new"])
                if ottyTab {
                    if ottyWindowID == nil {
                        let data = try await Self.run(executable, arguments: ["window", "list", "--json"])
                        let windows = try JSONDecoder().decode(OttyWindows.self, from: data)
                        ottyWindowID = windows.data.first(where: { $0.focused == true })?.id ?? windows.data.first?.id
                    }
                    if let ottyWindowID { commandArguments += ["--window", ottyWindowID] }
                }
                _ = try await Self.run(executable, arguments: commandArguments)
                if ottyTab, let ottyWindowID {
                    // CLI 创建标签页后显式显示所在窗口，避免打开结果留在后台。
                    _ = try await Self.run(executable, arguments: ["window", "focus", "--window", ottyWindowID])
                }
            }
        }
    }

    /// 独立参数保留特殊路径；并行读取输出，避免管道写满后阻塞终端命令。
    nonisolated private static func run(_ executable: URL, arguments: [String]) async throws -> Data {
        let process = Process()
        let output = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        let reader = Task.detached { output.fileHandleForReading.readDataToEndOfFile() }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                process.terminationHandler = { process in
                    if process.terminationStatus == 0 { continuation.resume() }
                    else { continuation.resume(throwing: FinderOpeningError.commandFailed(process.terminationStatus)) }
                }
                do {
                    try process.run()
                    output.fileHandleForWriting.closeFile()
                } catch {
                    process.terminationHandler = nil
                    output.fileHandleForWriting.closeFile()
                    continuation.resume(throwing: error)
                }
            }
            return await reader.value
        } catch {
            _ = await reader.value
            throw error
        }
    }
}

nonisolated enum FinderOpeningError: LocalizedError {
    case applicationUnavailable, pathUnavailable, commandFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .applicationUnavailable:
            NSLocalizedString("This application is no longer available. Remove it and add its new location.", comment: "")
        case .pathUnavailable:
            NSLocalizedString("The selected file or folder is no longer available.", comment: "")
        case .commandFailed(let status):
            String(format: NSLocalizedString("The application could not open the folder (exit code %d).", comment: ""), status)
        }
    }
}
