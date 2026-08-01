import WidgetKit
import SwiftUI
import PulseShared

// MARK: - Timeline Entry

struct PulseEntry: TimelineEntry {
    let date: Date
    let verse: WatchMessage.VerseDeliveryPayload?
}

// MARK: - Timeline Provider

struct PulseProvider: TimelineProvider {
    private let dataStore = WatchDataStore()

    func placeholder(in context: Context) -> PulseEntry {
        PulseEntry(date: .now, verse: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PulseEntry) -> Void) {
        let verse = dataStore.loadCurrent()
        completion(PulseEntry(date: .now, verse: verse))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PulseEntry>) -> Void) {
        let verse = dataStore.loadCurrent()
        let entry = PulseEntry(date: .now, verse: verse)
        // Policy .never — WidgetCenter.reloadAllTimelines() is called on verse delivery
        completion(Timeline(entries: [entry], policy: .never))
    }
}

// MARK: - Widget Bundle

@main
struct PulseWidgets: WidgetBundle {
    var body: some Widget {
        PulseComplication()
    }
}

// MARK: - Widget Configuration

struct PulseComplication: Widget {
    let kind = "PulseComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseProvider()) { entry in
            PulseComplicationEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Pulse")
        .description("Your scripture and biometric state at a glance.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

// MARK: - Entry View Router

struct PulseComplicationEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PulseEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            RectangularComplicationView(verse: entry.verse)
        case .accessoryCircular:
            CircularComplicationView(verse: entry.verse)
        case .accessoryInline:
            InlineComplicationView(verse: entry.verse)
        case .accessoryCorner:
            CornerComplicationView(verse: entry.verse)
        default:
            RectangularComplicationView(verse: entry.verse)
        }
    }
}
