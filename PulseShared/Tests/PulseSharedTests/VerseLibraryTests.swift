import XCTest
@testable import PulseShared

final class VerseLibraryTests: XCTestCase {

    // MARK: - VerseSelectionContext.emotion

    func testContextEmotionDefaultsToStateDefaultEmotion() {
        let ctx = VerseSelectionContext(
            state: .stressedAnxious,
            timeOfDay: .morning,
            confidence: 0.9
        )
        XCTAssertEqual(ctx.emotion, BiometricState.stressedAnxious.defaultEmotion)
        XCTAssertEqual(ctx.emotion, .stressed)
    }

    func testContextEmotionExplicitOverride() {
        let ctx = VerseSelectionContext(
            state: .stressedAnxious,
            timeOfDay: .morning,
            confidence: 0.9,
            emotion: .grateful
        )
        XCTAssertEqual(ctx.emotion, .grateful)
    }
}
