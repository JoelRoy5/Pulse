import SwiftUI
import SwiftData
import PulseShared

struct InsightsView: View {
    @Query(sort: \ClassificationRecord.timestamp, order: .reverse)
    private var records: [ClassificationRecord]

    private var groups: [DayGroup] {
        InsightsGrouping.byDay(records.map {
            ClassificationEntry(date: $0.timestamp, emotionRaw: $0.emotionRaw,
                                confidence: $0.confidence, wasNeutralFallback: $0.wasNeutralFallback,
                                signalsPresent: $0.signalsPresent)
        })
    }

    var body: some View {
        NavigationStack {
            Group {
                if groups.isEmpty {
                    ContentUnavailableView(
                        "No insights yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text("As Pulse reads your day, your emotions will appear here.")
                    )
                } else {
                    List(groups, id: \.day) { group in
                        HStack {
                            Text(group.day, format: .dateTime.weekday(.wide).month().day())
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                            Spacer()
                            if let emotionRaw = group.emotionRaw, let emotion = Emotion(rawValue: emotionRaw) {
                                Label(emotion.displayName, systemImage: emotion.systemImage)
                                    .font(.system(size: 13))
                                    .foregroundStyle(group.isNeutral ? .secondary : .primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Insights")
        }
        .trackScreen("Insights")
    }
}
