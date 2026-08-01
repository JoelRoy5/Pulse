import SwiftUI
import SwiftData
import PulseShared

// MARK: - HistoryView
//
// "Your Journey" tab — a chronologically-grouped list of VerseDeliveries
// with filter controls (All | Loved | Saved | State dropdown).

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \VerseDelivery.deliveredAt, order: .reverse)
    private var allDeliveries: [VerseDelivery]

    @Query private var preferences: [UserPreferences]

    @State private var viewModel: HistoryViewModel?
    @State private var selectedDelivery: VerseDelivery?
    @State private var shareDelivery: VerseDelivery?
    @State private var showingStateMenu = false

    // -PulseShowHistoryDetail YES — auto-present detail for most recent delivery on appear
    private let showDetailOnAppear: Bool = {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-PulseShowHistoryDetail"),
           idx + 1 < args.count {
            return args[idx + 1].uppercased() == "YES"
        }
        return false
    }()

    private var preferredBibleID: Int {
        preferences.first?.preferredBibleID ?? 3034
    }

    private var vm: HistoryViewModel? { viewModel }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.psDeepNavy.ignoresSafeArea()

                if allDeliveries.isEmpty {
                    emptyStateView
                } else {
                    contentList
                }
            }
            .navigationTitle("Your Journey")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { filterToolbar }
        }
        .task {
            if viewModel == nil {
                viewModel = HistoryViewModel(context: modelContext)
            }
            // -PulseShowHistoryDetail YES: auto-present detail for the most recent delivery
            if showDetailOnAppear, selectedDelivery == nil, let first = allDeliveries.first {
                try? await Task.sleep(for: .milliseconds(500))
                selectedDelivery = first
            }
        }
        .sheet(item: $selectedDelivery) { delivery in
            HistoryDetailView(
                delivery: delivery,
                preferredBibleID: preferredBibleID,
                onReact: { reaction in
                    viewModel?.react(reaction, to: delivery)
                },
                onShare: {
                    selectedDelivery = nil
                    // Brief delay so the detail sheet can dismiss before the share sheet appears.
                    // Using Task.sleep instead of DispatchQueue.main.asyncAfter.
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        shareDelivery = delivery
                    }
                }
            )
        }
        .sheet(item: $shareDelivery) { delivery in
            ShareCardView(delivery: delivery) {
                viewModel?.markShared(delivery)
            }
        }
    }

    // MARK: - Content List

    @ViewBuilder
    private var contentList: some View {
        let filtered = viewModel?.filtered(allDeliveries) ?? allDeliveries
        let sections = viewModel?.sections(from: filtered) ?? []

        VStack(spacing: 0) {
            // Filter bar — All | Loved | Saved
            if let vm = viewModel {
                HistoryFilterBar(filter: Binding(
                    get: { vm.filter },
                    set: { vm.filter = $0 }
                ))
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.sm)
            }

            if filtered.isEmpty {
                VStack(spacing: PSSpacing.md) {
                    Spacer()
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.psGrayMuted)
                    Text("No verses match your filter")
                        .font(PSFont.label(size: 17, weight: .medium))
                        .foregroundStyle(Color.psWhite.opacity(0.7))
                    Spacer()
                }
            } else {
                List {
                    ForEach(sections, id: \.section) { bucket in
                        Section {
                            ForEach(bucket.items) { delivery in
                                HistoryRowView(delivery: delivery) {
                                    // sharedAt is stamped by ShareCardView.onPresented — don't pre-stamp here
                                    shareDelivery = delivery
                                }
                                .listRowBackground(Color.psNavy)
                                .listRowInsets(.init(
                                    top: PSSpacing.sm,
                                    leading: PSSpacing.screenHorizontal,
                                    bottom: PSSpacing.sm,
                                    trailing: PSSpacing.screenHorizontal
                                ))
                                .onTapGesture {
                                    selectedDelivery = delivery
                                }
                            }
                        } header: {
                            Text(bucket.section.rawValue)
                                .font(PSFont.label(size: 13, weight: .semibold))
                                .foregroundStyle(Color.psGrayMuted)
                                .textCase(nil)
                                .padding(.leading, -PSSpacing.sm)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: PSSpacing.lg) {
            Spacer()
            Image(systemName: "heart")
                .font(.system(size: 56))
                .foregroundStyle(Color.psAccent.opacity(0.5))
            Text("Your journey begins with your first verse")
                .font(PSFont.label(size: 17, weight: .medium))
                .foregroundStyle(Color.psWhite.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, PSSpacing.xl)
            Spacer()
        }
    }

    // MARK: - Filter Toolbar

    @ToolbarContentBuilder
    private var filterToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            // State filter menu
            Menu {
                Button("All States") {
                    viewModel?.stateFilter = nil
                }
                Divider()
                ForEach(BiometricState.allCases) { state in
                    Button {
                        viewModel?.stateFilter = state
                    } label: {
                        Label(
                            "\(state.emoji) \(state.displayName)",
                            systemImage: viewModel?.stateFilter == state ? "checkmark" : ""
                        )
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    if let stateFilter = viewModel?.stateFilter {
                        Text(stateFilter.abbreviation)
                            .font(PSFont.label(size: 12, weight: .medium))
                    }
                }
                .foregroundStyle(viewModel?.stateFilter != nil ? Color.psAccent : Color.psWhite.opacity(0.7))
            }
            .accessibilityLabel("Filter by state")
        }
    }
}

// MARK: - HistoryFilterBar

struct HistoryFilterBar: View {
    @Binding var filter: HistoryFilter

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HistoryFilter.allCases) { option in
                Button {
                    filter = option
                } label: {
                    Text(option.rawValue)
                        .font(PSFont.label(size: 14, weight: filter == option ? .semibold : .regular))
                        .foregroundStyle(filter == option ? Color.psDeepNavy : Color.psWhite.opacity(0.7))
                        .padding(.horizontal, PSSpacing.md)
                        .frame(minHeight: 44)
                        .background(filter == option ? Color.psAccent : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(filter == option ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.psNavy)
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
        .modelContainer(for: [VerseDelivery.self, UserPreferences.self], inMemory: true)
}
