import XCTest
@testable import PulseShared

final class StateClassifierTemperatureTests: XCTestCase {

    private let classifier = StateClassifier()

    /// A snapshot that clears the sick gate (restingHR + respiration present) with
    /// mildly-elevated respiration and low SpO2 so base sick is moderate.
    private func sickBase(bodyTemp: Double? = nil, wristTemp: Double? = nil) -> HealthSnapshot {
        HealthSnapshot(
            heartRateVariability: 25,
            restingHeartRate: 70,
            respiratoryRate: 20,
            oxygenSaturation: 0.95,
            bodyTemperature: bodyTemp,
            sleepingWristTemperature: wristTemp
        )
    }

    func testFeverBodyTempRaisesSick() {
        let scores = classifier.computeSubScores(sickBase())
        let withoutTemp = classifier.sickConfidenceForTest(sickBase(), scores, feverScore: nil)
        let scoresF = classifier.computeSubScores(sickBase(bodyTemp: 38.6))
        let withFever = classifier.sickConfidenceForTest(sickBase(bodyTemp: 38.6), scoresF,
                            feverScore: classifier.feverScoreForTest(sickBase(bodyTemp: 38.6), wristTempBaseline: nil))
        XCTAssertGreaterThan(withFever, withoutTemp)
    }

    func testNormalBodyTempDoesNotInflateSick() {
        let s = sickBase(bodyTemp: 36.8)   // present but not febrile
        let scores = classifier.computeSubScores(s)
        let base = classifier.sickConfidenceForTest(s, scores, feverScore: nil)
        let withNormal = classifier.sickConfidenceForTest(s, scores,
                            feverScore: classifier.feverScoreForTest(s, wristTempBaseline: nil))
        XCTAssertEqual(withNormal, base, accuracy: 0.0001)
    }

    func testTemperatureAbsentIsRegressionSafe() {
        let s = sickBase()
        XCTAssertNil(classifier.feverScoreForTest(s, wristTempBaseline: nil))
    }

    func testWristDeviationRaisesSickWithEnoughBaseline() {
        let s = sickBase(wristTemp: 35.6)               // +1.1 over a 34.5 baseline
        let base = (mean: 34.5, count: 5)
        let fever = classifier.feverScoreForTest(s, wristTempBaseline: base)
        XCTAssertNotNil(fever)
        XCTAssertGreaterThan(fever ?? 0, 0)
    }

    func testWristIgnoredWithoutEnoughBaseline() {
        let s = sickBase(wristTemp: 35.6)
        let base = (mean: 34.5, count: 2)               // < 3 nights
        XCTAssertNil(classifier.feverScoreForTest(s, wristTempBaseline: base))
    }

    func testDaylightAndHRRecoveryDoNotChangeClassification() {
        let plain = HealthSnapshot(heartRateVariability: 55, restingHeartRate: 55, sleepEfficiency: 0.9, totalSleepMinutes: 450)
        let withContext = HealthSnapshot(heartRateVariability: 55, restingHeartRate: 55, sleepEfficiency: 0.9, totalSleepMinutes: 450,
                                         timeInDaylightMinutes: 120, heartRateRecoveryBPM: 40)
        XCTAssertEqual(classifier.classify(plain).state, classifier.classify(withContext).state)
    }
}
