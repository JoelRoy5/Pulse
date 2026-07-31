import Foundation
import PulseShared

// MARK: - MockHealthProvider

/// A `HealthDataProviding` implementation that returns hard-coded `HealthSnapshot`
/// fixtures keyed to a `BiometricState`.  Used automatically when
/// `HKHealthStore.isHealthDataAvailable()` is `false` (e.g. iPhone Simulator)
/// or when the `-PulseMockState <raw_value>` launch argument is present.
///
/// **Note on time-gated states:**
/// `MockHealthProvider` does not control the system clock.  States whose
/// confidence functions are gated to a specific time window
/// (`morningAwakening` → earlyMorning 5–8 am, `eveningWindingDown` → evening
/// 5–9 pm, `deepRestRecovered` → morning 8 am–12 pm, `spiritualAlert` → night
/// 9 pm–5 am) will only classify to that state when the device clock is in the
/// correct window.  Outside that window `StateClassifier` will fall back to its
/// time-of-day default.  This is expected and acceptable for a mock provider.
struct MockHealthProvider: HealthDataProviding {

    let scenario: BiometricState

    init(scenario: BiometricState = .exhaustedDepleted) {
        self.scenario = scenario
    }

    var isAvailable: Bool { true }

    func requestAuthorization() async throws {
        // No-op for mock
    }

    func fetchSnapshot() async throws -> HealthSnapshot {
        var snap = MockHealthProvider.snapshot(for: scenario)
        snap.computeCompleteness()
        return snap
    }

    // MARK: - Fixture Builders

    /// Returns a `HealthSnapshot` whose biometric values are calibrated to
    /// produce a high-confidence classification for the given `BiometricState`
    /// (above 0.65) — provided the device clock is in the required time window
    /// for time-gated states.  Values are transcribed from
    /// `PulseSharedTests/StateClassifierTests.swift` where test fixtures exist,
    /// and constructed analytically from the confidence functions in
    /// `StateClassifier.swift` for the four states without test coverage.
    static func snapshot(for state: BiometricState) -> HealthSnapshot {
        switch state {

        // ─── From test fixtures ────────────────────────────────────────────

        case .energizedPostWorkout:
            // testVictoryLapAfterWorkout — classified at hour 18
            var s = HealthSnapshot()
            s.heartRate = 110
            s.restingHeartRate = 58
            s.heartRateVariability = 55
            s.lastWorkoutEndedMinutesAgo = 20
            s.lastWorkoutType = "running"
            s.stepCount = 9000
            s.activeEnergyBurned = 520
            s.exerciseMinutes = 40
            return s

        case .stressedAnxious:
            // testStressedAnxious — classified at hour 14
            var s = HealthSnapshot()
            s.heartRate = 96
            s.restingHeartRate = 58
            s.heartRateVariability = 18
            s.sleepEfficiency = 0.8
            s.totalSleepMinutes = 400
            s.stepCount = 3000
            return s

        case .exhaustedDepleted:
            // testExhaustedDepleted — classified at hour 14
            var s = HealthSnapshot()
            s.heartRate = 64
            s.restingHeartRate = 60
            s.heartRateVariability = 16
            s.oxygenSaturation = 0.93
            s.sleepEfficiency = 0.55
            s.totalSleepMinutes = 250
            s.deepSleepMinutes = 15
            s.stepCount = 800
            s.activeEnergyBurned = 60
            return s

        case .deepRestRecovered:
            // testSabbathMorning — classified at hour 9 (morning window required)
            var s = HealthSnapshot()
            s.heartRate = 56
            s.restingHeartRate = 55
            s.heartRateVariability = 85
            s.oxygenSaturation = 0.99
            s.sleepEfficiency = 0.95
            s.totalSleepMinutes = 480
            s.deepSleepMinutes = 100
            s.remSleepMinutes = 110
            return s

        case .spiritualAlert:
            // testWatchmanHourAtNight — classified at hour 2 (night window required)
            var s = HealthSnapshot()
            s.heartRate = 58
            s.restingHeartRate = 56
            s.heartRateVariability = 50
            s.lateNightWakeMinutes = 35
            s.sleepEfficiency = 0.7
            s.totalSleepMinutes = 300
            s.stepCount = 0
            return s

        case .sickUnwell:
            // testSickUnwell — classified at hour 11
            var s = HealthSnapshot()
            s.heartRate = 88
            s.restingHeartRate = 72
            s.heartRateVariability = 22
            s.respiratoryRate = 23
            s.oxygenSaturation = 0.92
            s.sleepEfficiency = 0.75
            s.totalSleepMinutes = 380
            s.stepCount = 900
            return s

        case .peakPerformance:
            // testPeakPerformance — classified at hour 15
            var s = HealthSnapshot()
            s.heartRate = 60
            s.restingHeartRate = 52
            s.heartRateVariability = 95
            s.oxygenSaturation = 0.99
            s.sleepEfficiency = 0.93
            s.totalSleepMinutes = 470
            s.deepSleepMinutes = 95
            s.stepCount = 11000
            s.activeEnergyBurned = 640
            s.exerciseMinutes = 45
            return s

        case .activeEngaged:
            // testActiveEngaged — classified at hour 15
            var s = HealthSnapshot()
            s.heartRate = 72
            s.restingHeartRate = 60
            s.heartRateVariability = 45
            s.sleepEfficiency = 0.78
            s.totalSleepMinutes = 380
            s.stepCount = 9500
            s.activeEnergyBurned = 480
            s.exerciseMinutes = 35
            return s

        // ─── Analytically constructed (no test fixtures) ──────────────────

        case .peacefulSteady:
            // peacefulConfidence = hrStress * 0.35 + hrvRecovery * 0.45 + (1 - |activityLevel - 0.4|) * 0.20
            // Gate: hrvRecovery >= 0.5, no workout in last 60 min.
            // hrStress: HR=65, RHR=62 → ratio≈1.05 → hrStress = 1-(0.05/1.5) ≈ 0.967
            // hrvRecovery: HRV=55 → (55-20)/60 ≈ 0.583
            // activityLevel: steps=4500 → 0.4*0.5625, cals=220 → 0.3*0.44, ex=0 → 0 ≈ 0.357
            // confidence ≈ 0.967*0.35 + 0.583*0.45 + (1-|0.357-0.4|)*0.20
            //            ≈ 0.338 + 0.262 + (1-0.043)*0.20 ≈ 0.338 + 0.262 + 0.191 ≈ 0.791
            var s = HealthSnapshot()
            s.heartRate = 65
            s.restingHeartRate = 62
            s.heartRateVariability = 55
            s.sleepEfficiency = 0.82
            s.totalSleepMinutes = 420
            s.stepCount = 4500
            s.activeEnergyBurned = 220
            s.exerciseMinutes = 0
            return s

        case .morningAwakening:
            // morningConfidence: earlyMorning gate (5–8 am), wakeTime within 90 min → 0.6 + sleepQuality*0.4
            // sleepScore: efficiency=0.85, total=420, deep=70
            //   effScore=(0.85-0.65)/0.30=0.667, durScore=(420-240)/240=0.75, deepScore=70/90=0.778
            //   sleepScore=0.667*0.4+0.75*0.4+0.778*0.2 = 0.267+0.300+0.156 = 0.723
            // confidence = 0.6 + 0.723*0.4 = 0.889 (at earlyMorning hours)
            // wakeTime set to 45 min before "now" — but since we don't control the clock,
            // we set it to a reasonable early-morning timestamp.
            var s = HealthSnapshot()
            s.heartRate = 58
            s.restingHeartRate = 56
            s.heartRateVariability = 60
            s.oxygenSaturation = 0.98
            s.sleepEfficiency = 0.85
            s.totalSleepMinutes = 420
            s.deepSleepMinutes = 70
            s.remSleepMinutes = 85
            s.stepCount = 300
            s.activeEnergyBurned = 20
            // wakeTime = 45 minutes ago relative to fixture creation
            s.wakeTime = Date().addingTimeInterval(-45 * 60)
            return s

        case .eveningWindingDown:
            // eveningConfidence = (1 - activityLevel) * 0.5 + hrStress * 0.5; evening gate
            // activityLevel low: steps=2000→0.25, cals=150→0.30, ex=10→0.33 → 0.4*0.25+0.3*0.30+0.3*0.33≈0.269
            // hrStress: HR=62, RHR=60 → ratio≈1.033 → 1-(0.033/1.5)≈0.978
            // confidence = (1-0.269)*0.5 + 0.978*0.5 = 0.366 + 0.489 = 0.855 (at evening hours)
            var s = HealthSnapshot()
            s.heartRate = 62
            s.restingHeartRate = 60
            s.heartRateVariability = 52
            s.sleepEfficiency = 0.84
            s.totalSleepMinutes = 430
            s.stepCount = 2000
            s.activeEnergyBurned = 150
            s.exerciseMinutes = 10
            return s

        case .sadWithdrawn:
            // sadConfidence: requires sleepEfficiency or totalSleepMinutes present
            // raw = (1-activityLevel)*0.4 + (1-sleepQuality)*0.3 + (1-hrvRecovery)*0.3
            // Low activity: steps=500→0.0625, cals=50→0.10, ex=0→0 → activityLevel≈0.055
            // Poor sleep: efficiency=0.60, total=270, deep=20
            //   effScore=(0.60-0.65)/0.30=-0.167→0, durScore=(270-240)/240=0.125, deepScore=20/90=0.222
            //   sleepQuality=0*0.4+0.125*0.4+0.222*0.2=0+0.05+0.044=0.094
            // HRV=25 → hrvRecovery=(25-20)/60=0.083
            // raw=(1-0.055)*0.4+(1-0.094)*0.3+(1-0.083)*0.3=0.378+0.272+0.275=0.925→min(0.9,...)=0.9
            var s = HealthSnapshot()
            s.heartRate = 68
            s.restingHeartRate = 65
            s.heartRateVariability = 25
            s.sleepEfficiency = 0.60
            s.totalSleepMinutes = 270
            s.deepSleepMinutes = 20
            s.stepCount = 500
            s.activeEnergyBurned = 50
            s.exerciseMinutes = 0
            return s
        }
    }
}
