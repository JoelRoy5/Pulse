import XCTest
@testable import PulseShared

final class EmotionDeriverTests: XCTestCase {
    private let d = EmotionDeriver()
    private func scores(hrStress: Double = 0.3, hrvRecovery: Double = 0.6,
                        sleepQuality: Double = 0.6, activity: Double = 0.3) -> BiometricSubScores {
        BiometricSubScores(hrStress: hrStress, hrvRecovery: hrvRecovery, sleepQuality: sleepQuality,
                           oxygenLevel: 0.9, activityLevel: activity, respiratoryStress: 0.2, timeOfDay: .afternoon)
    }
    func testEnergyBands() {
        XCTAssertEqual(d.energy(from: scores(activity: 0.8)), .high)
        XCTAssertEqual(d.energy(from: scores(hrStress: 0.9, activity: 0.1)), .high) // hrStress*0.8=0.72
        XCTAssertEqual(d.energy(from: scores(hrStress: 0.2, activity: 0.1)), .low)
        XCTAssertEqual(d.energy(from: scores(hrStress: 0.3, activity: 0.45)), .medium)
    }
    func testMoodConservativeDefaultNeutral() {
        XCTAssertEqual(d.mood(from: scores()), .neutral) // (0.6+0.6)/2 - 0.15 = 0.45 → neutral
    }
    func testMoodPositiveOnGoodSignals() {
        XCTAssertEqual(d.mood(from: scores(hrStress: 0.1, hrvRecovery: 0.85, sleepQuality: 0.85)), .positive)
    }
    func testMoodNegativeOnStressSignals() {
        XCTAssertEqual(d.mood(from: scores(hrStress: 0.9, hrvRecovery: 0.25, sleepQuality: 0.25)), .negative)
    }
    func testMoodBiasShiftsToward() {
        let s = scores() // neutral at bias 0
        XCTAssertEqual(d.mood(from: s, bias: 0.2), .positive)   // 0.45+0.2=0.65
        XCTAssertEqual(d.mood(from: s, bias: -0.2), .negative)  // 0.45-0.2=0.25
    }
    func testUnwellOverride() {
        XCTAssertEqual(d.emotion(for: .sickUnwell, subScores: scores(activity: 0.9)), .unwell)
    }
    func testEmotionUsesGridWhenNotSick() {
        XCTAssertEqual(d.emotion(for: .stressedAnxious,
                                 subScores: scores(hrStress: 0.9, hrvRecovery: 0.2, sleepQuality: 0.2, activity: 0.2)),
                       .stressed)
    }
}
