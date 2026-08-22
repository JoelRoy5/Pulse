import XCTest
@testable import PulseShared

final class ClassificationSignalsTests: XCTestCase {

    func testSnapshotCarriesNewOptionalFields() {
        let s = HealthSnapshot(
            sleepingWristTemperature: 34.2,
            timeInDaylightMinutes: 45,
            heartRateRecoveryBPM: 32
        )
        XCTAssertEqual(s.sleepingWristTemperature, 34.2)
        XCTAssertEqual(s.timeInDaylightMinutes, 45)
        XCTAssertEqual(s.heartRateRecoveryBPM, 32)
    }

    func testInsufficientDataTrueWhenCoreSignalsAbsent() {
        let s = HealthSnapshot(stepCount: 1000)   // no HRV/sleep/restingHR
        XCTAssertTrue(ClassificationSignals.insufficientData(s))
    }

    func testInsufficientDataFalseWhenAnyCoreSignalPresent() {
        XCTAssertFalse(ClassificationSignals.insufficientData(HealthSnapshot(heartRateVariability: 40)))
        XCTAssertFalse(ClassificationSignals.insufficientData(HealthSnapshot(restingHeartRate: 60)))
        XCTAssertFalse(ClassificationSignals.insufficientData(HealthSnapshot(totalSleepMinutes: 400)))
    }

    func testSignalsPresentReflectsSnapshot() {
        let s = HealthSnapshot(heartRateVariability: 40, bodyTemperature: 37.0, totalSleepMinutes: 400)
        let present = Set(ClassificationSignals.signalsPresent(s))
        XCTAssertTrue(present.contains("hrv"))
        XCTAssertTrue(present.contains("sleep"))
        XCTAssertTrue(present.contains("temperature"))
        XCTAssertFalse(present.contains("daylight"))
    }

    func testShouldPromptSelfReport() {
        XCTAssertTrue(ClassificationSignals.shouldPromptSelfReport(latestInsufficientData: true))
        XCTAssertFalse(ClassificationSignals.shouldPromptSelfReport(latestInsufficientData: false))
        XCTAssertFalse(ClassificationSignals.shouldPromptSelfReport(latestInsufficientData: nil))
    }

    func testTemperatureBaselineMean() {
        XCTAssertNil(TemperatureBaseline.mean(of: []))
        let r = TemperatureBaseline.mean(of: [34.0, 34.5, 35.0])
        XCTAssertEqual(r?.count, 3)
        XCTAssertEqual(r?.mean ?? 0, 34.5, accuracy: 0.0001)
    }
}
