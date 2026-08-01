import SwiftUI
import PulseShared

// MARK: - HistoryView

struct HistoryView: View {
    @Environment(WatchState.self) private var watchState
    @State private var selectedVerse: WatchMessage.VerseDeliveryPayload?

    private var sections: [(title: String, items: [WatchMessage.VerseDeliveryPayload])] {
        let history = watchState.history
        guard !history.isEmpty else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        var todayItems: [WatchMessage.VerseDeliveryPayload] = []
        var yesterdayItems: [WatchMessage.VerseDeliveryPayload] = []
        var earlierItems: [WatchMessage.VerseDeliveryPayload] = []

        for item in history {
            let date = Date(timeIntervalSince1970: item.timestamp)
            let dayStart = calendar.startOfDay(for: date)
            if dayStart >= today {
                todayItems.append(item)
            } else if dayStart >= yesterday {
                yesterdayItems.append(item)
            } else {
                earlierItems.append(item)
            }
        }

        var result: [(title: String, items: [WatchMessage.VerseDeliveryPayload])] = []
        if !todayItems.isEmpty { result.append((title: "Today", items: todayItems)) }
        if !yesterdayItems.isEmpty { result.append((title: "Yesterday", items: yesterdayItems)) }
        if !earlierItems.isEmpty { result.append((title: "Earlier", items: earlierItems)) }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if sections.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(sections, id: \.title) { section in
                            Section(header: sectionHeader(section.title)) {
                                ForEach(section.items, id: \.deliveryID) { verse in
                                    historyRow(verse)
                                        .onTapGesture {
                                            selectedVerse = verse
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("RECENT")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $selectedVerse) { verse in
            VerseDetailSheet(verse: verse)
        }
        .background(Color.psDeepNavy.ignoresSafeArea())
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.5))
            .textCase(nil)
    }

    @ViewBuilder
    private func historyRow(_ verse: WatchMessage.VerseDeliveryPayload) -> some View {
        let date = Date(timeIntervalSince1970: verse.timestamp)
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(verse.stateEmoji)
                    .font(.system(size: 14))
                Text(verse.stateDisplayName)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text(date, style: .time)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Text(verse.verseReference)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.vertical, 2)
        .listRowBackground(Color.psNavy.opacity(0.6))
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Text("📜")
                .font(.system(size: 32))
            Text("No verses yet")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
            Text("Your verse history\nwill appear here")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Verse Detail Sheet

private struct VerseDetailSheet: View {
    let verse: WatchMessage.VerseDeliveryPayload

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    Text(verse.stateEmoji)
                        .font(.system(size: 16))
                    Text(verse.stateDisplayName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                }
                Text(Date(timeIntervalSince1970: verse.timestamp), style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))

                Divider().overlay(.white.opacity(0.2))

                // Verse text
                Text(verse.verseText)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(verse.verseReference) · \(verse.translationAbbreviation)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .background(
            (BiometricState(rawValue: verse.stateRaw)?.gradient) ??
            LinearGradient(colors: [Color.psDeepNavy], startPoint: .top, endPoint: .bottom)
        )
    }
}
