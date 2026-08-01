import SwiftUI
import PulseShared

// MARK: - MainView

struct MainView: View {
    @Environment(WatchState.self) private var watchState

    // Support -PulseWatchTab N launch arg for headless screenshot capture
    private var initialTab: Int {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-PulseWatchTab"),
           args.indices.contains(idx + 1),
           let tab = Int(args[idx + 1]) {
            return tab
        }
        return 0
    }

    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            VerseView()
                .tag(0)
            VitalsView()
                .tag(1)
            HistoryView()
                .tag(2)
            PrayerView()
                .tag(3)
        }
        .tabViewStyle(.verticalPage)
        .onAppear {
            selectedTab = initialTab
        }
    }
}
