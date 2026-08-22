import Foundation

/// Pure helpers over `HealthSnapshot` used by the recorder and UI.
public enum ClassificationSignals {

    /// True when none of the state-driving signals are present, so the classifier
    /// cannot meaningfully classify (drives the self-report prompt).
    public static func insufficientData(_ s: HealthSnapshot) -> Bool {
        let hasHRV = s.heartRateVariability != nil
        let hasSleep = s.sleepEfficiency != nil || s.totalSleepMinutes != nil
        let hasRestingHR = s.restingHeartRate != nil
        return !(hasHRV || hasSleep || hasRestingHR)
    }

    /// Compact list of which signals were present, for display + tuning.
    public static func signalsPresent(_ s: HealthSnapshot) -> [String] {
        var out: [String] = []
        if s.heartRateVariability != nil { out.append("hrv") }
        if s.restingHeartRate != nil { out.append("restingHR") }
        if s.sleepEfficiency != nil || s.totalSleepMinutes != nil { out.append("sleep") }
        if s.oxygenSaturation != nil { out.append("spo2") }
        if s.respiratoryRate != nil { out.append("respiration") }
        if s.bodyTemperature != nil || s.sleepingWristTemperature != nil { out.append("temperature") }
        if s.timeInDaylightMinutes != nil { out.append("daylight") }
        if s.heartRateRecoveryBPM != nil { out.append("hrRecovery") }
        if s.stepCount != nil || s.activeEnergyBurned != nil { out.append("activity") }
        return out
    }

    /// Whether Home should surface the "how are you feeling?" prompt.
    public static func shouldPromptSelfReport(latestInsufficientData: Bool?) -> Bool {
        latestInsufficientData == true
    }
}

/// Rolling wrist-temperature baseline.
public enum TemperatureBaseline {
    /// Mean of the provided recent nightly wrist temperatures. Returns nil when empty.
    public static func mean(of values: [Double]) -> (mean: Double, count: Int)? {
        guard !values.isEmpty else { return nil }
        return (values.reduce(0, +) / Double(values.count), values.count)
    }
}
