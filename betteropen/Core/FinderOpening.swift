import Foundation
import Darwin

/// Finder 扩展只共享菜单数据；打开操作交给主应用执行。
nonisolated enum FinderIntegration {
    static var scheme: String {
        Bundle.main.object(forInfoDictionaryKey: "BetterOpenFinderScheme") as? String ?? "betteropen"
    }
    static var isDevelopmentBundle: Bool { scheme == "betteropen-dev" }
    static var snapshotURL: URL {
        // 从用户数据库获取真实主目录；Foundation 在扩展内会返回沙盒目录。
        var entry = passwd()
        var result: UnsafeMutablePointer<passwd>?
        var buffer = [CChar](repeating: 0, count: 16_384)
        let home = buffer.withUnsafeMutableBufferPointer { storage -> String in
            guard getpwuid_r(getuid(), &entry, storage.baseAddress, storage.count, &result) == 0,
                  result != nil, let directory = entry.pw_dir else { return NSHomeDirectory() }
            return String(cString: directory)
        }
        let name = isDevelopmentBundle ? "BetterOpen Dev" : "BetterOpen"
        return URL(fileURLWithPath: home).appendingPathComponent("Library/Application Support/\(name)/FinderMenu/configuration.json")
    }

    static func requestURL(action: FinderAction, paths: [URL]) -> URL? {
        guard !paths.isEmpty, paths.allSatisfy({ $0.isFileURL }) else { return nil }
        var parts = URLComponents()
        parts.scheme = scheme
        parts.host = "open"
        parts.queryItems = [URLQueryItem(name: "action", value: action.rawValue)]
            + paths.map { URLQueryItem(name: "path", value: $0.path) }
        return parts.url
    }

    static func parseRequest(_ url: URL) -> (action: FinderAction, paths: [URL])? {
        guard url.scheme == scheme, url.host == "open",
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = parts.queryItems,
              items.filter({ $0.name == "action" }).count == 1,
              let value = items.first(where: { $0.name == "action" })?.value,
              let action = FinderAction(rawValue: value) else { return nil }
        let paths = items.filter { $0.name == "path" }.compactMap(\.value)
        guard !paths.isEmpty, paths.allSatisfy({ $0.hasPrefix("/") && !$0.contains("\0") }) else { return nil }
        return (action, paths.map { URL(fileURLWithPath: $0) })
    }
}

/// Finder 跨进程只传菜单标识；请求保留在扩展进程中，避免依赖 representedObject。
nonisolated struct FinderMenuRequests {
    private var nextTag = 0
    private var requests: [Int: URL] = [:]

    mutating func insert(_ request: URL) -> Int {
        nextTag += 1
        requests[nextTag] = request
        if requests.count > 128, let oldest = requests.keys.min() {
            requests.removeValue(forKey: oldest)
        }
        return nextTag
    }

    func request(for tag: Int) -> URL? { requests[tag] }
}

nonisolated enum FinderOpeningMode: String, CaseIterable, Sendable {
    case automatic, newWindow, newTab, currentWindow

    var title: String {
        switch self {
        case .automatic: "Default Opening"
        case .newWindow: "New Window"
        case .newTab: "New Tab"
        case .currentWindow: "Current Window"
        }
    }

    static func resolve(_ requested: Self, available modes: [Self]) -> Self {
        if modes.contains(requested) { return requested }
        return modes.first ?? .automatic
    }

    static func available(for identifier: String?, version: String? = nil) -> [Self] {
        switch identifier {
        case "io.appmakes.otty", "com.github.wez.wezterm", "com.googlecode.iterm2":
            [.newTab, .newWindow]
        case "com.mitchellh.ghostty":
            // Ghostty 的脚本接口从 1.3 开始提供，旧版不提供指定打开方式。
            if let version, version.compare("1.3", options: .numeric) != .orderedAscending {
                [.newTab, .newWindow]
            } else { [] }
        case "com.microsoft.VSCode", "com.sublimetext.4", "com.sublimetext.3":
            [.currentWindow, .newWindow]
        default: []
        }
    }
}

nonisolated enum FinderLaunchPlan: Equatable {
    case documents([URL])
    case command(executable: URL, arguments: [String])

    static func make(application: URL, bundleIdentifier: String?, paths: [URL],
                     mode: FinderOpeningMode = .automatic, hasExistingWindow: Bool = false,
                     isDirectory: (URL) -> Bool) -> [Self] {
        if let identifier = bundleIdentifier, mode == .newWindow || mode == .currentWindow {
            let cli: String?
            switch identifier {
            case "com.microsoft.VSCode": cli = "Contents/Resources/app/bin/code"
            case "com.sublimetext.4", "com.sublimetext.3": cli = "Contents/SharedSupport/bin/subl"
            default: cli = nil
            }
            if let cli {
                let flag = mode == .newWindow ? "--new-window" : identifier == "com.microsoft.VSCode" ? "--reuse-window" : "--add"
                return [.command(executable: application.appendingPathComponent(cli), arguments: [flag, "--"] + paths.map(\.path))]
            }
        }
        let terminals: Set<String> = ["com.mitchellh.ghostty", "io.appmakes.otty",
                                     "com.apple.Terminal", "com.googlecode.iterm2", "com.github.wez.wezterm",
                                     "io.alacritty", "net.kovidgoyal.kitty"]
        guard let identifier = bundleIdentifier, terminals.contains(identifier) else {
            return [.documents(paths)]
        }
        var seen = Set<String>()
        let directories = paths.map { isDirectory($0) ? $0 : $0.deletingLastPathComponent() }
            .map(\.standardizedFileURL).filter { seen.insert($0.path).inserted }
        if identifier == "io.appmakes.otty" {
            return directories.enumerated().map { index, directory in
                .command(executable: application.appendingPathComponent("Contents/MacOS/otty-cli"),
                         arguments: mode == .newTab && (hasExistingWindow || index > 0)
                            ? ["tab", "new", "--cwd", directory.path]
                            : ["open", directory.path])
            }
        }
        if identifier == "com.github.wez.wezterm", mode != .automatic {
            return directories.enumerated().map { index, directory in
                let arguments = hasExistingWindow || (mode == .newTab && index > 0)
                    ? ["cli", "spawn"] + (mode == .newWindow ? ["--new-window"] : []) + ["--cwd", directory.path]
                    : ["start", "--cwd", directory.path]
                return .command(executable: application.appendingPathComponent("Contents/MacOS/wezterm"), arguments: arguments)
            }
        }
        if (identifier == "com.mitchellh.ghostty" || identifier == "com.googlecode.iterm2"), mode != .automatic {
            let script: String
            if identifier == "com.mitchellh.ghostty" {
                script = """
                on run argv
                    tell application id "com.mitchellh.ghostty"
                        set cfg to new surface configuration
                        set initial working directory of cfg to item 1 of argv
                        if item 2 of argv is "newTab" and (count of windows) > 0 then
                            set targetTab to new tab in front window with configuration cfg
                            focus focused terminal of targetTab
                        else
                            set targetWindow to new window with configuration cfg
                            activate window targetWindow
                        end if
                    end tell
                end run
                """
            } else {
                script = """
                on run argv
                    tell application id "com.googlecode.iterm2"
                        if item 2 of argv is "newTab" and (count of windows) > 0 then
                            tell current window
                                set targetTab to create tab with default profile
                            end tell
                            set targetSession to current session of targetTab
                        else
                            set targetWindow to create window with default profile
                            set targetSession to current session of targetWindow
                        end if
                        tell targetSession to write text ("cd -- " & quoted form of (item 1 of argv))
                        activate
                    end tell
                end run
                """
            }
            return directories.map {
                .command(executable: URL(fileURLWithPath: "/usr/bin/osascript"), arguments: ["-e", script, "--", $0.path, mode.rawValue])
            }
        }
        let arguments: [String]?
        switch identifier {
        case "com.github.wez.wezterm": arguments = ["start", "--cwd"]
        case "io.alacritty": arguments = ["--working-directory"]
        case "net.kovidgoyal.kitty": arguments = ["--single-instance", "--directory"]
        default: arguments = nil
        }
        if let arguments {
            return directories.map {
                .command(executable: URL(fileURLWithPath: "/usr/bin/open"),
                         arguments: ["-n", "-a", application.path, "--args"] + arguments + [$0.path])
            }
        }
        return directories.map { .documents([$0]) }
    }
}
