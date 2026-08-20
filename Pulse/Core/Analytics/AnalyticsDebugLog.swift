#if DEBUG
import Foundation
import Observation

// MARK: - RecordedEvent

struct RecordedEvent: Identifiable {
    let id: UUID
    let name: String
    let props: [String: Any]
    let at: Date
    /// Whether the event was actually sent (i.e. analytics was enabled + configured).
    let wasSent: Bool

    init(name: String, props: [String: Any], at: Date, wasSent: Bool) {
        self.id = UUID()
        self.name = name
        self.props = props
        self.at = at
        self.wasSent = wasSent
    }
}

// MARK: - AnalyticsDebugLog

/// DEBUG-only in-memory ring buffer that stores the last 100 analytics events.
/// Conforms to `@Observable` so views update live whenever events are appended.
@Observable
@MainActor
final class AnalyticsDebugLog {

    static let shared = AnalyticsDebugLog()

    private static let capacity = 100

    /// Most-recent-first ordered list of recorded events.
    private(set) var events: [RecordedEvent] = []

    private init() {}

    /// Append an event, dropping the oldest when the ring buffer is full.
    func append(name: String, props: [String: Any], at date: Date = Date(), wasSent: Bool) {
        let event = RecordedEvent(name: name, props: props, at: date, wasSent: wasSent)
        events.insert(event, at: 0)
        if events.count > AnalyticsDebugLog.capacity {
            events.removeLast()
        }
    }

    /// Remove all recorded events from the buffer.
    func clear() {
        events.removeAll()
    }
}
#endif
