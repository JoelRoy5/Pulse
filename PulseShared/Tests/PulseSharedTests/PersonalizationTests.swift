import XCTest
@testable import PulseShared

final class PersonalizationTests: XCTestCase {
    func testNoCorrectionsIsZeroBias() {
        XCTAssertEqual(Personalization.moodBias(fromCorrections: []), 0, accuracy: 0.001)
    }
    func testCorrectionsTowardPositiveRaiseBias() {
        let c = [(shown: MoodTone.neutral, corrected: MoodTone.positive),
                 (shown: MoodTone.negative, corrected: MoodTone.positive)]
        XCTAssertGreaterThan(Personalization.moodBias(fromCorrections: c), 0)
    }
    func testBiasClamped() {
        let many = Array(repeating: (shown: MoodTone.negative, corrected: MoodTone.positive), count: 50)
        XCTAssertEqual(Personalization.moodBias(fromCorrections: many), 0.3, accuracy: 0.001)
    }
}
