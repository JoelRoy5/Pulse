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

    // MARK: - VerseLibrary bundled integrity

    func testBundledLibraryLoads() throws {
        let library = try VerseLibrary.load()
        XCTAssertEqual(library.version, 1)
    }

    func testBundledLibraryHasAllTenEmotions() throws {
        let library = try VerseLibrary.load()
        for emotion in Emotion.allCases {
            let entry = library[emotion]
            XCTAssertNotNil(entry, "missing pool for \(emotion.rawValue)")
            XCTAssertFalse(entry?.verses.isEmpty ?? true, "empty pool for \(emotion.rawValue)")
        }
    }

    func testBundledLibraryThemesMatchBiometricState() throws {
        let library = try VerseLibrary.load()
        for emotion in Emotion.allCases {
            let entry = try XCTUnwrap(library[emotion])
            XCTAssertEqual(entry.theme, emotion.biometricState.verseTheme,
                           "theme mismatch for \(emotion.rawValue)")
        }
    }

    func testBundledLibraryReferencesAllParse() throws {
        let library = try VerseLibrary.load()
        for emotion in Emotion.allCases {
            let entry = try XCTUnwrap(library[emotion])
            for ref in entry.verses {
                XCTAssertNotNil(USFM.usfm(for: ref),
                                "unparseable reference \"\(ref)\" in \(emotion.rawValue)")
            }
        }
    }

    func testBundledLibraryNoDuplicatesWithinPool() throws {
        let library = try VerseLibrary.load()
        for emotion in Emotion.allCases {
            let entry = try XCTUnwrap(library[emotion])
            XCTAssertEqual(Set(entry.verses).count, entry.verses.count,
                           "duplicate reference in \(emotion.rawValue)")
        }
    }

    func testBundledLibraryPoolsMeetMinimumSize() throws {
        let library = try VerseLibrary.load()
        for emotion in Emotion.allCases {
            let entry = try XCTUnwrap(library[emotion])
            XCTAssertGreaterThanOrEqual(entry.verses.count, 45,
                "pool for \(emotion.rawValue) has only \(entry.verses.count) verses")
        }
    }
}
