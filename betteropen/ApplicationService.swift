import AppKit
import KeyboardShortcuts

@MainActor
extension ApplicationBinding {
    var icon: NSImage { NSWorkspace.shared.icon(forFile: applicationURL.path) }
    var isAvailable: Bool { Bundle(url: applicationURL) != nil }
    var keyboardShortcut: KeyboardShortcuts.Shortcut? {
        guard let value = shortcut else { return nil }
        return .init(carbonKeyCode: value.keyCode, carbonModifiers: value.modifiers)
    }
}

@MainActor
final class ApplicationService {
    func toggle(_ app: ApplicationBinding, onError: @escaping @MainActor (String) -> Void) {
        guard let bundle = Bundle(url: app.applicationURL) else {
            onError(NSLocalizedString("This application is no longer available. Remove it and add its new location.", comment: ""))
            return
        }
        if let identifier = bundle.bundleIdentifier,
           NSWorkspace.shared.frontmostApplication?.bundleIdentifier == identifier {
            NSWorkspace.shared.frontmostApplication?.hide()
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: app.applicationURL, configuration: configuration) { _, error in
            if let error {
                let message = error.localizedDescription
                Task { @MainActor in onError(message) }
            }
        }
    }
}
