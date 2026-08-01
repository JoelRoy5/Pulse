import SwiftUI
import SwiftData
import PulseShared

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \VerseDelivery.deliveredAt, order: .reverse)
    private var allDeliveries: [VerseDelivery]

    @State private var selectedTab: Tab = initialTab()

    // -PulseShowShare YES → present ShareCardView for latest delivery on appear
    @State private var shareCardDelivery: VerseDelivery?
    @State private var showShareOnAppear: Bool = {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-PulseShowShare"),
           idx + 1 < args.count {
            return args[idx + 1].uppercased() == "YES"
        }
        return false
    }()

    enum Tab: String { case home, history, settings }

    /// Read once at launch — avoids re-evaluating ProcessInfo on every body call.
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

            HistoryView()
                .tabItem { Label("Journey", systemImage: "book.closed.fill") }
                .tag(Tab.history)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(Tab.settings)
        }
        .tint(Color.psAccent)
        .task {
            // -PulseShowShare YES: auto-present share card for latest delivery
            if showShareOnAppear, let delivery = allDeliveries.first {
                showShareOnAppear = false
                try? await Task.sleep(for: .milliseconds(600))
                shareCardDelivery = delivery
            }
        }
        .sheet(item: $shareCardDelivery) { delivery in
            ShareCardView(delivery: delivery) {
                delivery.sharedAt = .now
                delivery.engagedAt = delivery.engagedAt ?? .now
                try? modelContext.save()
            }
        }
    }

    // MARK: - Initial Tab from Launch Arg

    private static func initialTab() -> Tab {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-PulseInitialTab"),
           idx + 1 < args.count {
            let raw = args[idx + 1].lowercased()
            switch raw {
            case "journey": return .history
            case "settings": return .settings
            default: return .home
            }
        }
        return .home
    }
}

