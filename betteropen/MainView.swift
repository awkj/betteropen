import AppKit
import SwiftUI
import UniformTypeIdentifiers
import KeyboardShortcuts

@MainActor
struct MainView: View {
    @Bindable var state: AppState
    @Bindable var apps: ApplicationStore
    @Bindable var login: LoginService
    @State private var selection: UUID?
    @State private var pendingDeletion: UUID?

    var body: some View {
        NativeSettingsTabs(selection: $state.selectedTab, language: state.interfacePreferences.language, pages: [
            .init(title: "Application Shortcuts", symbol: "command", content: AnyView(applicationList)),
            .init(title: "Finder Extension", symbol: "folder", content: AnyView(finderSettings)),
            .init(title: "Application Settings", symbol: "gearshape", content: AnyView(settings)),
            .init(title: "About", symbol: "info.circle", content: AnyView(about))
        ])
        .frame(minWidth: 540, minHeight: 380)
        .alert("Unable to complete the action", isPresented: Binding(
            get: { apps.errorMessage != nil || login.errorMessage != nil || state.updater.errorMessage != nil || state.finder.errorMessage != nil },
            set: { if !$0 { apps.errorMessage = nil; login.errorMessage = nil; state.updater.errorMessage = nil; state.finder.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { apps.errorMessage = nil; login.errorMessage = nil; state.updater.errorMessage = nil; state.finder.errorMessage = nil }
        } message: {
            Text(apps.errorMessage ?? login.errorMessage ?? state.updater.errorMessage ?? state.finder.errorMessage ?? "")
        }
        .confirmationDialog("Remove this application?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), titleVisibility: .visible) {
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let id = pendingDeletion { apps.delete(id); selection = nil }
                pendingDeletion = nil
            }
        } message: {
            Text("This removes the application and its shortcut.")
        }
        .environment(\.locale, state.interfacePreferences.language.locale)
    }

    private var applicationList: some View {
        VStack(spacing: 0) {
            if apps.apps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "command.square").font(.system(size: 40)).foregroundStyle(.secondary)
                    Text("Open your apps with a shortcut").font(.headline)
                    Text("Add an application, then record its global shortcut.").foregroundStyle(.secondary)
                    Button("Add Application…", action: addApplication)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    ForEach(apps.apps) { app in
                        HStack(spacing: 12) {
                            Image(nsImage: app.icon).resizable().frame(width: 36, height: 36)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.displayName).font(.body)
                                if !app.isAvailable {
                                    Text("Application unavailable").font(.caption).foregroundStyle(.orange)
                                }
                            }
                            Spacer()
                            ShortcutRecorder(shortcut: Binding(
                                get: { apps.apps.first(where: { $0.id == app.id })?.keyboardShortcut },
                                set: { state.updateShortcut($0, for: app.id) }
                            ), language: state.interfacePreferences.language,
                               accessibilityTitle: String(format: state.interfacePreferences.language.localized("Shortcut for %@"), app.displayName))
                            .frame(width: 148, height: 28)
                        }
                        .padding(.vertical, 5)
                        .tag(app.id)
                        .contextMenu {
                            Button("Remove Application", role: .destructive) { pendingDeletion = app.id }
                        }
                    }
                    .onMove { apps.move(from: $0, to: $1) }
                }
                .listStyle(.inset)
            }
            Divider()
            HStack {
                ControlGroup {
                    Button(action: addApplication) {
                        Label("Add Application…", systemImage: "plus")
                    }
                    .help("Add Application…")
                    Button { pendingDeletion = selection } label: {
                        Label("Remove Application", systemImage: "minus")
                    }
                    .disabled(selection == nil)
                    .keyboardShortcut(.delete, modifiers: [])
                    .help("Remove Application")
                }
                .labelStyle(.iconOnly)
                .fixedSize()
                Spacer()
                Toggle("Enable Application Shortcuts", isOn: $state.shortcutsEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .fixedSize()
            }
            .padding(12)
        }
    }

    private var finderSettings: some View {
        Form {
            Section {
                Toggle("Enable Finder Extension", isOn: $state.finderEnabled)
            }
            Group {
                Section {
                    Toggle("Copy Path", isOn: Binding(
                        get: { state.finder.configuration.copyPathEnabled },
                        set: { state.finder.setCopyPathEnabled($0) }
                    ))
                } header: {
                    Text("Finder Actions")
                }
                Section {
                    finderApplicationSettings("Default Editor", modeTitle: "Editor Opening Mode", action: .editor,
                                              applications: state.finderApplications.editors)
                }
                Section {
                    finderApplicationSettings("Default Terminal", modeTitle: "Terminal Opening Mode", action: .terminal,
                                              applications: state.finderApplications.terminals)
                } footer: {
                    Text("Installed apps are detected automatically. Choose Disabled to hide an action from Finder.")
                }
            }
            .disabled(!state.finderEnabled)
            Section {
                if !state.isPreview || FinderIntegration.isDevelopmentBundle {
                    HStack {
                        Text("Finder Extension")
                        Spacer()
                        if !state.finderEnabled {
                            Label("Turned Off", systemImage: "pause.circle.fill")
                                .foregroundStyle(.secondary)
                        } else if state.finderExtensionEnabled {
                            Label("Enabled", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label("Not Enabled", systemImage: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    if let error = state.finderMenuError {
                        HStack {
                            Label("Finder menu update failed", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Spacer()
                            Button("Retry", action: state.refreshFinderIntegration)
                        }
                        Text(error).font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Button(state.finderExtensionEnabled ? LocalizedStringKey("Manage Finder Extension…") : LocalizedStringKey("Enable Finder Extension…"), action: state.openFinderSettings)
                }
            }
            Section {
                Label("Full Disk Access", systemImage: "lock.shield")
                Text("If a protected folder won’t open, enable access for BetterOpen in Settings, then restart the app.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Open Settings…", action: state.openFullDiskAccessSettings)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            state.finderApplications.refresh()
            state.refreshFinderStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.finderApplications.refresh()
            state.refreshFinderStatus()
        }
    }

    private func finderApplicationSettings(_ title: LocalizedStringKey, modeTitle: LocalizedStringKey,
                                           action: FinderAction, applications: [FinderApplication]) -> some View {
        Group {
            applicationPicker(title, action: action, applications: applications)
                .pickerStyle(.menu)
            if state.finder.configuration.application(for: action) != nil {
                if state.openingModes(for: action).isEmpty {
                    Text("Opening mode selection is unavailable for this application.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    openingModePicker(modeTitle, action: action)
                        .pickerStyle(.menu)
                }
            }
        }
    }

    private func openingModePicker(_ title: LocalizedStringKey, action: FinderAction) -> some View {
        let modes = state.openingModes(for: action)
        return Picker(title, selection: Binding(
            get: { state.openingMode(for: action) },
            set: { state.setOpeningMode($0, for: action) }
        )) {
            ForEach(modes, id: \.self) { mode in
                Text(LocalizedStringKey(mode.title)).tag(mode)
            }
        }
        .disabled(state.finder.configuration.application(for: action) == nil || modes.count == 1)
    }

    private func applicationPicker(_ title: LocalizedStringKey, action: FinderAction,
                                   applications: [FinderApplication]) -> some View {
        let selected = state.finder.configuration.application(for: action)
        return Picker(title, selection: Binding<URL?>(
            get: { state.finder.configuration.application(for: action)?.applicationURL },
            set: { url in state.finder.select(applications.first(where: { $0.applicationURL == url }), for: action) }
        )) {
            Text("Disabled").tag(Optional<URL>.none)
            if let selected, !applications.contains(where: { $0.applicationURL == selected.applicationURL }) {
                Text("\(selected.displayName) (Unavailable)").tag(Optional(selected.applicationURL))
            }
            ForEach(applications) { application in
                Text(application.displayName).tag(Optional(application.applicationURL))
            }
        }
    }

    private var settings: some View {
        Form {
            Section("Appearance & Language") {
                Picker("Appearance", selection: $state.interfacePreferences.appearance) {
                    Text("Follow System").tag(AppAppearance.system)
                    Text("Light").tag(AppAppearance.light)
                    Text("Dark").tag(AppAppearance.dark)
                }
                .pickerStyle(.menu)
                Picker("Language", selection: $state.interfacePreferences.language) {
                    Text("Follow System").tag(AppLanguage.system)
                    Text(verbatim: "简体中文").tag(AppLanguage.simplifiedChinese)
                    Text(verbatim: "English").tag(AppLanguage.english)
                }
                .pickerStyle(.menu)
            }
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { login.enabled || login.needsApproval },
                    set: { login.setEnabled($0) }
                ))
                .disabled(state.isPreview)
                if login.needsApproval {
                    Button("Approve in System Settings", action: login.openSettings)
                }
            }
            Section {
                Toggle("Show menu bar icon", isOn: $state.menuBarVisible)
                Toggle("Show Dock icon", isOn: $state.interfacePreferences.dockVisible)
                if #available(macOS 26, *) {
                    Button("Open Menu Bar Settings…", action: state.openMenuBarSettings)
                }
            } header: {
                Text("App Icons")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    if #available(macOS 26, *) {
                        Text("On newer versions of macOS, you can also manage BetterOpen in System Settings > Menu Bar > Allow in the Menu Bar.")
                    }
                    Text("When both icons are hidden, reopen BetterOpen from Finder or Spotlight to access settings.")
                }
            }
            Section {
                HStack {
                    Button("Import Shortcuts…", action: importShortcuts)
                    Button("Export Shortcuts…", action: exportShortcuts)
                }
            } header: {
                Text("Shortcut Configuration")
            }
        }
        .formStyle(.grouped)
    }

    private var about: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSImage(named: NSImage.applicationIconName)
                  ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityLabel(Text("BetterOpen"))

            VStack(spacing: 6) {
                Text(verbatim: "BetterOpen")
                    .font(.title.weight(.semibold))
                HStack(spacing: 4) {
                    Text("Version")
                    Text(verbatim: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                }
                .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Button("Check for Updates…") {}
                    .disabled(true)
                Text("Update checking is coming soon.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addApplication() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        // 文件选择附着在当前窗口，避免阻塞整个应用的事件循环。
        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK else { return }
            for url in panel.urls { apps.add(url) }
        }
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    private func importShortcuts() { state.importShortcuts() }
    private func exportShortcuts() { state.exportShortcuts() }
}

// Canvas 预览使用独立数据，避免修改用户配置或注册真实热键。
#Preview("快捷键") {
    let state = AppState(preview: true)
    MainView(state: state, apps: state.apps, login: state.login)
}

#Preview("Finder 打开") {
    let state = AppState(preview: true)
    state.selectedTab = 1
    return MainView(state: state, apps: state.apps, login: state.login)
}

#Preview("设置页面") {
    let state = AppState(preview: true)
    state.selectedTab = 2
    return MainView(state: state, apps: state.apps, login: state.login)
}

#Preview("关于页面") {
    let state = AppState(preview: true)
    state.selectedTab = 3
    return MainView(state: state, apps: state.apps, login: state.login)
}

// AppKit 的工具栏分页提供系统设置窗口样式，并自动采用当前系统的玻璃外观。
@MainActor
private struct NativeSettingsTabs: NSViewControllerRepresentable {
    struct Page {
        let title: String
        let symbol: String
        let content: AnyView
    }

    @Binding var selection: Int
    let language: AppLanguage
    let pages: [Page]

    func makeNSViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.tabStyle = .toolbar
        controller.canPropagateSelectedChildViewControllerTitle = false
        controller.transitionOptions = []
        for (index, page) in pages.enumerated() {
            let item = NSTabViewItem(viewController: NSHostingController(rootView: AnyView(page.content.environment(\.locale, language.locale))))
            item.identifier = "BetterOpen.section.\(index)"
            item.label = language.localized(page.title)
            item.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: item.label)
            controller.addTabViewItem(item)
        }
        controller.selectedTabViewItemIndex = selection
        controller.selectionChanged = { selection = $0 }
        return controller
    }

    func updateNSViewController(_ controller: Controller, context: Context) {
        controller.selectionChanged = { selection = $0 }
        for (item, page) in zip(controller.tabViewItems, pages) {
            item.label = language.localized(page.title)
            item.image?.accessibilityDescription = item.label
            (item.viewController as? NSHostingController<AnyView>)?.rootView = AnyView(page.content.environment(\.locale, language.locale))
        }
        controller.view.window?.title = FinderIntegration.isDevelopmentBundle ? language.localized("BetterOpen Dev") : "BetterOpen"
        if controller.selectedTabViewItemIndex != selection {
            controller.selectedTabViewItemIndex = selection
        }
    }

    final class Controller: NSTabViewController {
        var selectionChanged: ((Int) -> Void)?

        override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
            super.tabView(tabView, didSelect: tabViewItem)
            let index = selectedTabViewItemIndex
            // 在下一轮更新绑定，避免在 SwiftUI 更新视图期间修改状态。
            Task { @MainActor [weak self] in
                guard self?.selectedTabViewItemIndex == index else { return }
                self?.selectionChanged?(index)
            }
        }

        override func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            [.flexibleSpace] + super.toolbarDefaultItemIdentifiers(toolbar) + [.flexibleSpace]
        }

        override func viewDidAppear() {
            super.viewDidAppear()
            view.window?.toolbarStyle = .preference
            view.window?.toolbar?.displayMode = .iconAndLabel
            view.window?.toolbar?.allowsUserCustomization = false
        }
    }
}

// 保留第三方录制器的冲突校验和事件生命周期，仅替换搜索框的外观。
@MainActor
private struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcuts.Shortcut?
    let language: AppLanguage
    let accessibilityTitle: String

    func makeNSView(context: Context) -> RecorderContainer {
        let coordinator = context.coordinator
        let recorder = KeyboardShortcuts.RecorderCocoa(shortcut: shortcut) {
            coordinator.binding.wrappedValue = $0
        }
        recorder.focusRingType = .none
        recorder.isBezeled = false
        recorder.isBordered = false
        recorder.drawsBackground = false
        recorder.font = .systemFont(ofSize: NSFont.systemFontSize)
        recorder.textColor = .labelColor
        recorder.setAccessibilityLabel(accessibilityTitle)
        return RecorderContainer(recorder: recorder, language: language)
    }

    func updateNSView(_ container: RecorderContainer, context: Context) {
        context.coordinator.binding = $shortcut
        if container.recorder.shortcut != shortcut {
            container.recorder.shortcut = shortcut
        }
        container.recorder.setAccessibilityLabel(accessibilityTitle)
        container.language = language
        container.updatePlaceholder()
    }

    func makeCoordinator() -> Coordinator { Coordinator(binding: $shortcut) }

    final class Coordinator {
        var binding: Binding<KeyboardShortcuts.Shortcut?>
        init(binding: Binding<KeyboardShortcuts.Shortcut?>) { self.binding = binding }
    }

    final class RecorderContainer: NSView {
        let recorder: KeyboardShortcuts.RecorderCocoa
        var language: AppLanguage
        private var updateObserver: NSObjectProtocol?
        private var wasRecording = false
        private var appearanceObserver: NSObjectProtocol?

        init(recorder: KeyboardShortcuts.RecorderCocoa, language: AppLanguage) {
            self.recorder = recorder
            self.language = language
            super.init(frame: .zero)
            wantsLayer = true
            layer?.cornerRadius = 6
            layer?.masksToBounds = true
            appearanceObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.needsDisplay = true }
            }
            addSubview(recorder)
            recorder.translatesAutoresizingMaskIntoConstraints = false
            // 使用无边框控件的自然高度，避免固定高度让文字在输入框内偏上。
            NSLayoutConstraint.activate([
                recorder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
                recorder.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
                recorder.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("不支持从归档加载快捷键控件") }

        isolated deinit {
            if let updateObserver { NotificationCenter.default.removeObserver(updateObserver) }
            if let appearanceObserver { NSWorkspace.shared.notificationCenter.removeObserver(appearanceObserver) }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let updateObserver { NotificationCenter.default.removeObserver(updateObserver) }
            updateObserver = nil
            if let window {
                updateObserver = NotificationCenter.default.addObserver(
                    forName: NSWindow.didUpdateNotification, object: window, queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        self.updatePlaceholder()
                        let recording = window.isKeyWindow && self.recorder.currentEditor() != nil
                        if recording != self.wasRecording {
                            self.wasRecording = recording
                            self.needsDisplay = true
                        }
                    }
                }
            }
        }

        func updatePlaceholder() {
            let recording = window?.isKeyWindow == true && recorder.currentEditor() != nil
            let placeholder = language.localized(recording ? "Press Shortcut" : "Record Shortcut")
            if recorder.placeholderString != placeholder { recorder.placeholderString = placeholder }
        }

        override var wantsUpdateLayer: Bool { true }

        override func updateLayer() {
            let recording = window?.isKeyWindow == true && recorder.currentEditor() != nil
            // 边框位于内容上方，并裁切系统搜索框在新系统上的焦点光晕。
            let increasedContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            effectiveAppearance.performAsCurrentDrawingAppearance {
                layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
                let borderColor: NSColor = recording ? .controlAccentColor
                    : (increasedContrast ? .labelColor : .separatorColor)
                layer?.borderColor = borderColor.cgColor
            }
            layer?.borderWidth = recording || increasedContrast ? 1 : 0.5
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            needsDisplay = true
        }
    }
}
