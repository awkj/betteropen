import AppKit
import KeyboardShortcuts

@MainActor
final class GlobalShortcutService {
    var activate: ((ApplicationBinding) -> Void)?
    private var names: [KeyboardShortcuts.Name] = []
    private var enabled: Bool

    init(enabled: Bool = true) { self.enabled = enabled }

    func replace(apps: [ApplicationBinding]) {
        // 替换回调时暂停事件分发，完成后按总开关恢复注册。
        KeyboardShortcuts.isEnabled = false
        stop()
        for app in apps where app.shortcut != nil {
            guard let shortcut = app.keyboardShortcut else { continue }
            let name = KeyboardShortcuts.Name("betteropen.app.\(app.id)")
            names.append(name)
            KeyboardShortcuts.setShortcut(shortcut, for: name)
            KeyboardShortcuts.onKeyDown(for: name) { [weak self] in
                guard let self, self.enabled else { return }
                self.activate?(app)
            }
        }
        setEnabled(enabled)
        KeyboardShortcuts.isEnabled = true
    }

    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        if enabled { KeyboardShortcuts.enable(names) }
        else { KeyboardShortcuts.disable(names) }
    }

    func stop() {
        for name in names {
            KeyboardShortcuts.removeHandler(for: name)
            KeyboardShortcuts.setShortcut(nil, for: name)
        }
        names = []
    }
}
