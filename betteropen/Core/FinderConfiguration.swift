import Foundation
import Observation
import OSLog

nonisolated enum FinderAction: String, Codable, CaseIterable, Sendable {
    case copyPath, editor, terminal
}

nonisolated struct FinderApplication: Codable, Equatable, Identifiable, Sendable {
    let applicationURL: URL
    let displayName: String
    let bundleIdentifier: String
    var id: URL { applicationURL }
}

nonisolated struct FinderConfiguration: Codable, Equatable, Sendable {
    var version = 1
    var copyPathEnabled = true
    var editor: FinderApplication?
    var terminal: FinderApplication?

    func application(for action: FinderAction) -> FinderApplication? {
        switch action {
        case .editor: editor
        case .terminal: terminal
        case .copyPath: nil
        }
    }

    /// 总开关只清空发布给 Finder 的操作，保留用户的应用选择。
    func menuConfiguration(enabled: Bool) -> Self {
        guard !enabled else { return self }
        var menu = self
        menu.copyPathEnabled = false
        menu.editor = nil
        menu.terminal = nil
        return menu
    }

    var actions: [FinderAction] {
        FinderAction.allCases.filter {
            $0 == .copyPath ? copyPathEnabled : application(for: $0) != nil
        }
    }
}

nonisolated struct FinderConfigurationFile {
    let url: URL
    var write: (Data, URL) throws -> Void = { data, url in
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    func load() throws -> FinderConfiguration {
        guard FileManager.default.fileExists(atPath: url.path) else { return .init() }
        let configuration = try JSONDecoder().decode(FinderConfiguration.self, from: Data(contentsOf: url))
        try Self.validate(configuration)
        return configuration
    }

    static func validate(_ configuration: FinderConfiguration) throws {
        guard configuration.version == 1 else { throw ConfigurationError.unsupportedFormat }
        for app in [configuration.editor, configuration.terminal].compactMap({ $0 }) {
            guard app.applicationURL.isFileURL, app.applicationURL.pathExtension.lowercased() == "app",
                  !app.displayName.isEmpty, !app.bundleIdentifier.isEmpty else { throw ConfigurationError.invalidApplication }
        }
    }

    func save(_ configuration: FinderConfiguration) throws {
        try Self.validate(configuration)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try write(encoder.encode(configuration), url)
    }
}

@MainActor
@Observable
final class FinderSettingsStore {
    private(set) var configuration = FinderConfiguration()
    var errorMessage: String?
    var didChange: (() -> Void)?
    private let file: FinderConfigurationFile
    private var loadFailed = false
    let needsInitialSelection: Bool

    init(file: FinderConfigurationFile) {
        self.file = file
        needsInitialSelection = !FileManager.default.fileExists(atPath: file.url.path)
        do { configuration = try file.load() }
        catch { loadFailed = true; errorMessage = error.localizedDescription }
    }

    @discardableResult
    func commit(_ value: FinderConfiguration) -> Bool {
        do {
            if loadFailed, FileManager.default.fileExists(atPath: file.url.path) {
                try FileManager.default.copyItem(at: file.url, to: file.url.appendingPathExtension("backup-\(UUID().uuidString)"))
            }
            try file.save(value)
            loadFailed = false
            configuration = value
            didChange?()
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func select(_ application: FinderApplication?, for action: FinderAction) {
        var updated = configuration
        switch action {
        case .editor: updated.editor = application
        case .terminal: updated.terminal = application
        case .copyPath: return
        }
        commit(updated)
    }

    func setCopyPathEnabled(_ enabled: Bool) {
        var updated = configuration
        updated.copyPathEnabled = enabled
        commit(updated)
    }
}

/// 扩展只读取专用菜单目录，不读取快捷键配置或自动生成默认菜单。
nonisolated enum FinderSharedConfiguration {
    static func decode(_ data: Data?) -> FinderConfiguration? {
        guard let data, let configuration = try? JSONDecoder().decode(FinderConfiguration.self, from: data),
              (try? FinderConfigurationFile.validate(configuration)) != nil else { return nil }
        return configuration
    }

    static func load() -> FinderConfiguration? {
        do { return decode(try Data(contentsOf: FinderIntegration.snapshotURL)) }
        catch {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterOpen", category: "FinderConfiguration")
                .error("无法读取 Finder 菜单配置：\(FinderIntegration.snapshotURL.path, privacy: .public)，\(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func save(_ configuration: FinderConfiguration) throws {
        try FinderConfigurationFile(url: FinderIntegration.snapshotURL).save(configuration)
    }
}
