import Foundation
import Testing
@testable import BetterOpenCore

@Suite("界面偏好")
struct InterfacePreferencesTests {
    @Test func preferencesPersistWithoutChangingSystemPreferences() throws {
        let suite = "BetterOpen.interface.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["fr"], forKey: "AppleLanguages")
        defaults.set("Dark", forKey: "AppleInterfaceStyle")
        #expect(InterfacePreferences(defaults: defaults) == InterfacePreferences())
        let selected = InterfacePreferences(appearance: .dark, language: .simplifiedChinese,
                                            dockVisible: false)
        selected.save(to: defaults)
        #expect(InterfacePreferences(defaults: defaults) == selected)
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["fr"])
        #expect(defaults.string(forKey: "AppleInterfaceStyle") == "Dark")
        InterfacePreferences().save(to: defaults)
        #expect(InterfacePreferences(defaults: defaults) == InterfacePreferences())
    }

    @Test func unknownValuesFollowSystem() throws {
        let suite = "BetterOpen.interface.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("invalid", forKey: "interface.appearance")
        defaults.set("invalid", forKey: "interface.language")
        #expect(InterfacePreferences(defaults: defaults) == InterfacePreferences())
    }

    @Test func languageSelectionAndSystemFallback() {
        #expect(AppLanguage.english.resolvedIdentifier(preferredLanguages: ["zh-Hans"]) == "en")
        #expect(AppLanguage.simplifiedChinese.resolvedIdentifier(preferredLanguages: ["en"]) == "zh-Hans")
        #expect(AppLanguage.system.resolvedIdentifier(preferredLanguages: ["zh-Hans-CN", "en"]) == "zh-Hans")
        #expect(AppLanguage.system.resolvedIdentifier(preferredLanguages: ["de", "en"]) == "en")
    }
}
