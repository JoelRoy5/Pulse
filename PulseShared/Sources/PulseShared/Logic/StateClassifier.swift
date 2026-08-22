import Foundation

/// Classifies a ``HealthSnapshot`` into one of 12 ``BiometricState`` values.
///
/// Architecture: a multi-dimensional scoring matrix — each state defines a confidence
/// function (0.0–1.0). The highest confidence above 0.65 wins; otherwise a
/// time-of-day fallback at confidence 0.5 is returned.
public struct StateClassifier {

    public init() {}

    // MARK: - Public API

    public func classify(
        _ snapshot: HealthSnapshot,
        at date: Date = .now,
        calendar: Calendar = .current,
        wristTempBaseline: (mean: Double, count: Int)? = nil
    ) -> ClassificationResult {
        let scores = computeSubScores(snapshot, at: date, calendar: calendar)
        let fever = feverScore(snapshot, wristTempBaseline: wristTempBaseline)

        let candidates: [(BiometricState, Double)] = [
            (.energizedPostWorkout, victoryLapConfidence(snapshot, scores)),
            (.stressedAnxious,      stressedConfidence(snapshot, scores)),
            (.exhaustedDepleted,    exhaustedConfidence(snapshot, scores)),
            (.deepRestRecovered,    sabbathMorningConfidence(snapshot, scores)),
            (.peacefulSteady,       peacefulConfidence(snapshot, scores)),
            (.morningAwakening,     morningConfidence(snapshot, scores, at: date, calendar: calendar)),
            (.eveningWindingDown,   eveningConfidence(snapshot, scores)),
            (.activeEngaged,        activeConfidence(snapshot, scores)),
            (.sadWithdrawn,         sadConfidence(snapshot, scores)),
            (.sickUnwell,           sickConfidence(snapshot, scores, feverScore: fever)),
            (.peakPerformance,      peakConfidence(snapshot, scores)),
            (.spiritualAlert,       watchmanConfidence(snapshot, scores)),
        ]

        // Safe unwrap: array is non-empty literal, but avoid force-unwrap per spec
        guard let best = candidates.max(by: { $0.1 < $1.1 }) else {
            let fallback = timeOfDayFallback(scores.timeOfDay)
            let emotion = EmotionDeriver().emotion(for: fallback, subScores: scores)
            return ClassificationResult(
                state: fallback,
                emotion: emotion,
                confidence: 0.5,
                snapshot: snapshot,
                subScores: scores
            )
        }

        if best.1 >= 0.65 {
            let state = best.0
            let emotion = EmotionDeriver().emotion(for: state, subScores: scores)
            return ClassificationResult(
                state: state,
                emotion: emotion,
                confidence: best.1,
                snapshot: snapshot,
                subScores: scores
            )
        } else {
            let fallback = timeOfDayFallback(scores.timeOfDay)
            let emotion = EmotionDeriver().emotion(for: fallback, subScores: scores)
            return ClassificationResult(
                state: fallback,
                emotion: emotion,
                confidence: 0.5,
                snapshot: snapshot,
                subScores: scores
            )
        }
    }

    // MARK: - Sub-Score Computation

    /// Computes all biometric sub-scores from a raw ``HealthSnapshot``.
    /// Verbatim from `Instructions/03_HEALTH_ENGINE.md` lines 239–299 with
    /// nil defaults: hrStress=0.5, hrvRecovery=0.5, sleepQuality=0.5, oxygenLevel=0.7,
    /// activityLevel computed from zeros, respiratoryStress=0.5.
    public func computeSubScores(
        _ snapshot: HealthSnapshot,
        at date: Date = .now,
        calendar: Calendar = .current
    ) -> BiometricSubScores {
        BiometricSubScores(
            hrStress:         hrStressScore(from: snapshot),
            hrvRecovery:      hrvScore(from: snapshot),
            sleepQuality:     sleepScore(from: snapshot),
            oxygenLevel:      oxygenScore(from: snapshot),
            activityLevel:    activityScore(from: snapshot),
            respiratoryStress: respiratoryStressScore(from: snapshot),
            timeOfDay:        TimeOfDay(date: date, calendar: calendar)
        )
    }

    // MARK: - Sub-Score Formulas (verbatim from doc-03 lines 239–299)

    private func hrStressScore(from snapshot: HealthSnapshot) -> Double {
        guard let hr = snapshot.heartRate,
              let rhr = snapshot.restingHeartRate else { return 0.5 }
        let elevationRatio = hr / rhr
        return max(0, min(1, 1.0 - ((elevationRatio - 1.0) / 1.5)))
    }

    private func hrvScore(from snapshot: HealthSnapshot) -> Double {
        guard let hrv = snapshot.heartRateVariability else { return 0.5 }
        return max(0, min(1, (hrv - 20.0) / 60.0))
    }

    private func sleepScore(from snapshot: HealthSnapshot) -> Double {
        guard let efficiency = snapshot.sleepEfficiency,
              let total = snapshot.totalSleepMinutes else { return 0.5 }

        let effScore      = max(0, min(1, (efficiency - 0.65) / 0.30))
        let durationScore = max(0, min(1, (total - 240) / 240))
        let deepScore: Double
        if let deep = snapshot.deepSleepMinutes {
            deepScore = max(0, min(1, deep / 90.0))
        } else {
            deepScore = 0.5
        }
        return effScore * 0.4 + durationScore * 0.4 + deepScore * 0.2
    }

    private func oxygenScore(from snapshot: HealthSnapshot) -> Double {
        guard let spo2 = snapshot.oxygenSaturation else { return 0.7 }
        return max(0, min(1, (spo2 - 0.94) / 0.06))
    }

    private func activityScore(from snapshot: HealthSnapshot) -> Double {
        let steps    = Double(snapshot.stepCount ?? 0)
        let calories = snapshot.activeEnergyBurned ?? 0
        let exercise = snapshot.exerciseMinutes ?? 0

        let stepScore = min(1.0, steps / 8000.0)
        let calScore  = min(1.0, calories / 500.0)
        let exScore   = min(1.0, exercise / 30.0)

        return stepScore * 0.4 + calScore * 0.3 + exScore * 0.3
    }

    /// respiratoryStress: 1.0 at ≤16 breaths/min, linearly down to 0.0 at 24,
    /// requires both restingHeartRate and respiratoryRate present for sick confidence;
    /// this score alone uses respiratoryRate or defaults 0.5.
    private func respiratoryStressScore(from snapshot: HealthSnapshot) -> Double {
        guard let rate = snapshot.respiratoryRate else { return 0.5 }
        if rate <= 16 { return 1.0 }
        if rate >= 24 { return 0.0 }
        return 1.0 - (rate - 16.0) / (24.0 - 16.0)
    }

    // MARK: - Five Spec'd Confidence Functions (verbatim from doc-03 lines 304–358)

    /// energizedPostWorkout — Victory Lap.
    private func victoryLapConfidence(
        _ snapshot: HealthSnapshot,
        _ scores: BiometricSubScores
    ) -> Double {
        guard let workoutEnd = snapshot.lastWorkoutEndedMinutesAgo,
              workoutEnd >= 2, workoutEnd <= 45 else { return 0.0 }

        let timingScore = 1.0 - abs(workoutEnd - 20) / 25.0  // peaks at 20 min post
        let hrvPenalty  = scores.hrvRecovery < 0.4 ? 0.8 : 1.0 // still recovering

        return min(1.0, timingScore * 0.7 + scores.activityLevel * 0.3) * hrvPenalty
    }

    /// stressedAnxious — Still Waters.
    private func stressedConfidence(
        _ snapshot: HealthSnapshot,
        _ scores: BiometricSubScores
    ) -> Double {
        guard snapshot.lastWorkoutEndedMinutesAgo ?? 999 > 60 else { return 0.0 }
        let stressSignal = (1.0 - scores.hrStress) * 0.5 + (1.0 - scores.hrvRecovery) * 0.5
        return min(1.0, stressSignal * 1.4)
    }

    /// exhaustedDepleted — Weary Soul.
    private func exhaustedConfidence(
        _ snapshot: HealthSnapshot,
        _ scores: BiometricSubScores
    ) -> Double {
        let sleepBad = 1.0 - scores.sleepQuality
        let lowHRV   = 1.0 - scores.hrvRecovery
        let lowOxy   = 1.0 - scores.oxygenLevel
        let inactive = 1.0 - scores.activityLevel
        return min(1.0, (sleepBad * 0.35 + lowHRV * 0.35 + lowOxy * 0.15 + inactive * 0.15) * 1.2)
    }

    /// deepRestRecovered — Sabbath Morning.
    private func sabbathMorningConfidence(
        _ snapshot: HealthSnapshot,
        _ scores: BiometricSubScores
    ) -> Double {
        guard scores.timeOfDay == .morning else { return 0.0 }
        return scores.sleepQuality * 0.5 + scores.hrvRecovery * 0.3 + scores.oxygenLevel * 0.2
    }

    /// spiritualAlert — Watchman Hour.
    private func watchmanConfidence(
        _ snapshot: HealthSnapshot,
        _ scores: BiometricSubScores
    ) -> Double {
        guard scores.timeOfDay == .night,
              let lateWake = snapshot.lateNightWakeMinutes,
              lateWake > 10 else { return 0.0 }
        return min(1.0, lateWake / 30.0)
    }

    // MARK: - Seven Open Confidence Functions

    /// peacefulSteady.
    /// Gated: requires hrvRecovery ≥ 0.5 (moderate or better HRV) so that sparse-data
    /// snapshots with default hrv=0.5 don't falsely trigger; also gated to 0 when a
    /// workout ended within the last 60 min (post-workout energy dominates).
    private func peacefulConfidence(
        _ snapshot: HealthSnapshot,
        _ scores: BiometricSubScores
    ) -> Double {
        guard scores.hrvRecovery >= 0.5 else { return 0.0 }
        guard snapshot.lastWorkoutEndedMinutesAgo.map({ $0 > 60 }) ?? true else { return 0.0 }
        return scores.hrStress * 0.35 + scores.hrvRecovery * 0.45 + (1.0 - abs(scores.activityLevel - 0.4)) * 0.20
    }

    /// morningAwakening — New Mercies.
    /// Gated to earlyMorning only.
    /// Base: 0.6 + sleepQuality*0.4; scaled to 0.55 if wakeTime is not present or
    /// more than 90 min before `date`.
    private func morningConfidence(
        _ snapshot: HealthSnapshot,
        _ scores: BiometricSubScores,
        at date: Date,
        calendar: Calendar
    ) -> Double {
        guard scores.timeOfDay == .earlyMorning else { return 0.0 }

        if let wakeTime = snapshot.wakeTime {
            let minutesSinceWake = date.timeIntervalSince(wakeTime) / 60.0
            if minutesSinceWake >= 0 && minutesSinceWake <= 90 {
                return 0.6 + scores.sleepQuality * 0.4
            }
        }
        return 0.55
    }

    /// eveningWindingDown.
    /// Gated to evening only.
    private func eveningConfidence(
        _ snapshot: HealthSnapshot,
        _ scores: BiometricSubScores
    ) -> Double {
        guard scores.timeOfDay == .evening else { return 0.0 }
        return (1.0 - scores.activityLevel) * 0.5 + scores.hrStress * 0.5
    }

    /// activeEngaged.
    /// Gated: returns 0 if `isPostWorkout` (victory lap takes precedence).
    /// Tuned: penalised by 0.10 when hrvRecovery > 0.85 (very-high-HRV + activity
    /// is peak-performance territory, not merely active-engaged).
    private func activeConfidence(
        _ snapshot: HealthSnapshot,
        _ scores: BiometricSubScores
    ) -> Double {
        guard !snapshot.isPostWorkout else { return 0.0 }
        let base = scores.activityLevel * 0.7 + scores.hrStress * 0.3
        let peakPenalty = scores.hrvRecovery > 0.85 ? 0.10 : 0.0
        return max(0, base - peakPenalty)
    }

    /// sadWithdrawn — Broken Vessel.
    /// Gated: requires at least one sleep metric (sleepEfficiency or totalSleepMinutes)
    /// to be present so that data-sparse snapshots don't falsely register as sad.
    private func sadConfidence(
        _ snapshot: HealthSnapshot,
        _ scores: BiometricSubScores
    ) -> Double {
        guard snapshot.sleepEfficiency != nil || snapshot.totalSleepMinutes != nil else {
            return 0.0
        }
        let raw = (1.0 - scores.activityLevel) * 0.4
                + (1.0 - scores.sleepQuality)  * 0.3
                + (1.0 - scores.hrvRecovery)   * 0.3
        return min(0.9, raw)
    }

    /// sickUnwell — Healing Hands.
    /// Requires both restingHeartRate AND respiratoryRate to be present; else returns 0.
    private func sickConfidence(
        _ snapshot: HealthSnapshot,
        _ scores: BiometricSubScores,
        feverScore: Double?
    ) -> Double {
        guard snapshot.restingHeartRate != nil,
              snapshot.respiratoryRate != nil else { return 0.0 }
        let base = (1.0 - scores.respiratoryStress) * 0.4
                 + (1.0 - scores.oxygenLevel)        * 0.4
                 + (1.0 - scores.hrvRecovery)         * 0.2
        let raw: Double
        if let fever = feverScore, fever > 0 {
            raw = base * 0.75 + fever * 0.25
        } else {
            raw = base
        }
        return min(1.0, raw * 1.15)
    }

    /// Optional fever score in [0,1]; nil when no temperature signal is present.
    /// Body temp uses an absolute fever threshold; wrist temp uses deviation from a
    /// rolling baseline (needs ≥ 3 nights). Returns the max of available sources.
    private func feverScore(
        _ snapshot: HealthSnapshot,
        wristTempBaseline: (mean: Double, count: Int)?
    ) -> Double? {
        var scores: [Double] = []
        if let bodyTemp = snapshot.bodyTemperature {
            scores.append(max(0, min(1, (bodyTemp - 37.5) / 1.5)))
        }
        if let wrist = snapshot.sleepingWristTemperature,
           let base = wristTempBaseline, base.count >= 3 {
            let dev = wrist - base.mean
            scores.append(max(0, min(1, (dev - 0.5) / 1.0)))
        }
        return scores.max()
    }

    /// peakPerformance — Mountain Top.
    /// Gated: requires hrvRecovery ≥ 0.7 and sleepQuality ≥ 0.6.
    private func peakConfidence(
        _ snapshot: HealthSnapshot,
        _ scores: BiometricSubScores
    ) -> Double {
        guard scores.hrvRecovery >= 0.7, scores.sleepQuality >= 0.6 else { return 0.0 }
        return scores.hrvRecovery  * 0.35
             + scores.sleepQuality * 0.30
             + scores.oxygenLevel  * 0.15
             + scores.activityLevel * 0.20
    }

    // MARK: - Time-of-Day Fallback

    private func timeOfDayFallback(_ timeOfDay: TimeOfDay) -> BiometricState {
        switch timeOfDay {
        case .earlyMorning:          return .morningAwakening
        case .morning, .afternoon:   return .peacefulSteady
        case .evening:               return .eveningWindingDown
        case .night:                 return .peacefulSteady
        }
    }

    // MARK: - Test Shims

    // Test shims (internal) — expose the private helpers to the test target.
    func feverScoreForTest(_ s: HealthSnapshot, wristTempBaseline: (mean: Double, count: Int)?) -> Double? {
        feverScore(s, wristTempBaseline: wristTempBaseline)
    }
    func sickConfidenceForTest(_ s: HealthSnapshot, _ scores: BiometricSubScores, feverScore: Double?) -> Double {
        sickConfidence(s, scores, feverScore: feverScore)
    }
}
