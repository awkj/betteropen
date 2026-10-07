import AppKit
import FinderSync
import OSLog

nonisolated final class FinderSync: FIFinderSync {
    private var menuRequests = FinderMenuRequests()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterOpen", category: "FinderOpening")

    override init() {
        super.init()
        refreshVolumes()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refreshVolumes),
                                                          name: NSWorkspace.didMountNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refreshVolumes),
                                                          name: NSWorkspace.didUnmountNotification, object: nil)
    }

    @objc private func refreshVolumes() {
        FIFinderSyncController.default().directoryURLs = Set(
            FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: []) ?? [])
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer else { return nil }
        let menu = NSMenu()
        let controller = FIFinderSyncController.default()
        let paths: [URL]
        if menuKind == .contextualMenuForContainer {
            paths = controller.targetedURL().map { [$0] } ?? []
        } else {
            paths = controller.selectedItemURLs() ?? controller.targetedURL().map { [$0] } ?? []
        }
        guard !paths.isEmpty,
              let configuration = FinderSharedConfiguration.load() else { return menu }
        for action in configuration.actions {
            guard let request = FinderIntegration.requestURL(action: action, paths: paths) else { continue }
            let app = configuration.application(for: action)
            let title: String
            if action == .copyPath {
                title = NSLocalizedString("Copy Path", comment: "复制 Finder 路径")
            } else {
                // 应用有效性由主应用检查；扩展不直接读取其他应用的包内容。
                guard let app else { continue }
                title = String(format: NSLocalizedString("Open in %@", comment: "Finder 打开菜单"), app.displayName)
            }
            let item = NSMenuItem(title: title, action: #selector(openApplication(_:)), keyEquivalent: "")
            item.target = self
            item.tag = menuRequests.insert(request)
            let icon = app.map { NSWorkspace.shared.icon(forFile: $0.applicationURL.path) }
                ?? NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
            icon?.size = NSSize(width: 16, height: 16)
            item.image = icon
            menu.addItem(item)
        }
        return menu
    }

    @objc private func openApplication(_ sender: NSMenuItem) {
        guard let url = menuRequests.request(for: sender.tag),
              let request = FinderIntegration.parseRequest(url),
              let settings = FinderSharedConfiguration.load(),
              settings.actions.contains(request.action) else { return }
        logger.notice("收到 Finder 菜单操作：\(request.action.rawValue, privacy: .public)")
        if request.action == .copyPath {
            // 复制路径直接在扩展内完成，不切换应用或弹出配置窗口。
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(request.paths.map(\.path).joined(separator: "\n"), forType: .string)
            return
        }
        // 明确使用包含本扩展的主应用，避免其他构建占用 URL 协议。
        let host = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.open([url], withApplicationAt: host, configuration: configuration) { [logger] _, error in
            if let error {
                logger.error("无法将 Finder 操作交给主应用：\(error.localizedDescription, privacy: .public)")
            } else {
                logger.notice("已将 Finder 操作交给主应用")
            }
        }
    }
}
