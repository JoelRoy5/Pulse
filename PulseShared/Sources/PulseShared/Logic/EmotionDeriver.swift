import Foundation

public struct EmotionDeriver: Sendable {
    public init() {}

    /// Derives energy level from biometric sub-scores.
    /// arousal = max(activityLevel, hrStress * 0.8)
    /// > 0.6 → .high, < 0.3 → .low, else .medium
    public func energy(from s: BiometricSubScores) -> EnergyLevel {
        let arousal = max(s.activityLevel, s.hrStress * 0.8)
        if arousal > 0.6 {
            return .high
        } else if arousal < 0.3 {
            return .low
        } else {
            return .medium
        }
    }

    /// Derives mood tone from biometric sub-scores with optional bias.
    /// score = (hrvRecovery + sleepQuality) / 2 - hrStress * 0.5 + bias
    /// > 0.55 → .positive, < 0.30 → .negative, else .neutral
    public func mood(from s: BiometricSubScores, bias: Double = 0) -> MoodTone {
        let score = (s.hrvRecovery + s.sleepQuality) / 2 - s.hrStress * 0.5 + bias
        if score > 0.55 {
            return .positive
        } else if score < 0.30 {
            return .negative
        } else {
            return .neutral
        }
    }

    /// Derives emotion from biometric state and sub-scores.
    /// If state == .sickUnwell, returns .unwell
    /// Otherwise, returns the emotion grid cell based on derived energy and mood
    public func emotion(for state: BiometricState, subScores: BiometricSubScores, moodBias: Double = 0) -> Emotion {
        if state == .sickUnwell {
            return .unwell
        }
        let energyLevel = energy(from: subScores)
        let moodTone = mood(from: subScores, bias: moodBias)
        return Emotion.grid(energy: energyLevel, mood: moodTone)
    }
}
