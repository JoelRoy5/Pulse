import WidgetKit
import SwiftUI

struct PulseEntry: TimelineEntry { let date: Date }

struct PulseProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseEntry { PulseEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (PulseEntry) -> Void) {
        completion(PulseEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PulseEntry>) -> Void) {
        completion(Timeline(entries: [PulseEntry(date: .now)], policy: .never))
    }
}

@main
struct PulseWidgets: WidgetBundle {
    var body: some Widget { PulseComplication() }
}

struct PulseComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PulseComplication", provider: PulseProvider()) { _ in
            Image(systemName: "heart.text.square")
        }
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
