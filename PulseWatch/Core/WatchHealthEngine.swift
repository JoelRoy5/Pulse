import Foundation
import HealthKit
import WatchKit
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse.watchkitapp", category: "WatchHealthEngine")

// MARK: - WatchHealthSnapshot

/// A lightweight snapshot of the four metrics the watch fetches locally.
struct WatchHealthSnapshot: Sendable {
    var heartRate: Double?      // bpm (10-min average)
    var hrv: Double?            // ms (latest 24h SDNN)
    var oxygenSaturation: Double? // fraction 0-1 (1h average)
    var stepCount: Int?         // today's total
    var fetchedAt: Date = .now
}

// MARK: - WatchHealthEngine

/// Thin HKHealthStore wrapper that fetches the 4 metrics relevant to the watch UI.
/// The watch-local fetch result can override the phone-sourced summary when fresher.
@MainActor
final class WatchHealthEngine: ObservableObject {

    static let shared = WatchHealthEngine()

    @Published var snapshot: WatchHealthSnapshot?
    @Published var isAuthorized = false
    @Published var isFetching = false

    private let store = HKHealthStore()

    private static let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        let identifiers: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .heartRateVariabilitySDNN,
            .oxygenSaturation,
            .stepCount
        ]
        for id in identifiers {
            types.insert(HKObjectType.quantityType(forIdentifier: id)!)
        }
        return types
    }()

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.info("HealthKit not available on this device")
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: Self.readTypes)
            isAuthorized = true
            logger.info("WatchHealthEngine: HealthKit authorized")
            await refreshMetrics()
        } catch {
            logger.error("WatchHealthEngine: authorization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Refresh

    func refreshMetrics() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        isFetching = true
        defer { isFetching = false }

        async let hrResult = fetchHeartRate()
        async let hrvResult = fetchHRV()
        async let spo2Result = fetchOxygenSaturation()
        async let stepsResult = fetchSteps()

        let (hr, hrv, spo2, steps) = await (hrResult, hrvResult, spo2Result, stepsResult)

        snapshot = WatchHealthSnapshot(
            heartRate: hr,
            hrv: hrv,
            oxygenSaturation: spo2,
            stepCount: steps,
            fetchedAt: .now
        )
        logger.info("WatchHealthEngine: snapshot refreshed HR=\(hr.map { String($0) } ?? "nil") HRV=\(hrv.map { String($0) } ?? "nil")")
    }

    // MARK: - Individual Fetches

    /// 10-minute average heart rate.
    private func fetchHeartRate() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let end = Date()
        let start = end.addingTimeInterval(-10 * 60)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, error in
                if let error { logger.warning("HR fetch error: \(error.localizedDescription, privacy: .public)") }
                let value = stats?.averageQuantity()?.doubleValue(for: .init(from: "count/min"))
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Latest HRV (SDNN) sample in the last 24 hours.
    private func fetchHRV() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        let end = Date()
        let start = end.addingTimeInterval(-24 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error { logger.warning("HRV fetch error: \(error.localizedDescription, privacy: .public)") }
                let value = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .secondUnit(with: .milli))
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// 1-hour average oxygen saturation (fraction 0-1).
    private func fetchOxygenSaturation() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else { return nil }
        let end = Date()
        let start = end.addingTimeInterval(-3600)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, error in
                if let error { logger.warning("SpO2 fetch error: \(error.localizedDescription, privacy: .public)") }
                let value = stats?.averageQuantity()?.doubleValue(for: .percent())
                // HKUnit.percent() returns a fraction 0-1
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Steps taken today (since midnight).
    private func fetchSteps() async -> Int? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if let error { logger.warning("Steps fetch error: \(error.localizedDescription, privacy: .public)") }
                let value = stats?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: value.map { Int($0) })
            }
            store.execute(query)
        }
    }
}
