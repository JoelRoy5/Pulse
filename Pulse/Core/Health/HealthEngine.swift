import Foundation
import HealthKit
import Observation
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "HealthEngine")

// MARK: - HealthEngine

/// Central coordinator for health data acquisition and biometric classification.
///
/// On each `refresh()` call it:
///  1. Fetches a fresh `HealthSnapshot` from its `provider`.
///  2. Classifies the snapshot via `StateClassifier`.
///  3. Publishes the results to `currentSnapshot` / `currentClassification`.
///  4. Calls `onClassification` with the result (used by Task 10 ScriptureEngine).
@Observable
@MainActor
final class HealthEngine {

    // MARK: - Published State

    var currentSnapshot: HealthSnapshot?
    var currentClassification: ClassificationResult?

    // MARK: - Callback Hook

    /// Set by Task 10's ScriptureEngine to receive classification updates.
    var onClassification: ((ClassificationResult) async -> Void)?

    // MARK: - Recorder

    /// Injected from PulseApp; records every classification result on-device.
    var recorder: ClassificationRecorder?

    // MARK: - Private

    private let provider: any HealthDataProviding
    private let classifier = StateClassifier()
    private var observerQueries: [HKObserverQuery] = []
    private let healthStore = HKHealthStore()

    // MARK: - Initialisation

    init(provider: any HealthDataProviding) {
        self.provider = provider
    }

    /// Convenience initialiser used by `PulseApp` that picks the right provider
    /// based on launch arguments and HealthKit availability.
    convenience init() {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-PulseMockState"),
           idx + 1 < args.count,
           let state = BiometricState(rawValue: args[idx + 1]) {
            logger.info("Using MockHealthProvider for state: \(state.rawValue, privacy: .public)")
            self.init(provider: MockHealthProvider(scenario: state))
        } else if !HKHealthStore.isHealthDataAvailable() {
            logger.info("HealthKit unavailable — using MockHealthProvider(.exhaustedDepleted)")
            self.init(provider: MockHealthProvider())
        } else {
            self.init(provider: MetricCollector())
        }
    }

    // MARK: - Public API

    func requestAuthorization() async throws {
        try await provider.requestAuthorization()
    }

    /// Pushes updated metric toggles from UserPreferences into the underlying
    /// `MetricCollector` so the next `refresh()` honours the user's selections.
    /// No-op when the provider is a mock (simulator or -PulseMockState).
    func updateMetricToggles(_ toggles: MetricToggles) {
        guard let collector = provider as? MetricCollector else { return }
        collector.toggles = toggles
        logger.info("Metric toggles updated: HR=\(toggles.useHeartRate) HRV=\(toggles.useHRV) sleep=\(toggles.useSleep)")
    }

    func refresh() async {
        do {
            let snapshot = try await provider.fetchSnapshot()
            let baseline = await recorder?.wristTempBaseline()
            let result = classifier.classify(snapshot, wristTempBaseline: baseline)
            currentSnapshot = snapshot
            currentClassification = result
            logger.info(
                "Classified: \(result.state.rawValue, privacy: .public) @ \(String(format: "%.2f", result.confidence), privacy: .public)"
            )
            await recorder?.record(result, snapshot: snapshot)
            if let callback = onClassification {
                await callback(result)
            }
        } catch {
            logger.error("refresh() failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Background Delivery

    /// Registers `HKObserverQuery` for five vital types and enables hourly
    /// background delivery.  Sleep and workout get immediate delivery.
    /// All errors are caught and logged; this method never throws to callers.
    func enableBackgroundDelivery() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let vitalTypes: [HKQuantityType] = [
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.respiratoryRate),
        ]

        for type in vitalTypes {
            healthStore.enableBackgroundDelivery(for: type, frequency: .hourly) { [weak self] success, error in
                if let error {
                    logger.warning(
                        "Background delivery failed for \(type.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                    return
                }
                if success {
                    Task { @MainActor [weak self] in
                        self?.setupObserverQuery(for: type)
                    }
                }
            }
        }

        // Sleep — immediate trigger
        let sleepType = HKCategoryType(.sleepAnalysis)
        healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { [weak self] success, error in
            if let error {
                logger.warning("Sleep background delivery failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            if success {
                Task { @MainActor [weak self] in
                    self?.setupObserverQuery(for: sleepType)
                }
            }
        }

        // Workout — immediate trigger on completion
        let workoutType = HKObjectType.workoutType()
        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { [weak self] success, error in
            if let error {
                logger.warning("Workout background delivery failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            if success {
                Task { @MainActor [weak self] in
                    self?.setupObserverQuery(for: workoutType)
                }
            }
        }
    }

    // MARK: - Observer Query

    private func setupObserverQuery(for type: HKSampleType) {
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
            if let error {
                logger.warning(
                    "Observer query error for \(type.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                completionHandler()
                return
            }
            Task { @MainActor [weak self] in
                await self?.refresh()
                completionHandler()
            }
        }
        observerQueries.append(query)
        healthStore.execute(query)
        logger.debug("Observer query registered for \(type.identifier, privacy: .public)")
    }
}
