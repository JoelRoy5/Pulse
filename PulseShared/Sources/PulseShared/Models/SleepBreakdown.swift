import Foundation

public struct SleepBreakdown: Codable, Sendable {
    public var inBedMinutes: Double
    public var totalSleepMinutes: Double
    public var deepSleepMinutes: Double
    public var remMinutes: Double
    public var lightSleepMinutes: Double
    public var awakeMinutes: Double
    public var lateNightWakeMinutes: Double
    public var sleepOnsetMinutes: Double
    public var bedtime: Date?
    public var wakeTime: Date?

    public var efficiency: Double {
        guard inBedMinutes > 0 else { return 0.0 }
        return totalSleepMinutes / inBedMinutes
    }

    public var quality: Quality {
        // veryPoor: < 4 hours (< 240 minutes)
        if totalSleepMinutes < 240 {
            return .veryPoor
        }
        // excellent: efficiency > 0.9 AND deepSleepMinutes > 90 AND remMinutes > 90
        if efficiency > 0.9 && deepSleepMinutes > 90 && remMinutes > 90 {
            return .excellent
        }
        // good: efficiency > 0.8 AND deepSleepMinutes > 60
        if efficiency > 0.8 && deepSleepMinutes > 60 {
            return .good
        }
        // fair: efficiency > 0.7 AND totalSleepMinutes >= 300
        if efficiency > 0.7 && totalSleepMinutes >= 300 {
            return .fair
        }
        // poor: efficiency <= 0.7 OR totalSleepMinutes < 300
        return .poor
    }

    public enum Quality: String, Codable, Sendable {
        case excellent, good, fair, poor, veryPoor
    }

    public init(
        inBedMinutes: Double,
        totalSleepMinutes: Double,
        deepSleepMinutes: Double,
        remMinutes: Double,
        lightSleepMinutes: Double,
        awakeMinutes: Double,
        lateNightWakeMinutes: Double,
        sleepOnsetMinutes: Double,
        bedtime: Date? = nil,
        wakeTime: Date? = nil
    ) {
        self.inBedMinutes = inBedMinutes
        self.totalSleepMinutes = totalSleepMinutes
        self.deepSleepMinutes = deepSleepMinutes
        self.remMinutes = remMinutes
        self.lightSleepMinutes = lightSleepMinutes
        self.awakeMinutes = awakeMinutes
        self.lateNightWakeMinutes = lateNightWakeMinutes
        self.sleepOnsetMinutes = sleepOnsetMinutes
        self.bedtime = bedtime
        self.wakeTime = wakeTime
    }
}
