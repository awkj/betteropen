import AppKit
import Observation
import ServiceManagement

@MainActor
@Observable
final class LoginService {
    private(set) var enabled = false
    private(set) var needsApproval = false
    var errorMessage: String?
    private let preview: Bool

    init(preview: Bool) {
        self.preview = preview
        if !preview {
            refresh()
        }
    }

    func refresh() {
        guard !preview else { return }
        enabled = SMAppService.mainApp.status == .enabled
        needsApproval = SMAppService.mainApp.status == .requiresApproval
    }

    @discardableResult
    func setEnabled(_ value: Bool) -> Bool {
        guard !preview else { return false }
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refresh()
            return value ? (enabled || needsApproval) : (!enabled && !needsApproval)
        } catch {
            refresh()
            errorMessage = error.localizedDescription
            return false
        }
    }

    func openSettings() { SMAppService.openSystemSettingsLoginItems() }

}
