import Foundation

nonisolated struct ApplicationBinding: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let applicationURL: URL
    var displayName: String
    var shortcut: Hotkey?

    init(id: UUID = UUID(), applicationURL: URL, displayName: String, shortcut: Hotkey? = nil) {
        self.id = id
        self.applicationURL = applicationURL.standardizedFileURL
        self.displayName = displayName
        self.shortcut = shortcut
    }
}

/// 只接受当前格式，版本字段用于拒绝未知结构，不执行历史数据迁移。
nonisolated struct ConfigurationDocument: Codable {
    static let currentVersion = 2
    let version: Int
    let applications: [ApplicationBinding]

    init(applications: [ApplicationBinding]) {
        version = Self.currentVersion
        self.applications = applications
    }
}

nonisolated enum ConfigurationError: LocalizedError {
    case invalidApplication, invalidShortcut, duplicateApplication, duplicateShortcut, unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .invalidApplication: NSLocalizedString("The configuration contains an invalid application.", comment: "")
        case .invalidShortcut: NSLocalizedString("The configuration contains an invalid shortcut.", comment: "")
        case .duplicateApplication: NSLocalizedString("The configuration contains duplicate applications.", comment: "")
        case .duplicateShortcut: NSLocalizedString("This shortcut is already assigned to another application.", comment: "")
        case .unsupportedFormat: NSLocalizedString("This configuration format is not supported.", comment: "")
        }
    }
}

nonisolated struct ConfigurationStore {
    let url: URL
    // 注入写入函数，以便测试保存失败的场景，不接触用户的真实配置。
    var write: (Data, URL) throws -> Void = { data, url in
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    static func validate(_ applications: [ApplicationBinding]) throws {
        var ids = Set<UUID>()
        var paths = Set<URL>()
        var shortcuts = Set<Hotkey>()
        for app in applications {
            let path = app.applicationURL.standardizedFileURL
            guard path.isFileURL, path.pathExtension.lowercased() == "app", !app.displayName.isEmpty else {
                throw ConfigurationError.invalidApplication
            }
            guard ids.insert(app.id).inserted, paths.insert(path).inserted else {
                throw ConfigurationError.duplicateApplication
            }
            guard let shortcut = app.shortcut else { continue }
            guard shortcut.isValid else { throw ConfigurationError.invalidShortcut }
            guard shortcuts.insert(shortcut).inserted else { throw ConfigurationError.duplicateShortcut }
        }
    }

    func load() throws -> [ApplicationBinding] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try decode(Data(contentsOf: url))
    }

    func decode(_ data: Data) throws -> [ApplicationBinding] {
        // 先校验版本，避免旧结构的字段缺失掩盖“不支持此格式”的提示。
        let decoder = JSONDecoder()
        let header = try decoder.decode(ConfigurationHeader.self, from: data)
        guard header.version == ConfigurationDocument.currentVersion else { throw ConfigurationError.unsupportedFormat }
        let document = try decoder.decode(ConfigurationDocument.self, from: data)
        try Self.validate(document.applications)
        return document.applications
    }

    func save(_ applications: [ApplicationBinding]) throws {
        try Self.validate(applications)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try write(encoder.encode(ConfigurationDocument(applications: applications)), url)
    }
}

nonisolated private struct ConfigurationHeader: Decodable {
    let version: Int
}
