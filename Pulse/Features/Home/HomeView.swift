import SwiftUI
import SwiftData
import PulseShared

// MARK: - HomeView

struct HomeView: View {
    @Environment(HealthEngine.self) private var healthEngine
    @Environment(ScriptureEngine.self) private var scriptureEngine
    @Environment(\.modelContext) private var modelContext

    // Last 5 deliveries for recent verses row
    @Query(sort: \VerseDelivery.deliveredAt, order: .reverse) private var allDeliveries: [VerseDelivery]

    // UserPreferences for bible ID
    @Query private var preferences: [UserPreferences]

    // ViewModel — lazily created once we have modelContext
    @State private var viewModel: HomeViewModel?

    // Sheet state
    @State private var selectedDetailDelivery: VerseDelivery?
    @State private var showingDetail = false
    @State private var shareItem: ShareItem?

    // MARK: - Derived

    private var recentDeliveries: [VerseDelivery] {
        Array(allDeliveries.prefix(5))
    }

    private var latestDelivery: VerseDelivery? {
        allDeliveries.first
    }

    private var preferredBibleID: Int {
        preferences.first?.preferredBibleID ?? 3034
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

                    // 4. Recent Verses
                    if !recentDeliveries.isEmpty {
                        RecentVersesRow(
                            deliveries: recentDeliveries,
                            onSelect: { delivery in
                                selectedDetailDelivery = delivery
                                showingDetail = true
                            }
                        )
                    }

                    Spacer(minLength: PSSpacing.xxl)
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.top, PSSpacing.sm)
            }
            .background(Color.psDeepNavy.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    topBarLeading
                }
            }
            .refreshable {
                await healthEngine.refresh()
            }
            .task {
                // Initialise ViewModel with SwiftData context from environment
                if viewModel == nil {
                    viewModel = HomeViewModel(context: modelContext)
                }
                await healthEngine.refresh()
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
                    }
                )
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
                    let text = "\"\(delivery.verseText)\" — \(delivery.verseReference) (\(delivery.translationAbbreviation))"
                    shareItem = ShareItem(text: text)
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

    // MARK: - Top Bar

    private var topBarLeading: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pulse")
                .font(PSFont.label(size: 22, weight: .bold))
                .foregroundStyle(Color.psAccent)
            Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                .font(PSFont.label(size: 13))
                .foregroundStyle(Color.psGrayMuted)
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
