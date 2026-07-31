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
            stateDisplayName: "Weary Soul", stateEmoji: "🌙",
            stateBodyText: "Your body is asking for rest. Come and lay it down.",
            primaryColor: "#6366F1", timestamp: 123.0)
        let dict = payload.dictionary(type: .verseDelivery)
        XCTAssertEqual(dict["type"] as? String, "verse_delivery")
        let decoded = WatchMessage.VerseDeliveryPayload.from(dict)
        XCTAssertEqual(decoded?.verseReference, "Matthew 11:28")
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
