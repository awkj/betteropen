import AppKit
import Observation
import Sparkle
import SwiftUI

@MainActor
@Observable
final class UpdaterService {
    private(set) var canCheckForUpdates = false
    var errorMessage: String?
    @ObservationIgnored private let controller: SPUStandardUpdaterController?
    @ObservationIgnored private var observation: NSKeyValueObservation?

    init(preview: Bool) {
        let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        controller = preview || feed.isEmpty ? nil : SPUStandardUpdaterController(startingUpdater: false,
                                                                 updaterDelegate: nil, userDriverDelegate: nil)
        if let controller {
            observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, change in
                let enabled = change.newValue ?? false
                Task { @MainActor [weak self] in self?.canCheckForUpdates = enabled }
            }
        }
    }

    func start() {
        guard let controller else { return }
        do { try controller.updater.start() }
        catch { errorMessage = error.localizedDescription }
    }

    func checkForUpdates() { controller?.checkForUpdates(nil) }
}

@MainActor
struct StatusMenu: View {
    @Bindable var state: AppState
    let showWindow: () -> Void

    var body: some View {
        Button("Application Shortcuts") { state.selectedTab = 0; showWindow() }
        Button("Finder Extension") { state.selectedTab = 1; showWindow() }
        Button("Application Settings") { state.selectedTab = 2; showWindow() }
        Divider()
        Text("\(FinderIntegration.isDevelopmentBundle ? "BetterOpen Dev" : "BetterOpen") \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
        Button(FinderIntegration.isDevelopmentBundle ? LocalizedStringKey("Quit BetterOpen Dev") : LocalizedStringKey("Quit BetterOpen")) { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
