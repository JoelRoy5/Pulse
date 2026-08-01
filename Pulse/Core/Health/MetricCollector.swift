import Foundation
import HealthKit
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "MetricCollector")

// MARK: - MetricToggles

/// Snapshot of UserPreferences metric toggle values passed into MetricCollector.
/// All fields default to `true` so that the collector works correctly when no
/// UserPreferences row exists (first launch, simulator, etc.).
struct MetricToggles: Sendable {
    var useHeartRate:   Bool = true
    var useHRV:         Bool = true
    var useSleep:       Bool = true
    var useOxygen:      Bool = true
    var useRespiration: Bool = true
    var useBodyTemp:    Bool = false
    var useActivity:    Bool = true
    var useVO2Max:      Bool = true
    var useMindfulness: Bool = true

    static let defaults = MetricToggles()
}

// MARK: - MetricCollector

/// Real HealthKit implementation of `HealthDataProviding`.
/// Each metric is fetched in a separate failure-isolated async task; a failed
/// query yields `nil` for that field and never propagates an error out of
/// `fetchSnapshot()`.
///
/// Metric toggles (sourced from `UserPreferences`) gate which fields are
/// requested from HealthKit. A disabled metric yields `nil` in the snapshot
/// and is ignored by `StateClassifier`.
final class MetricCollector: HealthDataProviding, @unchecked Sendable {

    // MARK: - Properties

    private let healthStore = HKHealthStore()

    /// Toggled by SettingsView via `HealthEngine.updateMetricToggles(_:)`.
    /// Mutations are always performed on the MainActor; reads happen on an
    /// arbitrary background task — the struct is value-typed so copying is safe.
    var toggles: MetricToggles = .defaults

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Read / Write Type Sets

    static let readTypes: Set<HKObjectType> = [
        // Vitals
        HKQuantityType(.heartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.respiratoryRate),
        HKQuantityType(.oxygenSaturation),
        HKQuantityType(.bodyTemperature),
        HKQuantityType(.bloodPressureSystolic),
        HKQuantityType(.bloodPressureDiastolic),
        // Activity
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.basalEnergyBurned),
        HKQuantityType(.stepCount),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.flightsClimbed),
        HKQuantityType(.vo2Max),
        HKQuantityType(.appleExerciseTime),
        HKQuantityType(.appleStandTime),
        HKQuantityType(.walkingHeartRateAverage),
        // Sleep
        HKCategoryType(.sleepAnalysis),
        // Mindfulness
        HKCategoryType(.mindfulSession),
        // Workout
        HKObjectType.workoutType(),
    ]

    static let writeTypes: Set<HKSampleType> = [
        HKCategoryType(.mindfulSession),
    ]

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await healthStore.requestAuthorization(
            toShare: MetricCollector.writeTypes,
            read: MetricCollector.readTypes
        )
    }

    // MARK: - fetchSnapshot

    /// Fetches all metrics concurrently via `async let`.
    /// Every individual fetch is wrapped so that a failure yields `nil` for that
    /// metric and does not interrupt the overall snapshot construction.
    ///
    /// Metrics disabled in `toggles` (from UserPreferences) are short-circuited
    /// to `nil` without issuing a HealthKit query — they will not influence
    /// `StateClassifier` results.
    func fetchSnapshot() async throws -> HealthSnapshot {
        // Capture toggles once on the calling actor — avoids data-race reading
        // a stored property from a concurrent context.
        let t = toggles

        async let heartRate         = t.useHeartRate   ? fetchHeartRate()        : nil as Double?
        async let hrv               = t.useHRV         ? fetchHRV()              : nil as Double?
        async let restingHR         = t.useHeartRate   ? fetchRestingHR()        : nil as Double?
        async let respiratoryRate   = t.useRespiration ? fetchRespiratoryRate()  : nil as Double?
        async let oxygenSaturation  = t.useOxygen      ? fetchOxygenSaturation() : nil as Double?
        async let bodyTemperature   = t.useBodyTemp    ? fetchBodyTemperature()  : nil as Double?
        async let activeEnergy      = t.useActivity    ? fetchActiveEnergy()     : nil as Double?
        async let basalEnergy       = t.useActivity    ? fetchBasalEnergy()      : nil as Double?
        async let stepCount         = t.useActivity    ? fetchStepCount()        : nil as Int?
        async let exerciseMinutes   = t.useActivity    ? fetchExerciseMinutes()  : nil as Double?
        async let standHours        = t.useActivity    ? fetchStandHours()       : nil as Int?
        async let distance          = t.useActivity    ? fetchDistance()          : nil as Double?
        async let flightsClimbed    = t.useActivity    ? fetchFlightsClimbed()   : nil as Int?
        async let walkingHRAvg      = t.useHeartRate   ? fetchWalkingHRAverage() : nil as Double?
        async let vo2Max            = t.useVO2Max      ? fetchVO2Max()            : nil as Double?
        async let mindfulMinutes    = t.useMindfulness ? fetchMindfulMinutes()   : nil as Double?
        async let sleepData         = t.useSleep       ? fetchSleepData()         : nil as SleepBreakdown?
        async let workout           = t.useActivity    ? fetchLastWorkout()       : nil as WorkoutInfo?

        let hrValue          = await heartRate
        let hrvValue         = await hrv
        let restingHRValue   = await restingHR
        let respValue        = await respiratoryRate
        let spo2Value        = await oxygenSaturation
        let tempValue        = await bodyTemperature
        let activeCalValue   = await activeEnergy
        let basalCalValue    = await basalEnergy
        let stepsValue       = await stepCount
        let exMinsValue      = await exerciseMinutes
        let standHrsValue    = await standHours
        let distValue        = await distance
        let flightsValue     = await flightsClimbed
        let walkHRValue      = await walkingHRAvg
        let vo2Value         = await vo2Max
        let mindfulValue     = await mindfulMinutes
        let sleep            = await sleepData
        let workoutData      = await workout

        var snapshot = HealthSnapshot(
            heartRate: hrValue,
            heartRateVariability: hrvValue,
            restingHeartRate: restingHRValue,
            respiratoryRate: respValue,
            oxygenSaturation: spo2Value,
            bodyTemperature: tempValue,
            walkingHeartRateAverage: walkHRValue,
            vo2Max: vo2Value,
            sleepEfficiency: sleep?.efficiency,
            deepSleepMinutes: sleep?.deepSleepMinutes,
            remSleepMinutes: sleep?.remMinutes,
            lightSleepMinutes: sleep?.lightSleepMinutes,
            totalSleepMinutes: sleep?.totalSleepMinutes,
            lateNightWakeMinutes: sleep?.lateNightWakeMinutes,
            sleepOnsetMinutes: sleep?.sleepOnsetMinutes,
            bedtime: sleep?.bedtime,
            wakeTime: sleep?.wakeTime,
            activeEnergyBurned: activeCalValue,
            basalEnergyBurned: basalCalValue,
            stepCount: stepsValue,
            exerciseMinutes: exMinsValue,
            standHours: standHrsValue,
            distanceWalkingRunning: distValue,
            flightsClimbed: flightsValue,
            mindfulMinutes: mindfulValue,
            lastWorkoutType: workoutData?.type,
            lastWorkoutEndedMinutesAgo: workoutData?.endedMinutesAgo,
            lastWorkoutDurationMinutes: workoutData?.durationMinutes,
            lastWorkoutCalories: workoutData?.calories,
            lastWorkoutHRAvg: workoutData?.hrAvg
        )
        snapshot.computeCompleteness()
        return snapshot
    }

    // MARK: - Private Fetch Helpers

    // Heart Rate — last 10 minutes average
    private func fetchHeartRate() async -> Double? {
        let type = HKQuantityType(.heartRate)
        let start = Date().addingTimeInterval(-10 * 60)
        return await fetchQuantityStatistics(
            type: type,
            start: start,
            end: .now,
            options: .discreteAverage,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
    }

    // HRV (SDNN) — most recent sample in last 24 hours
    private func fetchHRV() async -> Double? {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let start = Date().addingTimeInterval(-24 * 60 * 60)
        return await fetchMostRecentSample(
            type: type,
            start: start,
            end: .now,
            unit: .secondUnit(with: .milli)
        )
    }

    // Resting HR — today's value (HealthKit computed daily)
    private func fetchRestingHR() async -> Double? {
        let type = HKQuantityType(.restingHeartRate)
        let start = Calendar.current.startOfDay(for: .now)
        return await fetchQuantityStatistics(
            type: type,
            start: start,
            end: .now,
            options: .discreteAverage,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
    }

    // Respiratory Rate — average over last 1 hour
    private func fetchRespiratoryRate() async -> Double? {
        let type = HKQuantityType(.respiratoryRate)
        let start = Date().addingTimeInterval(-60 * 60)
        return await fetchQuantityStatistics(
            type: type,
            start: start,
            end: .now,
            options: .discreteAverage,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
    }

    // SpO2 — most recent valid reading in last 1 hour
    private func fetchOxygenSaturation() async -> Double? {
        let type = HKQuantityType(.oxygenSaturation)
        let start = Date().addingTimeInterval(-60 * 60)
        return await fetchQuantityStatistics(
            type: type,
            start: start,
            end: .now,
            options: .discreteAverage,
            unit: .percent()
        )
    }

    // Body Temperature — most recent sample in last 24 hours
    private func fetchBodyTemperature() async -> Double? {
        let type = HKQuantityType(.bodyTemperature)
        let start = Date().addingTimeInterval(-24 * 60 * 60)
        return await fetchMostRecentSample(
            type: type,
            start: start,
            end: .now,
            unit: .degreeCelsius()
        )
    }

    // Active Energy — cumulative today
    private func fetchActiveEnergy() async -> Double? {
        let type = HKQuantityType(.activeEnergyBurned)
        let start = Calendar.current.startOfDay(for: .now)
        return await fetchQuantityStatistics(
            type: type,
            start: start,
            end: .now,
            options: .cumulativeSum,
            unit: .kilocalorie()
        )
    }

    // Basal Energy — cumulative today
    private func fetchBasalEnergy() async -> Double? {
        let type = HKQuantityType(.basalEnergyBurned)
        let start = Calendar.current.startOfDay(for: .now)
        return await fetchQuantityStatistics(
            type: type,
            start: start,
            end: .now,
            options: .cumulativeSum,
            unit: .kilocalorie()
        )
    }

    // Step Count — cumulative today
    private func fetchStepCount() async -> Int? {
        let type = HKQuantityType(.stepCount)
        let start = Calendar.current.startOfDay(for: .now)
        let value = await fetchQuantityStatistics(
            type: type,
            start: start,
            end: .now,
            options: .cumulativeSum,
            unit: .count()
        )
        return value.map { Int($0) }
    }

    // Exercise Minutes — Apple Exercise Time today
    private func fetchExerciseMinutes() async -> Double? {
        let type = HKQuantityType(.appleExerciseTime)
        let start = Calendar.current.startOfDay(for: .now)
        return await fetchQuantityStatistics(
            type: type,
            start: start,
            end: .now,
            options: .cumulativeSum,
            unit: .minute()
        )
    }

    // Stand Hours — Apple Stand Time today
    private func fetchStandHours() async -> Int? {
        let type = HKQuantityType(.appleStandTime)
        let start = Calendar.current.startOfDay(for: .now)
        let value = await fetchQuantityStatistics(
            type: type,
            start: start,
            end: .now,
            options: .cumulativeSum,
            unit: .hour()
        )
        return value.map { Int($0) }
    }

    // Distance Walking/Running — today
    private func fetchDistance() async -> Double? {
        let type = HKQuantityType(.distanceWalkingRunning)
        let start = Calendar.current.startOfDay(for: .now)
        return await fetchQuantityStatistics(
            type: type,
            start: start,
            end: .now,
            options: .cumulativeSum,
            unit: .meter()
        )
    }

    // Flights Climbed — today
    private func fetchFlightsClimbed() async -> Int? {
        let type = HKQuantityType(.flightsClimbed)
        let start = Calendar.current.startOfDay(for: .now)
        let value = await fetchQuantityStatistics(
            type: type,
            start: start,
            end: .now,
            options: .cumulativeSum,
            unit: .count()
        )
        return value.map { Int($0) }
    }

    // Walking HR Average — today
    private func fetchWalkingHRAverage() async -> Double? {
        let type = HKQuantityType(.walkingHeartRateAverage)
        let start = Calendar.current.startOfDay(for: .now)
        return await fetchQuantityStatistics(
            type: type,
            start: start,
            end: .now,
            options: .discreteAverage,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
    }

    // VO2 Max — most recent in last 7 days
    private func fetchVO2Max() async -> Double? {
        let type = HKQuantityType(.vo2Max)
        let start = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        return await fetchMostRecentSample(
            type: type,
            start: start,
            end: .now,
            unit: HKUnit(from: "ml/kg*min")
        )
    }

    // Mindful Minutes — today
    private func fetchMindfulMinutes() async -> Double? {
        let type = HKCategoryType(.mindfulSession)
        let start = Calendar.current.startOfDay(for: .now)
        return await fetchMindfulDuration(type: type, start: start, end: .now)
    }

    // Sleep Data — last 24 hours, analysed via SleepAnalyzer
    private func fetchSleepData() async -> SleepBreakdown? {
        let type = HKCategoryType(.sleepAnalysis)
        let start = Date().addingTimeInterval(-24 * 60 * 60)
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: .now,
                options: .strictStartDate
            )
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    logger.warning("Sleep query failed: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let categorySamples = samples as? [HKCategorySample], !categorySamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let sleepSamples = categorySamples.compactMap { sample -> SleepSample? in
                    guard let stage = Self.sleepStage(from: sample.value) else { return nil }
                    return SleepSample(stage: stage, start: sample.startDate, end: sample.endDate)
                }
                let breakdown = SleepAnalyzer().analyze(samples: sleepSamples)
                continuation.resume(returning: breakdown)
            }
            healthStore.execute(query)
        }
    }

    // Last Workout — within last 3 hours
    private struct WorkoutInfo {
        let type: String
        let endedMinutesAgo: Double
        let durationMinutes: Double
        let calories: Double?
        let hrAvg: Double?
    }

    private func fetchLastWorkout() async -> WorkoutInfo? {
        let start = Date().addingTimeInterval(-3 * 60 * 60)
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: .now,
                options: .strictEndDate
            )
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    logger.warning("Workout query failed: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let workout = samples?.first as? HKWorkout else {
                    continuation.resume(returning: nil)
                    return
                }
                let endedMinutesAgo = Date().timeIntervalSince(workout.endDate) / 60.0
                let durationMinutes = workout.duration / 60.0
                let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                    .sumQuantity()?.doubleValue(for: .kilocalorie())
                let hrAvg = workout.statistics(for: HKQuantityType(.heartRate))?
                    .averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                let info = WorkoutInfo(
                    type: workout.workoutActivityType.name,
                    endedMinutesAgo: endedMinutesAgo,
                    durationMinutes: durationMinutes,
                    calories: calories,
                    hrAvg: hrAvg
                )
                continuation.resume(returning: info)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Generic Query Helpers

    private func fetchQuantityStatistics(
        type: HKQuantityType,
        start: Date,
        end: Date,
        options: HKStatisticsOptions,
        unit: HKUnit
    ) async -> Double? {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: .strictStartDate
            )
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options
            ) { _, statistics, error in
                if let error {
                    logger.warning(
                        "\(type.identifier, privacy: .public) statistics query failed: \(error.localizedDescription, privacy: .public)"
                    )
                    continuation.resume(returning: nil)
                    return
                }
                let quantity: HKQuantity?
                switch options {
                case .cumulativeSum: quantity = statistics?.sumQuantity()
                case .discreteAverage: quantity = statistics?.averageQuantity()
                case .discreteMax: quantity = statistics?.maximumQuantity()
                case .discreteMin: quantity = statistics?.minimumQuantity()
                default: quantity = statistics?.averageQuantity()
                }
                continuation.resume(returning: quantity?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func fetchMostRecentSample(
        type: HKQuantityType,
        start: Date,
        end: Date,
        unit: HKUnit
    ) async -> Double? {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: .strictStartDate
            )
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    logger.warning(
                        "\(type.identifier, privacy: .public) sample query failed: \(error.localizedDescription, privacy: .public)"
                    )
                    continuation.resume(returning: nil)
                    return
                }
                let value = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchMindfulDuration(
        type: HKCategoryType,
        start: Date,
        end: Date
    ) async -> Double? {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: .strictStartDate
            )
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    logger.warning("Mindful session query failed: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let samples, !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let totalMinutes = samples
                    .map { $0.endDate.timeIntervalSince($0.startDate) / 60.0 }
                    .reduce(0, +)
                continuation.resume(returning: totalMinutes)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Sleep Stage Mapping

    private static func sleepStage(from value: Int) -> SleepStage? {
        guard let hkValue = HKCategoryValueSleepAnalysis(rawValue: value) else { return nil }
        switch hkValue {
        case .inBed:             return .inBed
        case .awake:             return .awake
        case .asleepCore:        return .core
        case .asleepDeep:        return .deep
        case .asleepREM:         return .rem
        case .asleepUnspecified: return .unspecified
        @unknown default:        return nil
        }
    }
}

// MARK: - HKWorkoutActivityType name helper

private extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running:           return "running"
        case .cycling:           return "cycling"
        case .walking:           return "walking"
        case .swimming:          return "swimming"
        case .yoga:              return "yoga"
        case .functionalStrengthTraining: return "strength_training"
        case .highIntensityIntervalTraining: return "hiit"
        case .hiking:            return "hiking"
        case .dance:             return "dance"
        case .rowing:            return "rowing"
        case .elliptical:        return "elliptical"
        default:                 return "other"
        }
    }
}
