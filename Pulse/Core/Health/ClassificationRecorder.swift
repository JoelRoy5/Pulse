import Foundation
import SwiftData
import PulseShared

/// Writes one ClassificationRecord per classification and prunes old ones.
/// On-device only. Also computes the rolling wrist-temperature baseline.
@MainActor
final class ClassificationRecorder {
    private let context: ModelContext
    private let retentionDays = 90
    private let baselineNights = 14

    init(context: ModelContext) {
        self.context = context
    }

    func record(_ result: ClassificationResult, snapshot: HealthSnapshot) {
        let record = ClassificationRecord(
            emotionRaw: result.emotion.rawValue,
            stateRaw: result.state.rawValue,
            confidence: result.confidence,
            wasNeutralFallback: result.confidence < 0.65,
            insufficientData: ClassificationSignals.insufficientData(snapshot),
            signalsPresent: ClassificationSignals.signalsPresent(snapshot),
            sleepingWristTemperature: snapshot.sleepingWristTemperature,
            timeInDaylightMinutes: snapshot.timeInDaylightMinutes,
            heartRateRecoveryBPM: snapshot.heartRateRecoveryBPM
        )
        context.insert(record)
        prune()
        try? context.save()
    }

    /// Mean of the most recent nightly wrist temperatures (last `baselineNights`
    /// records that have one). Nil when none.
    func wristTempBaseline() -> (mean: Double, count: Int)? {
        var descriptor = FetchDescriptor<ClassificationRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        let recent = (try? context.fetch(descriptor)) ?? []
        let temps = recent.compactMap { $0.sleepingWristTemperature }.prefix(baselineNights)
        return TemperatureBaseline.mean(of: Array(temps))
    }

    private func prune() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: .now) ?? .distantPast
        let predicate = #Predicate<ClassificationRecord> { $0.timestamp < cutoff }
        try? context.delete(model: ClassificationRecord.self, where: predicate)
    }
}
