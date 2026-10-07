import AppKit
import FinderSync
import Observation
import KeyboardShortcuts

@MainActor
@Observable
final class AppState {
    let apps: ApplicationStore
    let finder: FinderSettingsStore
    let finderApplications = FinderApplicationDiscovery()
    let login: LoginService
    let updater: UpdaterService
    let isPreview: Bool
    private let preferences: UserDefaults
    private let applicationService = ApplicationService()
    private let finderService = FinderOpeningService()
    private var monitor: GlobalShortcutService?

    // 开发版使用独立配置验证真实热键，正式版的隔离预览仍不注册热键。
    private var canRegisterShortcuts: Bool { !isPreview || FinderIntegration.isDevelopmentBundle }

    private(set) var finderExtensionEnabled = false
    private(set) var finderMenuError: String?

    var finderEnabled: Bool {
        didSet {
            preferences.set(finderEnabled, forKey: "finder.enabled")
            publishFinderApplications()
        }
    }

    private(set) var editorOpeningMode: FinderOpeningMode
    private(set) var terminalOpeningMode: FinderOpeningMode

    var interfacePreferences: InterfacePreferences {
        didSet {
            interfacePreferences.save(to: preferences)
            applyAppearance()
            if oldValue.dockVisible != interfacePreferences.dockVisible { applyDockVisibility() }
        }
    }

    func applyAppearance() {
        switch interfacePreferences.appearance {
        case .system: NSApplication.shared.appearance = nil
        case .light: NSApplication.shared.appearance = NSAppearance(named: .aqua)
        case .dark: NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        }
    }

    var selectedTab = 0
    var menuBarVisible: Bool {
        didSet {
            preferences.set(menuBarVisible, forKey: "menuBar.visible")
        }
    }
    var shortcutsEnabled: Bool {
        didSet {
            preferences.set(shortcutsEnabled, forKey: "shortcuts.enabled")
            monitor?.setEnabled(shortcutsEnabled)
        }
    }

    init(preview requestedPreview: Bool = false) {
        let preview = requestedPreview || FinderIntegration.isDevelopmentBundle
        isPreview = preview
        let prefs = preview && !FinderIntegration.isDevelopmentBundle
            ? UserDefaults(suiteName: "io.github.awkj.BetterOpen.preview.preferences")! : .standard
        preferences = prefs
        interfacePreferences = InterfacePreferences(defaults: prefs)
        prefs.register(defaults: ["finder.enabled": true, "menuBar.visible": true, "shortcuts.enabled": true])
        editorOpeningMode = FinderOpeningMode(rawValue: prefs.string(forKey: "finder.editorOpeningMode") ?? "") ?? .newTab
        terminalOpeningMode = FinderOpeningMode(rawValue: prefs.string(forKey: "finder.terminalOpeningMode") ?? "") ?? .newTab
        finderEnabled = prefs.bool(forKey: "finder.enabled")
        menuBarVisible = prefs.bool(forKey: "menuBar.visible")
        shortcutsEnabled = prefs.bool(forKey: "shortcuts.enabled")
        let directory: URL
        if FinderIntegration.isDevelopmentBundle {
            directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("BetterOpen Dev", isDirectory: true)
        } else if preview {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("BetterOpen-preview-\(UUID().uuidString)")
        } else {
            directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("BetterOpen", isDirectory: true)
        }
        apps = ApplicationStore(store: ConfigurationStore(url: directory.appendingPathComponent("configuration.json")))
        finder = FinderSettingsStore(file: FinderConfigurationFile(url: directory.appendingPathComponent("finder-settings.json")))
        if finder.needsInitialSelection {
            var defaults = FinderConfiguration()
            defaults.terminal = finderApplications.terminals.first
            defaults.editor = finderApplications.editors.first
            finder.commit(defaults)
        }
        login = LoginService(preview: preview)
        updater = UpdaterService(preview: preview)
        finder.didChange = { [weak self] in self?.publishFinderApplications() }
        if preview {
            apps.add(URL(fileURLWithPath: "/System/Applications/Calculator.app"))
            for path in ["/Applications/Visual Studio Code.app", "/Applications/Ghostty.app", "/Applications/Otty.app"] {
                let url = URL(fileURLWithPath: path)
                guard Bundle(url: url) != nil else { continue }
                apps.add(url)
            }
        }
        apps.didChange = { [weak self] in
            self?.syncShortcuts()
        }
    }

    func start() {
        applyAppearance()
        applyDockVisibility()
        refreshFinderStatus()
        publishFinderApplications()
        updater.start()
        guard canRegisterShortcuts else { return }
        monitor = GlobalShortcutService(enabled: shortcutsEnabled)
        monitor?.activate = { [weak self] app in
            self?.applicationService.toggle(app) { [weak self] message in self?.apps.errorMessage = message }
        }
        syncShortcuts()
    }

    private func publishFinderApplications() {
        guard !isPreview || FinderIntegration.isDevelopmentBundle else { return }
        do {
            try finderService.publish(finder.configuration.menuConfiguration(enabled: finderEnabled))
            finderMenuError = nil
        } catch {
            finderMenuError = error.localizedDescription
            apps.errorMessage = interfacePreferences.language.localized("Unable to update the Finder menu. Reopen BetterOpen to retry.") + "\n" + error.localizedDescription
        }
    }

    func openFromFinder(_ urls: [URL], onError: @escaping @MainActor () -> Void) {
        guard finderEnabled, !isPreview || FinderIntegration.isDevelopmentBundle else { return }
        for url in urls {
            Task {
                do { try await finderService.open(url, configuration: finder.configuration,
                                                    editorMode: openingMode(for: .editor), terminalMode: openingMode(for: .terminal)) }
                catch { apps.errorMessage = error.localizedDescription; onError() }
            }
        }
    }

    func openingModes(for action: FinderAction) -> [FinderOpeningMode] {
        let app = finder.configuration.application(for: action)
        let version = app.flatMap { Bundle(url: $0.applicationURL)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String }
        return FinderOpeningMode.available(for: app?.bundleIdentifier, version: version)
    }

    func openingMode(for action: FinderAction) -> FinderOpeningMode {
        let mode = action == .editor ? editorOpeningMode : terminalOpeningMode
        return FinderOpeningMode.resolve(mode, available: openingModes(for: action))
    }

    func setOpeningMode(_ mode: FinderOpeningMode, for action: FinderAction) {
        guard action != .copyPath, openingModes(for: action).contains(mode) else { return }
        if action == .editor { editorOpeningMode = mode } else { terminalOpeningMode = mode }
        preferences.set(mode.rawValue, forKey: action == .editor ? "finder.editorOpeningMode" : "finder.terminalOpeningMode")
    }

    func refreshFinderStatus() {
        // 系统接口只查询本应用包含的扩展，不混用开发版和正式版状态。
        finderExtensionEnabled = FIFinderSyncController.isExtensionEnabled
    }

    func refreshFinderIntegration() {
        finderApplications.refresh()
        refreshFinderStatus()
        publishFinderApplications()
    }

    func openFinderSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }

    func syncShortcuts() {
        guard canRegisterShortcuts else { return }
        monitor?.replace(apps: apps.apps)
    }

    func updateShortcut(_ shortcut: KeyboardShortcuts.Shortcut?, for id: UUID) {
        let value = shortcut.map { Hotkey(keyCode: $0.carbonKeyCode, modifiers: $0.carbonModifiers) }
        apps.setShortcut(value, for: id)
    }

    func applyDockVisibility() {
        let visibleWindow = NSApp.windows.first { $0.isVisible && $0.isKeyWindow }
        NSApp.setActivationPolicy(interfacePreferences.dockVisible ? .regular : .accessory)
        if let visibleWindow {
            visibleWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func openMenuBarSettings() {
        guard #available(macOS 26, *),
              let url = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    func importShortcuts() {
        let panel = NSOpenPanel()
        panel.title = interfacePreferences.language.localized("Import Shortcuts From File")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { apps.importFile(url) }
    }

    func exportShortcuts() {
        let panel = NSSavePanel()
        panel.title = interfacePreferences.language.localized("Export Shortcuts To File")
        panel.nameFieldStringValue = "betteropen_shortcuts.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url { apps.exportFile(url) }
    }

    func stop() { monitor?.stop() }
}
