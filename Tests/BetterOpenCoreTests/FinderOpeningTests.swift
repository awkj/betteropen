import Foundation
import Testing
@testable import BetterOpenCore

@Suite("Finder 打开行为")
struct FinderOpeningTests {
    let app = URL(fileURLWithPath: "/Applications/Otty.app")

    @Test func absentSnapshotDoesNotProduceCopyPathMenu() throws {
        #expect(FinderSharedConfiguration.decode(nil) == nil)
        #expect(FinderSharedConfiguration.decode(Data("{}".utf8)) == nil)
        let data = try JSONEncoder().encode(FinderConfiguration())
        #expect(FinderSharedConfiguration.decode(data)?.actions == [.copyPath])
    }

    @Test func menuRequestsSurviveAnotherMenuAndRejectUnknownTags() throws {
        var requests = FinderMenuRequests()
        let first = try #require(FinderIntegration.requestURL(action: .terminal, paths: [URL(fileURLWithPath: "/tmp/first")]))
        let second = try #require(FinderIntegration.requestURL(action: .editor, paths: [URL(fileURLWithPath: "/tmp/second")]))
        let firstTag = requests.insert(first)
        let secondTag = requests.insert(second)
        #expect(firstTag != secondTag)
        #expect(requests.request(for: firstTag) == first)
        #expect(requests.request(for: secondTag) == second)
        #expect(requests.request(for: 0) == nil)
        for _ in 0..<128 { _ = requests.insert(second) }
        #expect(requests.request(for: firstTag) == nil)
    }

    @Test func masterSwitchHidesActionsAndPreservesSelections() throws {
        var configuration = FinderConfiguration()
        configuration.editor = FinderApplication(applicationURL: URL(fileURLWithPath: "/Applications/Code.app"), displayName: "Code", bundleIdentifier: "com.microsoft.VSCode")
        configuration.terminal = FinderApplication(applicationURL: app, displayName: "Otty", bundleIdentifier: "io.appmakes.otty")
        let disabled = configuration.menuConfiguration(enabled: false)
        let snapshot = try JSONEncoder().encode(disabled)
        #expect(FinderSharedConfiguration.decode(snapshot)?.actions.isEmpty == true)
        #expect(configuration.editor != nil)
        #expect(configuration.terminal != nil)
        #expect(configuration.copyPathEnabled)
        #expect(configuration.menuConfiguration(enabled: true).actions == [.copyPath, .editor, .terminal])
    }

    @Test func finderConfigurationRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = FinderConfigurationFile(url: directory.appendingPathComponent("finder-settings.json"))
        var configuration = FinderConfiguration()
        configuration.terminal = FinderApplication(applicationURL: app, displayName: "Otty", bundleIdentifier: "io.appmakes.otty")
        try file.save(configuration)
        #expect(try file.load() == configuration)
        #expect(configuration.actions == [.copyPath, .terminal])
        configuration.copyPathEnabled = false
        configuration.terminal = nil
        #expect(configuration.actions.isEmpty)
    }

    @Test @MainActor func failedFinderSavePreservesSelectionAndMenu() throws {
        let file = FinderConfigurationFile(url: URL(fileURLWithPath: "/unused"), write: { _, _ in throw CocoaError(.fileWriteNoPermission) })
        let store = FinderSettingsStore(file: file)
        var changes = 0
        store.didChange = { changes += 1 }
        store.setCopyPathEnabled(false)
        #expect(store.configuration.copyPathEnabled)
        #expect(store.errorMessage != nil)
        #expect(changes == 0)
    }

    @Test(arguments: FinderAction.allCases)
    func requestPreservesSpecialCharactersAndMultipleSelections(_ action: FinderAction) throws {
        let paths = [URL(fileURLWithPath: "/tmp/中文 空格 &'\"?#%\n$(touch nope)"), URL(fileURLWithPath: "/tmp/second")]
        let url = try #require(FinderIntegration.requestURL(action: action, paths: paths))
        let request = try #require(FinderIntegration.parseRequest(url))
        #expect(request.action == action)
        #expect(request.paths == paths)
    }

    @Test(arguments: ["betteropen://open?action=no&path=/tmp", "https://open?path=/tmp",
                      "betteropen://open?action=terminal&path=relative",
                      "betteropen://open?action=terminal",
                      "betteropen://open?action=terminal&path=/tmp%00oops"])
    func malformedRequestsAreRejected(_ input: String) throws {
        #expect(FinderIntegration.parseRequest(try #require(URL(string: input))) == nil)
    }

    @Test func editorKeepsFilesAndDirectories() {
        let paths = [URL(fileURLWithPath: "/tmp/project"), URL(fileURLWithPath: "/tmp/code.swift")]
        #expect(FinderLaunchPlan.make(application: app, bundleIdentifier: "com.microsoft.VSCode", paths: paths,
                                     isDirectory: { _ in false }) == [.documents(paths)])
    }

    @Test func terminalDeduplicatesParentDirectories() {
        let directory = URL(fileURLWithPath: "/tmp/project").standardizedFileURL
        let plans = FinderLaunchPlan.make(application: app, bundleIdentifier: "com.mitchellh.ghostty",
                                         paths: [directory, directory.appendingPathComponent("a"), directory.appendingPathComponent("b")],
                                         isDirectory: { $0 == directory })
        #expect(plans == [.documents([directory])])
    }

    @Test func ottyPassesDirectoryAsOneArgument() {
        let directory = URL(fileURLWithPath: "/tmp/中文 空格;$(touch nope)")
        let plans = FinderLaunchPlan.make(application: app, bundleIdentifier: "io.appmakes.otty", paths: [directory],
                                         isDirectory: { _ in true })
        #expect(plans == [.command(executable: app.appendingPathComponent("Contents/MacOS/otty-cli"),
                                  arguments: ["open", directory.path])])
    }

    @Test func openingModesRespectApplicationCapabilities() {
        #expect(FinderOpeningMode.available(for: "io.appmakes.otty") == [.newTab, .newWindow])
        #expect(FinderOpeningMode.available(for: "com.microsoft.VSCode") == [.currentWindow, .newWindow])
        #expect(FinderOpeningMode.available(for: "com.mitchellh.ghostty", version: "1.2.3") == [])
        #expect(FinderOpeningMode.available(for: "com.mitchellh.ghostty", version: "1.3.1").contains(.newTab))
        #expect(FinderOpeningMode.available(for: "unknown") == [])
        #expect(FinderOpeningMode.resolve(.automatic, available: [.newTab, .newWindow]) == .newTab)
        #expect(FinderOpeningMode.resolve(.newTab, available: [.currentWindow, .newWindow]) == .currentWindow)
        #expect(FinderOpeningMode.resolve(.newWindow, available: [.newTab, .newWindow]) == .newWindow)
    }

    @Test func explicitWindowModeAndEditorReusePreservePaths() {
        let directory = URL(fileURLWithPath: "/tmp/中文 空格;$(touch nope)")
        let window = FinderLaunchPlan.make(application: app, bundleIdentifier: "io.appmakes.otty", paths: [directory],
                                            mode: .newWindow, hasExistingWindow: true, isDirectory: { _ in true })
        #expect(window == [.command(executable: app.appendingPathComponent("Contents/MacOS/otty-cli"), arguments: ["open", directory.path])])
        let file = directory.appendingPathComponent("test.swift")
        let code = URL(fileURLWithPath: "/Applications/Visual Studio Code.app")
        let reuse = FinderLaunchPlan.make(application: code, bundleIdentifier: "com.microsoft.VSCode", paths: [file], mode: .currentWindow, isDirectory: { _ in false })
        #expect(reuse == [.command(executable: code.appendingPathComponent("Contents/Resources/app/bin/code"), arguments: ["--reuse-window", "--", file.path])])
        let wezterm = FinderLaunchPlan.make(application: app, bundleIdentifier: "com.github.wez.wezterm", paths: [directory], mode: .newTab, hasExistingWindow: true, isDirectory: { _ in true })
        #expect(wezterm == [.command(executable: app.appendingPathComponent("Contents/MacOS/wezterm"), arguments: ["cli", "spawn", "--cwd", directory.path])])
    }

    @Test func ottyReusesWindowAndCreatesTabsForMultipleDirectories() {
        let first = URL(fileURLWithPath: "/tmp/中文 空格;$(touch nope)")
        let second = URL(fileURLWithPath: "/tmp/second")
        let executable = app.appendingPathComponent("Contents/MacOS/otty-cli")
        let warm = FinderLaunchPlan.make(application: app, bundleIdentifier: "io.appmakes.otty",
                                         paths: [first, second], mode: .newTab, hasExistingWindow: true, isDirectory: { _ in true })
        #expect(warm == [.command(executable: executable, arguments: ["tab", "new", "--cwd", first.path]),
                         .command(executable: executable, arguments: ["tab", "new", "--cwd", second.path])])
        let cold = FinderLaunchPlan.make(application: app, bundleIdentifier: "io.appmakes.otty",
                                         paths: [first, second], mode: .newTab, isDirectory: { _ in true })
        #expect(cold == [.command(executable: executable, arguments: ["open", first.path]), warm[1]])
    }

    @Test(arguments: [#"{"version":1,"applications":[]}"#,
                      #"{"version":1,"applications":[{"id":"00000000-0000-0000-0000-000000000000","applicationURL":"file:///Applications/Otty.app","displayName":"Otty"}]}"#])
    func previousConfigurationVersionIsRejected(_ json: String) throws {
        let data = Data(json.utf8)
        #expect(throws: ConfigurationError.unsupportedFormat) {
            try ConfigurationStore(url: app).decode(data)
        }
    }
}
