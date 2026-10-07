import Foundation
import Observation

@MainActor
@Observable
final class ApplicationStore {
    private(set) var apps: [ApplicationBinding] = []
    var errorMessage: String?
    private let store: ConfigurationStore
    private var loadFailed = false
    var didChange: (() -> Void)?
    var validateEdit: (([ApplicationBinding]) throws -> Void)?

    init(store: ConfigurationStore) {
        self.store = store
        do { apps = try store.load() }
        catch {
            loadFailed = true
            errorMessage = error.localizedDescription
        }
    }

    /// 先保存再更新状态；编辑失败时保留内存列表与已注册的快捷键。
    @discardableResult
    func commit(_ updated: [ApplicationBinding]) -> Bool {
        do {
            try validateEdit?(updated)
            if loadFailed, FileManager.default.fileExists(atPath: store.url.path) {
                let backup = store.url.appendingPathExtension("backup-\(UUID().uuidString)")
                try FileManager.default.copyItem(at: store.url, to: backup)
            }
            try store.save(updated)
            loadFailed = false
            apps = updated
            didChange?()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func add(_ url: URL) {
        guard let bundle = Bundle(url: url), url.pathExtension.lowercased() == "app" else {
            errorMessage = ConfigurationError.invalidApplication.localizedDescription
            return
        }
        guard !apps.contains(where: { $0.applicationURL.standardizedFileURL == url.standardizedFileURL }) else { return }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        commit(apps + [ApplicationBinding(applicationURL: url, displayName: name)])
    }

    func setShortcut(_ shortcut: Hotkey?, for id: UUID) {
        var updated = apps
        guard let index = updated.firstIndex(where: { $0.id == id }) else { return }
        updated[index].shortcut = shortcut
        commit(updated)
    }

    func delete(_ id: UUID) { commit(apps.filter { $0.id != id }) }

    func move(from offsets: IndexSet, to destination: Int) {
        var updated = apps
        let moving = offsets.map { updated[$0] }
        for index in offsets.reversed() { updated.remove(at: index) }
        updated.insert(contentsOf: moving, at: destination - offsets.filter { $0 < destination }.count)
        commit(updated)
    }

    func importFile(_ url: URL) {
        do { commit(try store.decode(Data(contentsOf: url))) }
        catch { errorMessage = error.localizedDescription }
    }

    func exportFile(_ url: URL) {
        do { try ConfigurationStore(url: url).save(apps) }
        catch { errorMessage = error.localizedDescription }
    }
}
