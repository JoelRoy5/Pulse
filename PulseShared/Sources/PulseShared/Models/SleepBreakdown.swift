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
