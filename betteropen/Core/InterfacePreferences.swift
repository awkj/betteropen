import Foundation

nonisolated enum AppAppearance: String, CaseIterable, Sendable {
    case system
    case light
    case dark
}

nonisolated enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    func resolvedIdentifier(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        guard self == .system else { return rawValue }
        return Bundle.preferredLocalizations(from: ["en", "zh-Hans"], forPreferences: preferredLanguages).first ?? "en"
    }

    var locale: Locale { Locale(identifier: resolvedIdentifier()) }

    func localized(_ key: String, in bundle: Bundle = .main) -> String {
        let localizedBundle = bundle.path(forResource: resolvedIdentifier(), ofType: "lproj")
            .flatMap { Bundle(path: $0) } ?? bundle
        return localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }
}

/// 界面偏好与系统外观、系统语言独立；未知值回退到跟随系统。
nonisolated struct InterfacePreferences: Equatable, Sendable {
    var appearance: AppAppearance = .system
    var language: AppLanguage = .system

    var dockVisible = true

    init(appearance: AppAppearance = .system, language: AppLanguage = .system,
         dockVisible: Bool = true) {
        self.appearance = appearance
        self.language = language
        self.dockVisible = dockVisible
    }

    init(defaults: UserDefaults) {
        dockVisible = defaults.object(forKey: "dock.visible") as? Bool ?? true
        appearance = AppAppearance(rawValue: defaults.string(forKey: "interface.appearance") ?? "") ?? .system
        language = AppLanguage(rawValue: defaults.string(forKey: "interface.language") ?? "") ?? .system
    }

    func save(to defaults: UserDefaults) {
        defaults.set(dockVisible, forKey: "dock.visible")
        defaults.set(appearance.rawValue, forKey: "interface.appearance")
        defaults.set(language.rawValue, forKey: "interface.language")
    }
}
