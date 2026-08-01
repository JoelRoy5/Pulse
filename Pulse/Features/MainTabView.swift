import SwiftUI
import PulseShared

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    enum Tab { case home, history, settings }

    /// Set -PulseDebugHome YES to show the legacy TodayPlaceholderView instead.
    /// Read once at init time to avoid re-evaluating ProcessInfo on every body call.
    private let showDebugHome: Bool = {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-PulseDebugHome"),
           idx + 1 < args.count {
            return args[idx + 1].uppercased() == "YES"
        }
        return false
    }()

    var body: some View {
        TabView(selection: $selectedTab) {
            Group {
                if showDebugHome {
                    TodayPlaceholderView()
                } else {
                    HomeView()
                }
            }
            .tabItem { Label("Today", systemImage: "heart.fill") }
            .tag(Tab.home)

            JourneyPlaceholderView()
                .tabItem { Label("Journey", systemImage: "book.closed.fill") }
                .tag(Tab.history)

            SettingsPlaceholderView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(Tab.settings)
        }
        .tint(Color.psAccent)
    }
}

// MARK: - Placeholder screens (Tasks 15-17 replace these)

private struct JourneyPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.psDeepNavy.ignoresSafeArea()
            Text("Journey coming soon")
                .foregroundStyle(Color.psWhite.opacity(0.5))
        }
    }
}

private struct SettingsPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.psDeepNavy.ignoresSafeArea()
            Text("Settings coming soon")
                .foregroundStyle(Color.psWhite.opacity(0.5))
        }
    }
}
