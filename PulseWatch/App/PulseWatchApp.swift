import SwiftUI
import WatchKit
import PulseShared

@main
struct PulseWatchApp: App {

    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(WatchSessionManager.shared.watchState)
                .onAppear {
                    WatchSessionManager.shared.activate()
                    Task { @MainActor in
                        WatchAnalytics.shared.track(.watchOpened())
                    }
                }
        }
    }
}
