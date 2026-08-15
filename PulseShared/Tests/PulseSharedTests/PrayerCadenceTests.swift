import XCTest
@testable import PulseShared

final class PrayerCadenceTests: XCTestCase {
    func testStartEqualsTargetIsConstant() {
        let c = PrayerCadence(startBPM: 60, targetBPM: 60, durationSeconds: 120)
        XCTAssertEqual(c.bpm(atElapsed: 0), 60, accuracy: 0.001)
        XCTAssertEqual(c.bpm(atElapsed: 60), 60, accuracy: 0.001)
        XCTAssertEqual(c.bpm(atElapsed: 120), 60, accuracy: 0.001)
    }
    func testWindsDownMonotonically() {
        let c = PrayerCadence(startBPM: 90, targetBPM: 60, durationSeconds: 120)
        XCTAssertEqual(c.bpm(atElapsed: 0), 90, accuracy: 0.001)
        let mid = c.bpm(atElapsed: 60)
        XCTAssertLessThan(mid, 90)
        XCTAssertGreaterThan(mid, 60)
        XCTAssertEqual(c.bpm(atElapsed: 120), 60, accuracy: 0.5)
        // non-increasing across the session
        var prev = 999.0
        for t in stride(from: 0.0, through: 120.0, by: 5.0) {
            let v = c.bpm(atElapsed: t)
            XCTAssertLessThanOrEqual(v, prev + 0.001)
            prev = v
        }
    }
    func testNeverSpeedsUpWhenTargetAboveStart() {
        let c = PrayerCadence(startBPM: 55, targetBPM: 80, durationSeconds: 60)
        // target clamped to start; constant
        XCTAssertEqual(c.bpm(atElapsed: 0), 55, accuracy: 0.001)
        XCTAssertEqual(c.bpm(atElapsed: 60), 55, accuracy: 0.001)
    }
    func testClamps() {
        let c = PrayerCadence(startBPM: 200, targetBPM: 10, durationSeconds: 0)
        XCTAssertEqual(c.clampedStartBPM, 120, accuracy: 0.001)   // start capped
        XCTAssertEqual(c.clampedTargetBPM, 50, accuracy: 0.001)   // target floored
    }
    func testBeatInterval() {
        let c = PrayerCadence(startBPM: 60, targetBPM: 60, durationSeconds: 120)
        XCTAssertEqual(c.beatInterval(atElapsed: 0), 1.0, accuracy: 0.001)  // 60bpm = 1s
    }
}
