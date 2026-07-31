import XCTest
@testable import PulseShared

final class SleepAnalyzerTests: XCTestCase {
    // Helper: a date at a given hour:minute on a fixed day (Jan 2, 2026)
    private func t(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 1; c.day = day
        c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(SleepAnalyzer().analyze(samples: []))
    }

    func testFullNightBreakdown() {
        // In bed 23:00–07:00. Asleep 23:20–06:50 with stages; awake 03:00–03:15.
        let samples: [SleepSample] = [
            SleepSample(stage: .inBed, start: t(1, 23), end: t(2, 7)),
            SleepSample(stage: .core,  start: t(1, 23, 20), end: t(2, 1)),   // 100m light
            SleepSample(stage: .deep,  start: t(2, 1),      end: t(2, 2, 30)), // 90m deep
            SleepSample(stage: .awake, start: t(2, 3),      end: t(2, 3, 15)), // 15m awake after midnight
            SleepSample(stage: .rem,   start: t(2, 3, 15),  end: t(2, 5)),   // 105m REM
            SleepSample(stage: .core,  start: t(2, 5),      end: t(2, 6, 50)), // 110m light
        ]
        let b = SleepAnalyzer().analyze(samples: samples)!
        XCTAssertEqual(b.inBedMinutes, 480, accuracy: 0.5)
        XCTAssertEqual(b.deepSleepMinutes, 90, accuracy: 0.5)
        XCTAssertEqual(b.remMinutes, 105, accuracy: 0.5)
        XCTAssertEqual(b.lightSleepMinutes, 210, accuracy: 0.5)
        XCTAssertEqual(b.totalSleepMinutes, 405, accuracy: 0.5)
        XCTAssertEqual(b.awakeMinutes, 15, accuracy: 0.5)
        XCTAssertEqual(b.lateNightWakeMinutes, 15, accuracy: 0.5)
        XCTAssertEqual(b.sleepOnsetMinutes, 20, accuracy: 0.5)
        XCTAssertEqual(b.efficiency, 405.0/480.0, accuracy: 0.01)
        XCTAssertEqual(b.bedtime, t(1, 23))
        XCTAssertEqual(b.wakeTime, t(2, 6, 50))
    }

    func testNoInBedSamplesFallsBackToSpan() {
        let samples: [SleepSample] = [
            SleepSample(stage: .unspecified, start: t(1, 23), end: t(2, 6)),
        ]
        let b = SleepAnalyzer().analyze(samples: samples)!
        XCTAssertEqual(b.totalSleepMinutes, 420, accuracy: 0.5)
        XCTAssertEqual(b.inBedMinutes, 420, accuracy: 0.5)
        XCTAssertEqual(b.efficiency, 1.0, accuracy: 0.01)
    }
}
