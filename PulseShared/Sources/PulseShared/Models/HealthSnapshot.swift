import Foundation

public struct HealthSnapshot: Codable, Sendable {

    // MARK: - Vitals
    public var heartRate: Double?
    public var heartRateVariability: Double?
    public var restingHeartRate: Double?
    public var respiratoryRate: Double?
    public var oxygenSaturation: Double?
    public var bodyTemperature: Double?
    public var sleepingWristTemperature: Double?   // °C, Apple Watch nightly
    public var walkingHeartRateAverage: Double?
    public var vo2Max: Double?

    // MARK: - Sleep
    public var sleepEfficiency: Double?
    public var deepSleepMinutes: Double?
    public var remSleepMinutes: Double?
    public var lightSleepMinutes: Double?
    public var totalSleepMinutes: Double?
    public var lateNightWakeMinutes: Double?
    public var sleepOnsetMinutes: Double?
    public var bedtime: Date?
    public var wakeTime: Date?

    // MARK: - Activity
    public var activeEnergyBurned: Double?
    public var basalEnergyBurned: Double?
    public var stepCount: Int?
    public var exerciseMinutes: Double?
    public var standHours: Int?
    public var distanceWalkingRunning: Double?
    public var flightsClimbed: Int?
    public var timeInDaylightMinutes: Double?
    public var heartRateRecoveryBPM: Double?

    // MARK: - Mindfulness
    public var mindfulMinutes: Double?

    // MARK: - Recent Workout
    public var lastWorkoutType: String?
    public var lastWorkoutEndedMinutesAgo: Double?
    public var lastWorkoutDurationMinutes: Double?
    public var lastWorkoutCalories: Double?
    public var lastWorkoutHRAvg: Double?

    // MARK: - Metadata
    public var timestamp: Date = .now
    public var dataCompleteness: Double = 0.0

    // MARK: - Computed Properties

    public var sleepQuality: SleepQualityLevel {
        guard let efficiency = sleepEfficiency,
              let total = totalSleepMinutes else { return .unknown }

        switch (efficiency, total) {
        case (let e, let t) where e > 0.90 && t >= 420:  return .excellent
        case (let e, let t) where e > 0.80 && t >= 360:  return .good
        case (let e, let t) where e > 0.70 && t >= 300:  return .fair
        case (_, let t) where t < 240:                    return .veryPoor
        default:                                           return .poor
        }
    }

    public var hrvCategory: HRVCategory {
        guard let hrv = heartRateVariability else { return .unknown }
        switch hrv {
        case ...20:   return .veryLow
        case 20...40: return .low
        case 40...60: return .moderate
        case 60...80: return .high
        default:      return .veryHigh
        }
    }

    public var isPostWorkout: Bool {
        guard let minsAgo = lastWorkoutEndedMinutesAgo else { return false }
        return minsAgo >= 2 && minsAgo <= 60
    }

    // MARK: - Initializer

    public init(
        heartRate: Double? = nil,
        heartRateVariability: Double? = nil,
        restingHeartRate: Double? = nil,
        respiratoryRate: Double? = nil,
        oxygenSaturation: Double? = nil,
        bodyTemperature: Double? = nil,
        walkingHeartRateAverage: Double? = nil,
        vo2Max: Double? = nil,
        sleepEfficiency: Double? = nil,
        deepSleepMinutes: Double? = nil,
        remSleepMinutes: Double? = nil,
        lightSleepMinutes: Double? = nil,
        totalSleepMinutes: Double? = nil,
        lateNightWakeMinutes: Double? = nil,
        sleepOnsetMinutes: Double? = nil,
        bedtime: Date? = nil,
        wakeTime: Date? = nil,
        activeEnergyBurned: Double? = nil,
        basalEnergyBurned: Double? = nil,
        stepCount: Int? = nil,
        exerciseMinutes: Double? = nil,
        standHours: Int? = nil,
        distanceWalkingRunning: Double? = nil,
        flightsClimbed: Int? = nil,
        mindfulMinutes: Double? = nil,
        lastWorkoutType: String? = nil,
        lastWorkoutEndedMinutesAgo: Double? = nil,
        lastWorkoutDurationMinutes: Double? = nil,
        lastWorkoutCalories: Double? = nil,
        lastWorkoutHRAvg: Double? = nil,
        sleepingWristTemperature: Double? = nil,
        timeInDaylightMinutes: Double? = nil,
        heartRateRecoveryBPM: Double? = nil,
        timestamp: Date = .now,
        dataCompleteness: Double = 0.0
    ) {
        self.heartRate = heartRate
        self.heartRateVariability = heartRateVariability
        self.restingHeartRate = restingHeartRate
        self.respiratoryRate = respiratoryRate
        self.oxygenSaturation = oxygenSaturation
        self.bodyTemperature = bodyTemperature
        self.sleepingWristTemperature = sleepingWristTemperature
        self.walkingHeartRateAverage = walkingHeartRateAverage
        self.vo2Max = vo2Max
        self.sleepEfficiency = sleepEfficiency
        self.deepSleepMinutes = deepSleepMinutes
        self.remSleepMinutes = remSleepMinutes
        self.lightSleepMinutes = lightSleepMinutes
        self.totalSleepMinutes = totalSleepMinutes
        self.lateNightWakeMinutes = lateNightWakeMinutes
        self.sleepOnsetMinutes = sleepOnsetMinutes
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.activeEnergyBurned = activeEnergyBurned
        self.basalEnergyBurned = basalEnergyBurned
        self.stepCount = stepCount
        self.exerciseMinutes = exerciseMinutes
        self.standHours = standHours
        self.distanceWalkingRunning = distanceWalkingRunning
        self.flightsClimbed = flightsClimbed
        self.timeInDaylightMinutes = timeInDaylightMinutes
        self.heartRateRecoveryBPM = heartRateRecoveryBPM
        self.mindfulMinutes = mindfulMinutes
        self.lastWorkoutType = lastWorkoutType
        self.lastWorkoutEndedMinutesAgo = lastWorkoutEndedMinutesAgo
        self.lastWorkoutDurationMinutes = lastWorkoutDurationMinutes
        self.lastWorkoutCalories = lastWorkoutCalories
        self.lastWorkoutHRAvg = lastWorkoutHRAvg
        self.timestamp = timestamp
        self.dataCompleteness = dataCompleteness
    }

    // MARK: - Methods

    public mutating func computeCompleteness() {
        let vitalFields: [Any?] = [
            heartRate, heartRateVariability, restingHeartRate,
            respiratoryRate, oxygenSaturation
        ]
        let sleepFields: [Any?] = [sleepEfficiency, totalSleepMinutes]
        let activityFields: [Any?] = [stepCount, activeEnergyBurned]

        let allFields = vitalFields + sleepFields + activityFields
        let presentCount = allFields.compactMap { $0 }.count
        dataCompleteness = Double(presentCount) / Double(allFields.count)
    }

    // MARK: - Nested Types

    public enum SleepQualityLevel: String, Codable, Sendable {
        case excellent, good, fair, poor, veryPoor, unknown
    }

    public enum HRVCategory: String, Codable, Sendable {
        case veryLow, low, moderate, high, veryHigh, unknown
    }
}
