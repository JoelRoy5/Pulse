import XCTest
@testable import PulseShared

final class EmotionTests: XCTestCase {
    func testGridMapping() {
        XCTAssertEqual(Emotion.grid(energy: .low, mood: .negative), .drained)
        XCTAssertEqual(Emotion.grid(energy: .low, mood: .neutral), .restful)
        XCTAssertEqual(Emotion.grid(energy: .low, mood: .positive), .content)
        XCTAssertEqual(Emotion.grid(energy: .medium, mood: .negative), .weighedDown)
        XCTAssertEqual(Emotion.grid(energy: .medium, mood: .neutral), .steady)
        XCTAssertEqual(Emotion.grid(energy: .medium, mood: .positive), .grateful)
        XCTAssertEqual(Emotion.grid(energy: .high, mood: .negative), .stressed)
        XCTAssertEqual(Emotion.grid(energy: .high, mood: .neutral), .driven)
        XCTAssertEqual(Emotion.grid(energy: .high, mood: .positive), .energized)
    }
    func testDisplayNamesArePlain() {
        XCTAssertEqual(Emotion.weighedDown.displayName, "Weighed Down")
        XCTAssertEqual(Emotion.stressed.displayName, "Stressed")
        for e in Emotion.allCases { XCTAssertFalse(e.displayName.isEmpty) }
    }
    func testEveryEmotionMapsToAState() {
        for e in Emotion.allCases { XCTAssertFalse(e.biometricState.verseTheme.isEmpty) }
        XCTAssertEqual(Emotion.stressed.biometricState, .stressedAnxious)
        XCTAssertEqual(Emotion.drained.biometricState, .exhaustedDepleted)
        XCTAssertEqual(Emotion.unwell.biometricState, .sickUnwell)
    }
    func testStateDefaultEmotionRoundTrips() {
        XCTAssertEqual(BiometricState.stressedAnxious.defaultEmotion, .stressed)
        XCTAssertEqual(BiometricState.sickUnwell.defaultEmotion, .unwell)
        for s in BiometricState.allCases { _ = s.defaultEmotion } // total
    }
}
