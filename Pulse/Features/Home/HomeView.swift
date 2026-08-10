import SwiftUI
import SwiftData
import PulseShared

// MARK: - HomeView

struct HomeView: View {
    @Environment(HealthEngine.self) private var healthEngine
    @Environment(ScriptureEngine.self) private var scriptureEngine
    @Environment(VerseOfDayScheduler.self) private var votdScheduler
    @Environment(\.modelContext) private var modelContext

    // Last 5 deliveries for recent verses row
    @Query(sort: \VerseDelivery.deliveredAt, order: .reverse) private var allDeliveries: [VerseDelivery]

    // VOTD deliveries today (deliveryMethod == "votd", delivered since startOfDay)
    // Note: SwiftData @Query does not support Date.now in #Predicate at compile time,
    // so we filter from all "votd" deliveries sorted descending and pick today's.
    @Query(
        filter: #Predicate<VerseDelivery> { $0.deliveryMethod == "votd" },
        sort: \VerseDelivery.deliveredAt,
        order: .reverse
    ) private var allVOTDDeliveries: [VerseDelivery]

    // UserPreferences for bible ID and VOTD setting
    @Query private var preferences: [UserPreferences]

    // ViewModel — lazily created once we have modelContext
    @State private var viewModel: HomeViewModel?

    // Sheet state
    @State private var selectedDetailDelivery: VerseDelivery?
    @State private var showingDetail = false
    @State private var shareItem: ShareItem?
    @State private var shareCardDelivery: VerseDelivery?

    // MARK: - Derived

    private var recentDeliveries: [VerseDelivery] {
        // Exclude VOTD deliveries — they are already shown in the dedicated Verse of the Day card above.
        Array(allDeliveries.filter { $0.deliveryMethod != "votd" }.prefix(5))
    }

    /// All engagement dates for the streak widget:
    /// each delivery's deliveredAt plus engagedAt when non-nil.
    private var streakEngagementDates: [Date] {
        allDeliveries.flatMap { delivery -> [Date] in
            var dates = [delivery.deliveredAt]
            if let engaged = delivery.engagedAt {
                dates.append(engaged)
            }
            return dates
        }
    }

    private var latestDelivery: VerseDelivery? {
        allDeliveries.first
    }

    private var preferredBibleID: Int {
        preferences.first?.preferredBibleID ?? 3034
    }

    private var includeVerseOfDay: Bool {
        preferences.first?.includeVerseOfDay ?? true
    }

    /// Returns the most recent VOTD delivery from today's calendar day, if any.
    private var todaysVOTDDelivery: VerseDelivery? {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return allVOTDDeliveries.first { $0.deliveredAt >= startOfDay }
    }

    private var currentDelivery: VerseDelivery? {
        scriptureEngine.currentDelivery ?? latestDelivery
    }

    private var currentState: BiometricState? {
        healthEngine.currentClassification?.state
            ?? currentDelivery?.biometricState
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PSSpacing.md) {

                    // 0. Header
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pulse")
                            .font(PSFont.label(size: 28, weight: .bold))
                            .foregroundStyle(Color.psAccent)
                        Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                            .font(PSFont.label(size: 14))
                            .foregroundStyle(Color.psGrayMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, PSSpacing.sm)

                    // 1. State Banner Card
                    if let state = currentState {
                        StateBannerCard(
                            state: state,
                            confidence: healthEngine.currentClassification?.confidence
                                ?? currentDelivery?.stateConfidence ?? 0,
                            snapshot: healthEngine.currentSnapshot
                        )
                    }

                    // 2. Verse Card (skeleton / empty / current)
                    verseCardSection

                    // 3. Metrics Grid
                    if healthEngine.currentSnapshot != nil {
                        SectionHeader(title: "Today's Metrics")
                        MetricsGridView(snapshot: healthEngine.currentSnapshot)
                    }

                    // 4. Verse of the Day Card
                    if includeVerseOfDay, let votd = todaysVOTDDelivery {
                        VerseOfDayCard(delivery: votd) {
                            selectedDetailDelivery = votd
                            showingDetail = true
                        }
                    }

                    // 5. Recent Verses
                    if !recentDeliveries.isEmpty {
                        RecentVersesRow(
                            deliveries: recentDeliveries,
                            onSelect: { delivery in
                                selectedDetailDelivery = delivery
                                showingDetail = true
                            }
                        )
                    }

                    // 6. Streak Widget
                    StreakWidget(engagementDates: streakEngagementDates)

                    Spacer(minLength: PSSpacing.xxl)
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.top, PSSpacing.sm)
            }
            .background(Color.psDeepNavy.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await healthEngine.refresh()
            }
            .task {
                // Initialise ViewModel with SwiftData context from environment
                if viewModel == nil {
                    viewModel = HomeViewModel(context: modelContext)
                }
                await healthEngine.refresh()
                // Ensure today's VOTD is fetched and persisted
                await votdScheduler.ensureTodaysVOTD()
            }
            .onAppear {
                // -PulseShowDetail YES — debug flag: auto-present detail sheet
                let args = ProcessInfo.processInfo.arguments
                if let idx = args.firstIndex(of: "-PulseShowDetail"),
                   idx + 1 < args.count,
                   args[idx + 1] == "YES",
                   !showingDetail {
                    selectedDetailDelivery = nil
                    showingDetail = true
                }
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let delivery = selectedDetailDelivery ?? currentDelivery {
                VerseDetailSheet(
                    delivery: delivery,
                    preferredBibleID: preferredBibleID,
                    onReact: { reaction in
                        viewModel?.react(reaction, to: delivery)
                    },
                    onShare: {
                        showingDetail = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            shareCardDelivery = delivery
                        }
                    }
                )
            }
        }
        .sheet(item: $shareCardDelivery) { delivery in
            ShareCardView(delivery: delivery) {
                delivery.sharedAt = .now
                delivery.engagedAt = delivery.engagedAt ?? .now
                try? modelContext.save()
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(text: item.text)
        }
    }

    // MARK: - Verse Card Section

    @ViewBuilder
    private var verseCardSection: some View {
        if scriptureEngine.isLoading {
            EmptyVerseCard(isLoading: true, onDeliver: {})
        } else if let delivery = currentDelivery {
            CurrentVerseCard(
                delivery: delivery,
                onLove: { viewModel?.react(.loved, to: delivery) },
                onSave: { viewModel?.react(.saved, to: delivery) },
                onShare: {
                    shareCardDelivery = delivery
                    delivery.sharedAt = .now
                    delivery.engagedAt = delivery.engagedAt ?? .now
                    try? modelContext.save()
                },
                onReadMore: {
                    selectedDetailDelivery = delivery
                    showingDetail = true
                }
            )
        } else {
            EmptyVerseCard(isLoading: false) {
                Task { await scriptureEngine.deliverFirstVerse() }
            }
        }
    }

}

// MARK: - Helpers

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(PSFont.label(size: 16, weight: .semibold))
            .foregroundStyle(Color.psWhite)
    }
}

/// Wrapper to make share text Identifiable for .sheet(item:)
struct ShareItem: Identifiable {
    let id = UUID()
    let text: String
}

/// Native share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
