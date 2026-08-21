import XCTest
@testable import PulseShared

/// Deterministic RNG for tests (SplitMix64).
private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

final class LibraryVerseSelectorTests: XCTestCase {

    private func makeLibrary() -> VerseLibrary {
        VerseLibrary(version: 1, emotions: [
            "stressed": .init(theme: "peace_calm", themeDisplayName: "Peace & Calm",
                              verses: ["John 14:27", "Psalm 46:10", "Matthew 6:34", "1 Peter 5:7"]),
            "grateful": .init(theme: "gratitude_praise", themeDisplayName: "Gratitude & Praise",
                              verses: ["Psalm 100:4-5"])
            // note: no "unwell" entry — used to test the missing-pool path
        ])
    }

    private func context(_ emotion: Emotion, avoid: [String] = []) -> VerseSelectionContext {
        VerseSelectionContext(state: emotion.biometricState, timeOfDay: .morning,
                              confidence: 0.9, avoidRepeats: avoid, emotion: emotion)
    }

    func testPicksFromCorrectPoolWithTheme() throws {
        let selector = LibraryVerseSelector(library: makeLibrary())
        var rng = SeededRNG(seed: 1)
        let selection = try selector.select(for: context(.stressed), using: &rng)
        XCTAssertTrue(["John 14:27", "Psalm 46:10", "Matthew 6:34", "1 Peter 5:7"].contains(selection.reference))
        XCTAssertEqual(selection.theme, "peace_calm")
        XCTAssertEqual(selection.themeDisplayName, "Peace & Calm")
        XCTAssertFalse(selection.isFallback)
        XCTAssertNil(selection.rationale)
    }

    func testHonorsAvoidRepeats() throws {
        let selector = LibraryVerseSelector(library: makeLibrary())
        let avoid = ["John 14:27", "Psalm 46:10", "Matthew 6:34"]
        for seed in UInt64(0)..<50 {
            var rng = SeededRNG(seed: seed)
            let selection = try selector.select(for: context(.stressed, avoid: avoid), using: &rng)
            XCTAssertEqual(selection.reference, "1 Peter 5:7")
            XCTAssertFalse(avoid.contains(selection.reference))
        }
    }

    func testResetsWhenAllAvoided() throws {
        let selector = LibraryVerseSelector(library: makeLibrary())
        let all = ["John 14:27", "Psalm 46:10", "Matthew 6:34", "1 Peter 5:7"]
        var rng = SeededRNG(seed: 7)
        let selection = try selector.select(for: context(.stressed, avoid: all), using: &rng)
        XCTAssertTrue(all.contains(selection.reference))  // reset to full pool, still valid
    }

    func testVarietyAcrossCalls() throws {
        let selector = LibraryVerseSelector(library: makeLibrary())
        var seen = Set<String>()
        var avoid: [String] = []
        for seed in UInt64(0)..<4 {
            var rng = SeededRNG(seed: seed)
            let selection = try selector.select(for: context(.stressed, avoid: avoid), using: &rng)
            seen.insert(selection.reference)
            avoid.append(selection.reference)
        }
        XCTAssertEqual(seen.count, 4, "excluding prior picks should yield 4 distinct verses")
    }

    func testMissingPoolThrows() {
        let selector = LibraryVerseSelector(library: makeLibrary())
        var rng = SeededRNG(seed: 1)
        XCTAssertThrowsError(try selector.select(for: context(.unwell), using: &rng)) { error in
            XCTAssertEqual(error as? ScriptureAPIError, .notConfigured)
        }
    }

    func testAlternatesExcludePick() throws {
        let selector = LibraryVerseSelector(library: makeLibrary())
        var rng = SeededRNG(seed: 3)
        let selection = try selector.select(for: context(.stressed), using: &rng)
        XCTAssertFalse(selection.alternates.contains(selection.reference))
        XCTAssertLessThanOrEqual(selection.alternates.count, 3)
    }
}
