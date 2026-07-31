import XCTest
@testable import PulseShared

final class FallbackVerseProviderTests: XCTestCase {
    func testEveryStateHasEmergencyVerse() {
        let provider = FallbackVerseProvider()
        for state in BiometricState.allCases {
            let verse = provider.emergencyVerse(for: state)
            XCTAssertFalse(verse.text.isEmpty, "no emergency verse for \(state.rawValue)")
            XCTAssertFalse(verse.reference.isEmpty)
        }
    }
    func testKnownMappings() {
        XCTAssertEqual(FallbackVerseProvider.fallbackReference(for: .exhaustedDepleted), "Matthew 11:28-30")
        XCTAssertEqual(FallbackVerseProvider.fallbackReference(for: .peakPerformance), "Isaiah 40:31")
        let verse = FallbackVerseProvider().emergencyVerse(for: .stressedAnxious)
        XCTAssertEqual(verse.reference, "John 14:27")
    }
}
