import Foundation
import SwiftData

/// One record per classification (delivered or not) — the on-device tuning log
/// that powers the Insights view. Never leaves the device.
@Model
final class ClassificationRecord {
    var timestamp: Date
    var emotionRaw: String          // Emotion.rawValue (user-facing)
    var stateRaw: String            // BiometricState.rawValue (internal)
    var confidence: Double
    var wasNeutralFallback: Bool
    var insufficientData: Bool
    var signalsPresent: [String]
    var sleepingWristTemperature: Double?   // raw °C, for baseline computation
    var timeInDaylightMinutes: Double?
    var heartRateRecoveryBPM: Double?

    init(
        timestamp: Date = .now,
        emotionRaw: String,
        stateRaw: String,
        confidence: Double,
        wasNeutralFallback: Bool,
        insufficientData: Bool,
        signalsPresent: [String],
        sleepingWristTemperature: Double? = nil,
        timeInDaylightMinutes: Double? = nil,
        heartRateRecoveryBPM: Double? = nil
    ) {
        self.timestamp = timestamp
        self.emotionRaw = emotionRaw
        self.stateRaw = stateRaw
        self.confidence = confidence
        self.wasNeutralFallback = wasNeutralFallback
        self.insufficientData = insufficientData
        self.signalsPresent = signalsPresent
        self.sleepingWristTemperature = sleepingWristTemperature
        self.timeInDaylightMinutes = timeInDaylightMinutes
        self.heartRateRecoveryBPM = heartRateRecoveryBPM
    }
}
