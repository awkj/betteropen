import Foundation
import Testing
@testable import BetterOpenCore

@Suite("配置与快捷键回归测试")
struct ConfigurationTests {
    let calculator = ApplicationBinding(applicationURL: URL(fileURLWithPath: "/Applications/Calculator.app"), displayName: "Calculator")

    @Test func currentDocumentRoundTripPreservesIdentityAndEmptyShortcut() throws {
        let app = ApplicationBinding(applicationURL: calculator.applicationURL, displayName: "计算器")
        let data = try JSONEncoder().encode(ConfigurationDocument(applications: [app]))
        let records = try ConfigurationStore(url: URL(fileURLWithPath: "/unused")).decode(data)
        #expect(records == [app])
        #expect(records[0].shortcut == nil)
    }

    @Test func oldProjectFormatIsRejected() {
        let json = #"[{"appBundleURL":"file:///Applications/Calculator.app/","appDisplayName":"计算器","shortcut":"cmd+a"}]"#
        #expect(throws: DecodingError.self) {
            try ConfigurationStore(url: URL(fileURLWithPath: "/unused")).decode(Data(json.utf8))
        }
    }

    @Test func unsupportedVersionIsRejected() {
        let json = #"{"version":999,"applications":[]}"#
        #expect(throws: ConfigurationError.unsupportedFormat) {
            try ConfigurationStore(url: URL(fileURLWithPath: "/unused")).decode(Data(json.utf8))
        }
    }

    @Test func missingApplicationIsPreserved() throws {
        try ConfigurationStore.validate([calculator])
    }

    @Test(arguments: [Hotkey(keyCode: -1, modifiers: 256), Hotkey(keyCode: 128, modifiers: 256),
                      Hotkey(keyCode: 0, modifiers: -1), Hotkey(keyCode: 0, modifiers: 1024)])
    func malformedHotkeysAreRejected(_ hotkey: Hotkey) {
        let app = ApplicationBinding(applicationURL: calculator.applicationURL, displayName: "计算器", shortcut: hotkey)
        #expect(throws: ConfigurationError.invalidShortcut) { try ConfigurationStore.validate([app]) }
    }

    @Test func zeroKeyCodeAndAllModifiersRoundTrip() throws {
        let app = ApplicationBinding(applicationURL: calculator.applicationURL, displayName: "计算器",
                                     shortcut: Hotkey(keyCode: 0, modifiers: 6912))
        let data = try JSONEncoder().encode(ConfigurationDocument(applications: [app]))
        #expect(try ConfigurationStore(url: URL(fileURLWithPath: "/unused")).decode(data) == [app])
    }

    @Test func duplicateHotkeysAreRejected() {
        let hotkey = Hotkey(keyCode: 0, modifiers: 2304)
        let one = ApplicationBinding(applicationURL: calculator.applicationURL, displayName: "One", shortcut: hotkey)
        let two = ApplicationBinding(applicationURL: URL(fileURLWithPath: "/Applications/Other.app"),
                                     displayName: "Two", shortcut: hotkey)
        #expect(throws: ConfigurationError.duplicateShortcut) { try ConfigurationStore.validate([one, two]) }
    }

    @Test func duplicateApplicationPathsAreRejected() {
        let duplicate = ApplicationBinding(applicationURL: calculator.applicationURL, displayName: "另一份计算器")
        #expect(throws: ConfigurationError.duplicateApplication) { try ConfigurationStore.validate([calculator, duplicate]) }
    }

    @Test func duplicateIdentifiersAreRejected() {
        let duplicate = ApplicationBinding(id: calculator.id, applicationURL: URL(fileURLWithPath: "/Applications/Other.app"),
                                           displayName: "其他应用")
        #expect(throws: ConfigurationError.duplicateApplication) { try ConfigurationStore.validate([calculator, duplicate]) }
    }

    @Test func realAtomicFileRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigurationStore(url: directory.appendingPathComponent("nested/configuration.json"))
        #expect(try store.load().isEmpty)
        try store.save([calculator])
        #expect(try store.load() == [calculator])
    }

    @Test @MainActor func failedWriteLeavesMemoryAndRegistrationsUntouched() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("configuration.json")
        try ConfigurationStore(url: url).save([calculator])
        let store = ConfigurationStore(url: url, write: { _, _ in throw CocoaError(.fileWriteNoPermission) })
        let manager = ApplicationStore(store: store)
        var callbackCount = 0
        manager.didChange = { callbackCount += 1 }
        #expect(!manager.commit([]))
        #expect(manager.apps == [calculator])
        #expect(callbackCount == 0)
        #expect(manager.errorMessage != nil)
        #expect(try ConfigurationStore(url: url).load() == [calculator])
    }

    @Test @MainActor func importingRefreshesLiveRegistrationsExactlyOnce() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = ApplicationStore(store: ConfigurationStore(url: directory.appendingPathComponent("configuration.json")))
        let incoming = directory.appendingPathComponent("incoming.json")
        try ConfigurationStore(url: incoming).save([calculator])
        var count = 0
        manager.didChange = { count += 1 }
        manager.importFile(incoming)
        #expect(manager.apps == [calculator])
        #expect(count == 1)
    }

    @Test @MainActor func failedImportPreservesExistingConfiguration() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigurationStore(url: directory.appendingPathComponent("configuration.json"))
        try store.save([calculator])
        let manager = ApplicationStore(store: store)
        let invalid = directory.appendingPathComponent("bad.json")
        try Data("invalid".utf8).write(to: invalid)
        var count = 0
        manager.didChange = { count += 1 }
        manager.importFile(invalid)
        #expect(manager.apps == [calculator])
        #expect(count == 0)
        #expect(try store.load() == [calculator])
    }

    @Test @MainActor func unreadableOriginalIsBackedUpBeforeReplacement() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = ConfigurationStore(url: directory.appendingPathComponent("configuration.json"))
        let original = Data("broken json".utf8)
        try original.write(to: store.url)
        let manager = ApplicationStore(store: store)
        #expect(manager.errorMessage != nil)
        #expect(manager.commit([calculator]))
        let backups = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("configuration.json.backup-") }
        #expect(backups.count == 1)
        #expect(try Data(contentsOf: backups[0]) == original)
    }

    @Test @MainActor func rejectedEditLeavesExistingStateAndHotkeysUntouched() {
        let manager = ApplicationStore(store: ConfigurationStore(url: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("configuration.json")))
        manager.validateEdit = { _ in throw ConfigurationError.invalidShortcut }
        var count = 0
        manager.didChange = { count += 1 }
        #expect(!manager.commit([calculator]))
        #expect(manager.apps.isEmpty)
        #expect(count == 0)
    }

}
