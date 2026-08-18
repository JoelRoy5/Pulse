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

    // Shown once, until the user first scrolls to another tab.
    @AppStorage("hasDiscoveredWatchTabs") private var hasDiscoveredTabs = false
    @State private var showHint = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .overlay(alignment: .top) {
            if showHint && selectedTab == 0 {
                scrollHint
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            selectedTab = initialTab
            if !hasDiscoveredTabs {
                withAnimation(.easeIn(duration: 0.4)) { showHint = true }
                // Auto-dismiss after a few seconds so it never lingers over content.
                Task {
                    try? await Task.sleep(for: .seconds(3.5))
                    withAnimation(.easeOut(duration: 0.4)) { showHint = false }
                }
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue != 0 {
                hasDiscoveredTabs = true
                withAnimation(.easeOut(duration: 0.3)) { showHint = false }
            }
        }
    }

    // First-run affordance: turn the crown to reach the other tabs.
    private var scrollHint: some View {
        HStack(spacing: 4) {
            Text("Turn crown for more")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
            Image(systemName: "chevron.compact.down")
                .font(.system(size: 12, weight: .bold))
                .symbolEffect(.bounce, options: reduceMotion ? .nonRepeating : .repeating)
        }
        .foregroundStyle(Color.psDeepNavy)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.psAccent, in: Capsule())
        .padding(.top, 2)
    }
}
