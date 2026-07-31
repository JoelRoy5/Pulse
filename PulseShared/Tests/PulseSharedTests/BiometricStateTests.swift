import XCTest
@testable import PulseShared

final class BiometricStateTests: XCTestCase {
    func testTwelveStatesWithStableRawValues() {
        XCTAssertEqual(BiometricState.allCases.count, 12)
        XCTAssertEqual(BiometricState.energizedPostWorkout.rawValue, "energized_post_workout")
        XCTAssertEqual(BiometricState.spiritualAlert.rawValue, "spiritual_alert")
        XCTAssertEqual(BiometricState(rawValue: "exhausted_depleted"), .exhaustedDepleted)
    }
    func testDisplayMetadataPresent() {
        for state in BiometricState.allCases {
            XCTAssertFalse(state.displayName.isEmpty)
            XCTAssertFalse(state.bodyInterpretation.isEmpty)
            XCTAssertFalse(state.emoji.isEmpty)
            XCTAssertFalse(state.verseTheme.isEmpty)
        }
        XCTAssertEqual(BiometricState.exhaustedDepleted.displayName, "Weary Soul")
        XCTAssertEqual(BiometricState.stressedAnxious.deliveryUrgency, .high)
        XCTAssertEqual(BiometricState.energizedPostWorkout.deliveryUrgency, .timeSensitive)
        XCTAssertEqual(BiometricState.peacefulSteady.deliveryUrgency, .standard)
    }
}

final class TimeOfDayTests: XCTestCase {
    func testHourBoundaries() {
        XCTAssertEqual(TimeOfDay(hour: 5), .earlyMorning)
        XCTAssertEqual(TimeOfDay(hour: 7), .earlyMorning)
        XCTAssertEqual(TimeOfDay(hour: 8), .morning)
        XCTAssertEqual(TimeOfDay(hour: 11), .morning)
        XCTAssertEqual(TimeOfDay(hour: 12), .afternoon)
        XCTAssertEqual(TimeOfDay(hour: 16), .afternoon)
        XCTAssertEqual(TimeOfDay(hour: 17), .evening)
        XCTAssertEqual(TimeOfDay(hour: 20), .evening)
        XCTAssertEqual(TimeOfDay(hour: 21), .night)
        XCTAssertEqual(TimeOfDay(hour: 2), .night)
    }
}

final class HealthQualityTests: XCTestCase {
    func testFactories() {
        XCTAssertEqual(HealthQuality.forHeartRate(70, restingBPM: 60), .good)
        XCTAssertEqual(HealthQuality.forHeartRate(85, restingBPM: 60), .fair)
        XCTAssertEqual(HealthQuality.forHeartRate(100, restingBPM: 60), .poor)
        XCTAssertEqual(HealthQuality.forHeartRate(100, restingBPM: nil), .unavailable)
        XCTAssertEqual(HealthQuality.forHRV(55), .good)
        XCTAssertEqual(HealthQuality.forOxygen(0.95), .fair)
        XCTAssertEqual(HealthQuality.forSleepEfficiency(0.6), .poor)
    }
}
