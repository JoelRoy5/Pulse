import Foundation

public struct ClassificationEntry: Sendable {
    public let date: Date
    public let emotionRaw: String
    public let confidence: Double
    public let wasNeutralFallback: Bool
    public let signalsPresent: [String]

    public init(date: Date, emotionRaw: String, confidence: Double,
                wasNeutralFallback: Bool, signalsPresent: [String]) {
        self.date = date; self.emotionRaw = emotionRaw; self.confidence = confidence
        self.wasNeutralFallback = wasNeutralFallback; self.signalsPresent = signalsPresent
    }
}

public struct DayGroup: Sendable, Equatable {
    public let day: Date          // start-of-day
    public let emotionRaw: String?
    public let isNeutral: Bool
}

public enum InsightsGrouping {

    /// Groups entries by calendar day, newest day first. A day's representative
    /// emotion is the most recent non-fallback entry; if all are fallbacks the day
    /// is marked neutral (using the most recent entry's emotion).
    public static func byDay(_ entries: [ClassificationEntry], calendar: Calendar = .current) -> [DayGroup] {
        let buckets = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        return buckets.keys.sorted(by: >).map { day in
            let dayEntries = buckets[day]!.sorted { $0.date > $1.date }
            if let real = dayEntries.first(where: { !$0.wasNeutralFallback }) {
                return DayGroup(day: day, emotionRaw: real.emotionRaw, isNeutral: false)
            }
            return DayGroup(day: day, emotionRaw: dayEntries.first?.emotionRaw, isNeutral: true)
        }
    }

    public static func signalLabel(_ key: String) -> String {
        switch key {
        case "hrv": return "HRV"
        case "restingHR": return "Resting HR"
        case "sleep": return "Sleep"
        case "spo2": return "Blood oxygen"
        case "respiration": return "Respiration"
        case "temperature": return "Temperature"
        case "daylight": return "Daylight"
        case "hrRecovery": return "HR recovery"
        case "activity": return "Activity"
        default: return key
        }
    }
}
