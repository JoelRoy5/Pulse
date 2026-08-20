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
            let tabName: String
            switch newValue {
            case 0: tabName = "verse"
            case 1: tabName = "vitals"
            case 2: tabName = "history"
            case 3: tabName = "prayer"
            default: tabName = "\(newValue)"
            }
            Task { @MainActor in
                WatchAnalytics.shared.track(.watchTabViewed(tab: tabName))
            }
        }
    }

    // First-run affordance: tap (or turn the crown) to reach the other tabs.
    private var scrollHint: some View {
        Button {
            hasDiscoveredTabs = true
            withAnimation(.easeInOut(duration: 0.35)) {
                selectedTab = 1
                showHint = false
            }
        } label: {
            HStack(spacing: 4) {
                Text("Scroll for more")
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
        .buttonStyle(.plain)
    }
}
