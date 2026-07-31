import SwiftUI
import WatchKit
import PulseShared

@main
struct PulseWatchApp: App {

    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            WatchDebugView()
                .environment(WatchSessionManager.shared.watchState)
                .onAppear {
                    WatchSessionManager.shared.activate()
                }
        }
    }
}

// MARK: - WatchDebugView

/// Minimal debug root view — Task 12 replaces this with the full UI.
private struct WatchDebugView: View {
    @Environment(WatchState.self) private var watchState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let verse = watchState.currentVerse {
                    Text(verse.verseReference)
                        .font(.headline)
                    Text(verse.verseText)
                        .font(.body)
                } else {
                    Text("Waiting for verse…")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
}
