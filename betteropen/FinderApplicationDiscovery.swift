import AppKit
import Observation

@MainActor
@Observable
final class FinderApplicationDiscovery {
    private(set) var editors: [FinderApplication] = []
    private(set) var terminals: [FinderApplication] = []

    init() { refresh() }

    func refresh() {
        // 使用 Launch Services 查找应用，支持用户目录和非标准安装位置。
        terminals = discover([
            ("Ghostty", "com.mitchellh.ghostty"), ("Otty", "io.appmakes.otty"),
            ("iTerm", "com.googlecode.iterm2"), ("Terminal", "com.apple.Terminal"),
            ("WezTerm", "com.github.wez.wezterm"), ("Alacritty", "io.alacritty"),
            ("kitty", "net.kovidgoyal.kitty")
        ])
        editors = discover([
            ("Visual Studio Code", "com.microsoft.VSCode"), ("Cursor", "com.todesktop.230313mzl4w4u92"),
            ("Zed", "dev.zed.Zed"), ("Sublime Text", "com.sublimetext.4"),
            ("Sublime Text", "com.sublimetext.3"), ("BBEdit", "com.barebones.bbedit"),
            ("CotEditor", "com.coteditor.CotEditor"), ("Nova", "com.panic.Nova"),
            ("TextMate", "com.macromates.TextMate"), ("Typora", "abnerworks.Typora"),
            ("VS Code Insiders", "com.microsoft.VSCodeInsiders"), ("VSCodium", "com.visualstudio.code.oss"),
            ("Xcode", "com.apple.dt.Xcode"), ("TextEdit", "com.apple.TextEdit"),
            ("IntelliJ IDEA", "com.jetbrains.intellij"), ("PyCharm", "com.jetbrains.pycharm"),
            ("WebStorm", "com.jetbrains.WebStorm"), ("GoLand", "com.jetbrains.goland"),
            ("CLion", "com.jetbrains.CLion"), ("PhpStorm", "com.jetbrains.PhpStorm"),
            ("RubyMine", "com.jetbrains.rubymine")
        ])
    }

    private func discover(_ catalog: [(String, String)]) -> [FinderApplication] {
        var seen = Set<String>()
        return catalog.compactMap { name, identifier in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier),
                  let bundle = Bundle(url: url), bundle.bundleIdentifier == identifier,
                  seen.insert(url.standardizedFileURL.path).inserted else { return nil }
            return FinderApplication(applicationURL: url.standardizedFileURL, displayName: name, bundleIdentifier: identifier)
        }
    }
}
