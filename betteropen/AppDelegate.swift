import AppKit
import SwiftUI

@main
@MainActor
struct BetterOpenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var state: AppState

    init() {
        let state = AppState(preview: CommandLine.arguments.contains("--preview"))
        _state = State(initialValue: state)
        delegate.configure(state: state)
    }

    var body: some Scene {
        @Bindable var state = state
        MenuBarExtra(FinderIntegration.isDevelopmentBundle ? state.interfacePreferences.language.localized("BetterOpen Dev") : "BetterOpen", image: "menu-item", isInserted: $state.menuBarVisible) {
            StatusMenu(state: state, showWindow: delegate.showMainWindow)
                .environment(\.locale, state.interfacePreferences.language.locale)
        }
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button(state.interfacePreferences.language.localized("Settings…")) { delegate.showSettings() }
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: AppState!
    private var window: NSWindow?
    private var terminationSignals: [DispatchSourceSignal] = []

    func configure(state: AppState) { self.state = state }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 终端开发会话通过信号正常退出，确保注销快捷键并清理服务。
        if CommandLine.arguments.contains("--dev-session") {
            for number in [SIGINT, SIGTERM] {
                signal(number, SIG_IGN)
                let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
                source.setEventHandler { NSApp.terminate(nil) }
                source.resume()
                terminationSignals.append(source)
            }
        }
        // 直接加载包内图标，避免 Dock 使用系统缓存或额外套底后的图标。
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        state.start()
        if (state.apps.apps.isEmpty && state.finder.needsInitialSelection) || state.apps.errorMessage != nil || state.finder.errorMessage != nil || state.isPreview { showMainWindow() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        state.openFromFinder(urls) { [weak self] in self?.showMainWindow() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) { state?.stop() }

    func showSettings() {
        state?.selectedTab = 2
        showMainWindow()
    }

    func showMainWindow() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 460),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = FinderIntegration.isDevelopmentBundle ? state.interfacePreferences.language.localized("BetterOpen Dev") : "BetterOpen"
            window.identifier = NSUserInterfaceItemIdentifier("BetterOpenMainWindow")
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 560, height: 420)
            window.contentViewController = NSHostingController(rootView: MainView(state: state, apps: state.apps, login: state.login))
            window.center()
            window.setFrameAutosaveName("BetterOpenMainWindow")
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        state.login.refresh()
    }
}
