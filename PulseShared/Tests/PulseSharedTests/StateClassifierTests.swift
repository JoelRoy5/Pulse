import XCTest
@testable import PulseShared

final class StateClassifierTests: XCTestCase {
    private let classifier = StateClassifier()
    private func date(hour: Int) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 1; c.day = 15; c.hour = hour
        return Calendar.current.date(from: c)!
    }
    private func classify(_ s: HealthSnapshot, hour: Int) -> ClassificationResult {
        var snap = s; snap.computeCompleteness()
        return classifier.classify(snap, at: date(hour: hour))
    }

    func testVictoryLapAfterWorkout() {
        var s = HealthSnapshot()
        s.heartRate = 110; s.restingHeartRate = 58; s.heartRateVariability = 55
        s.lastWorkoutEndedMinutesAgo = 20; s.lastWorkoutType = "running"
        s.stepCount = 9000; s.activeEnergyBurned = 520; s.exerciseMinutes = 40
        XCTAssertEqual(classify(s, hour: 18).state, .energizedPostWorkout)
    }
    func testStressedAnxious() {
        var s = HealthSnapshot()
        s.heartRate = 96; s.restingHeartRate = 58; s.heartRateVariability = 18
        s.sleepEfficiency = 0.8; s.totalSleepMinutes = 400; s.stepCount = 3000
        XCTAssertEqual(classify(s, hour: 14).state, .stressedAnxious)
    }
    func testExhaustedDepleted() {
        var s = HealthSnapshot()
        s.heartRate = 64; s.restingHeartRate = 60; s.heartRateVariability = 16
        s.oxygenSaturation = 0.93; s.sleepEfficiency = 0.55; s.totalSleepMinutes = 250
        s.deepSleepMinutes = 15; s.stepCount = 800; s.activeEnergyBurned = 60
        XCTAssertEqual(classify(s, hour: 14).state, .exhaustedDepleted)
    }
    func testSabbathMorning() {
        var s = HealthSnapshot()
        s.heartRate = 56; s.restingHeartRate = 55; s.heartRateVariability = 85
        s.oxygenSaturation = 0.99; s.sleepEfficiency = 0.95; s.totalSleepMinutes = 480
        s.deepSleepMinutes = 100; s.remSleepMinutes = 110
        XCTAssertEqual(classify(s, hour: 9).state, .deepRestRecovered)
    }
    func testWatchmanHourAtNight() {
        var s = HealthSnapshot()
        s.heartRate = 58; s.restingHeartRate = 56; s.heartRateVariability = 50
        s.lateNightWakeMinutes = 35
        s.sleepEfficiency = 0.7; s.totalSleepMinutes = 300; s.stepCount = 0
        XCTAssertEqual(classify(s, hour: 2).state, .spiritualAlert)
    }
    func testSickUnwell() {
        var s = HealthSnapshot()
        s.heartRate = 88; s.restingHeartRate = 72; s.heartRateVariability = 22
        s.respiratoryRate = 23; s.oxygenSaturation = 0.92
        s.sleepEfficiency = 0.75; s.totalSleepMinutes = 380; s.stepCount = 900
        XCTAssertEqual(classify(s, hour: 11).state, .sickUnwell)
    }
    func testPeakPerformance() {
        var s = HealthSnapshot()
        s.heartRate = 60; s.restingHeartRate = 52; s.heartRateVariability = 95
        s.oxygenSaturation = 0.99; s.sleepEfficiency = 0.93; s.totalSleepMinutes = 470
        s.deepSleepMinutes = 95; s.stepCount = 11000; s.activeEnergyBurned = 640
        s.exerciseMinutes = 45
        let r = classify(s, hour: 15)
        XCTAssertTrue([.peakPerformance, .activeEngaged].contains(r.state))
        XCTAssertEqual(r.state, .peakPerformance)
    }
    func testActiveEngaged() {
        var s = HealthSnapshot()
        s.heartRate = 72; s.restingHeartRate = 60; s.heartRateVariability = 45
        s.sleepEfficiency = 0.78; s.totalSleepMinutes = 380
        s.stepCount = 9500; s.activeEnergyBurned = 480; s.exerciseMinutes = 35
        XCTAssertEqual(classify(s, hour: 15).state, .activeEngaged)
    }
    func testFallbackWhenNothingConfident() {
        var s = HealthSnapshot()
        s.heartRate = 70; s.restingHeartRate = 62; s.heartRateVariability = 45
        s.stepCount = 4000; s.activeEnergyBurned = 200
        let r = classify(s, hour: 14)
        XCTAssertEqual(r.confidence, 0.5, accuracy: 0.001)
        XCTAssertEqual(r.state, .peacefulSteady)
    }
    func testNeverCrashesOnEmptySnapshot() {
        for hour in [3, 7, 10, 14, 19, 22] {
            _ = classify(HealthSnapshot(), hour: hour)
        }
    }
}
