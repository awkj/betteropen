import AppKit
import KeyboardShortcuts

@main struct NativeCheck {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let app = ApplicationBinding(applicationURL: URL(fileURLWithPath: "/tmp/BetterOpenNativeCheck.app"),
                            displayName: "原生验证", shortcut: Hotkey(keyCode: 18, modifiers: 2048))
        let name = KeyboardShortcuts.Name("betteropen.app.\(app.id)")
        let monitor = GlobalShortcutService(enabled: false)
        defer { monitor.stop() }
        monitor.replace(apps: [app])
        precondition(!KeyboardShortcuts.isEnabled(for: name), "启动时停用的热键仍占用按键")
        monitor.setEnabled(true)
        precondition(KeyboardShortcuts.isEnabled(for: name), "应用热键未注册")
        monitor.setEnabled(false)
        precondition(!KeyboardShortcuts.isEnabled(for: name), "停用后的热键仍占用按键")
        var edited = app
        edited.shortcut = Hotkey(keyCode: 17, modifiers: 6912)
        monitor.replace(apps: [edited])
        precondition(!KeyboardShortcuts.isEnabled(for: name), "停用期间替换配置意外启用了热键")
        monitor.setEnabled(true)
        precondition(KeyboardShortcuts.isEnabled(for: name), "原菜单栏组合未能用于应用热键")
        precondition(KeyboardShortcuts.getShortcut(for: name) == edited.keyboardShortcut, "编辑后的热键未更新")
        edited.shortcut = nil
        monitor.replace(apps: [edited])
        precondition(!KeyboardShortcuts.isEnabled(for: name), "清除后的热键仍已注册")
        monitor.replace(apps: [app])
        monitor.replace(apps: [])
        precondition(!KeyboardShortcuts.isEnabled(for: name), "删除后的热键仍已注册")
        monitor.setEnabled(false)
        monitor.replace(apps: [app])
        precondition(!KeyboardShortcuts.isEnabled(for: name), "停用期间添加应用意外启用了热键")
        monitor.replace(apps: [])
        monitor.setEnabled(true)
        precondition(!KeyboardShortcuts.isEnabled(for: name), "恢复时重新注册了已删除的热键")
        monitor.replace(apps: [app])
        monitor.stop()
        precondition(!KeyboardShortcuts.isEnabled(for: name), "退出时未注销应用热键")
        print("通过：启动停用、开启、停用、停用期间替换配置与添加、恢复、清除、删除与退出清理")
    }
}
