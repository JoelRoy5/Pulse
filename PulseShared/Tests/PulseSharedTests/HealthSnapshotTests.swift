import XCTest
@testable import PulseShared

final class HealthSnapshotTests: XCTestCase {
    func testCompletenessCountsNineTrackedFields() {
        var s = HealthSnapshot()
        s.computeCompleteness()
        XCTAssertEqual(s.dataCompleteness, 0.0)

        s.heartRate = 72; s.heartRateVariability = 48; s.restingHeartRate = 58
        s.respiratoryRate = 15; s.oxygenSaturation = 0.97
        s.sleepEfficiency = 0.85; s.totalSleepMinutes = 420
        s.stepCount = 4000; s.activeEnergyBurned = 300
        s.computeCompleteness()
        XCTAssertEqual(s.dataCompleteness, 1.0, accuracy: 0.001)

        var half = HealthSnapshot()
        half.heartRate = 72; half.heartRateVariability = 48
        half.restingHeartRate = 58; half.respiratoryRate = 15
        half.computeCompleteness()
        XCTAssertEqual(half.dataCompleteness, 4.0/9.0, accuracy: 0.001)
    }
    func testSleepQualityBands() {
        var s = HealthSnapshot()
        XCTAssertEqual(s.sleepQuality, .unknown)
        s.sleepEfficiency = 0.95; s.totalSleepMinutes = 450
        XCTAssertEqual(s.sleepQuality, .excellent)
        s.sleepEfficiency = 0.85; s.totalSleepMinutes = 400
        XCTAssertEqual(s.sleepQuality, .good)
        s.sleepEfficiency = 0.75; s.totalSleepMinutes = 320
        XCTAssertEqual(s.sleepQuality, .fair)
        s.sleepEfficiency = 0.75; s.totalSleepMinutes = 250
        XCTAssertEqual(s.sleepQuality, .poor)
        s.sleepEfficiency = 0.9; s.totalSleepMinutes = 200
        XCTAssertEqual(s.sleepQuality, .veryPoor)
    }
    func testIsPostWorkoutWindow() {
        var s = HealthSnapshot()
        XCTAssertFalse(s.isPostWorkout)
        s.lastWorkoutEndedMinutesAgo = 10
        XCTAssertTrue(s.isPostWorkout)
        s.lastWorkoutEndedMinutesAgo = 61
        XCTAssertFalse(s.isPostWorkout)
    }
    func testWatchMessageRoundTrip() {
        let payload = WatchMessage.VerseDeliveryPayload(
            deliveryID: "abc", verseText: "Come to me", verseReference: "Matthew 11:28",
            translationAbbreviation: "NIV", stateRaw: "exhausted_depleted",
            stateDisplayName: "Weary Soul", stateSymbol: "moon.fill",
            stateBodyText: "Your body is asking for rest. Come and lay it down.",
            primaryColor: "#6366F1", timestamp: 123.0)
        let dict = payload.dictionary(type: .verseDelivery)
        XCTAssertEqual(dict["type"] as? String, "verse_delivery")
        let decoded = WatchMessage.VerseDeliveryPayload.from(dict)
        XCTAssertEqual(decoded?.verseReference, "Matthew 11:28")
    }

    func testSleepBreakdownQualityBands() {
        // excellent: efficiency > 0.9 AND deepSleepMinutes > 90 AND remMinutes > 90
        var sb = SleepBreakdown(
            inBedMinutes: 500, totalSleepMinutes: 480, deepSleepMinutes: 120,
            remMinutes: 120, lightSleepMinutes: 240, awakeMinutes: 20,
            lateNightWakeMinutes: 5, sleepOnsetMinutes: 10)
        XCTAssertEqual(sb.quality, .excellent)

        // good: efficiency > 0.8 AND deepSleepMinutes > 60
        sb = SleepBreakdown(
            inBedMinutes: 450, totalSleepMinutes: 380, deepSleepMinutes: 80,
            remMinutes: 60, lightSleepMinutes: 240, awakeMinutes: 20,
            lateNightWakeMinutes: 5, sleepOnsetMinutes: 10)
        XCTAssertEqual(sb.quality, .good)

        // fair: efficiency > 0.7 AND totalSleepMinutes >= 300
        sb = SleepBreakdown(
            inBedMinutes: 420, totalSleepMinutes: 310, deepSleepMinutes: 50,
            remMinutes: 50, lightSleepMinutes: 210, awakeMinutes: 20,
            lateNightWakeMinutes: 5, sleepOnsetMinutes: 10)
        XCTAssertEqual(sb.quality, .fair)

        // poor: efficiency <= 0.7 OR totalSleepMinutes < 300
        sb = SleepBreakdown(
            inBedMinutes: 400, totalSleepMinutes: 250, deepSleepMinutes: 40,
            remMinutes: 40, lightSleepMinutes: 170, awakeMinutes: 30,
            lateNightWakeMinutes: 10, sleepOnsetMinutes: 15)
        XCTAssertEqual(sb.quality, .poor)

        // veryPoor: totalSleepMinutes < 240
        sb = SleepBreakdown(
            inBedMinutes: 300, totalSleepMinutes: 200, deepSleepMinutes: 30,
            remMinutes: 30, lightSleepMinutes: 140, awakeMinutes: 50,
            lateNightWakeMinutes: 20, sleepOnsetMinutes: 20)
        XCTAssertEqual(sb.quality, .veryPoor)
    }
}

final class BibleVerseTests: XCTestCase {
    func testExcerptTruncatesAtWordBoundary() {
        let verse = BibleVerse(id: "MAT.11.28", reference: "Matthew 11:28",
            text: "Come to me, all you who are weary and burdened, and I will give you rest.",
            translationAbbreviation: "NIV", copyright: "©", chapterURLString: nil)
        XCTAssertEqual(verse.excerpt(maxChars: 20), "Come to me, all you...")
        XCTAssertEqual(verse.excerpt(maxChars: 200), verse.text)
    }
}
