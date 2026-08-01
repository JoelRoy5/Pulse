import SwiftUI
import PulseShared

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    enum Tab { case home, history, settings }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayPlaceholderView()
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
