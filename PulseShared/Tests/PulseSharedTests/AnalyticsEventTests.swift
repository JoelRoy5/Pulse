import XCTest
@testable import PulseShared

final class AnalyticsEventTests: XCTestCase {
    func testFactoryNamesAndProps() {
        XCTAssertEqual(AnalyticsEvent.verseLoved.name, "verse_loved")
        XCTAssertEqual(AnalyticsEvent.verseDelivered(method: "auto").properties["method"], .string("auto"))
        XCTAssertEqual(AnalyticsEvent.feelingPicked(emotion: "grateful").properties["emotion"], .string("grateful"))
        XCTAssertEqual(AnalyticsEvent.prayerCompleted(durationS: 120).properties["duration_s"], .int(120))
    }
    func testPayloadShape() {
        let p = AnalyticsEvent.verseSaved.payload(distinctID: "abc", appVersion: "1.0", platform: "ios", timestamp: 100)
        XCTAssertEqual(p["event"] as? String, "verse_saved")
        XCTAssertEqual(p["distinct_id"] as? String, "abc")
        let props = p["properties"] as? [String: Any]
        XCTAssertEqual(props?["platform"] as? String, "ios")
        XCTAssertEqual(props?["$app_version"] as? String, "1.0")
    }
    // GUARDRAIL: no event/property may carry a health key.
    func testNoDisallowedKeysAcrossAllProperties() {
        let banned = ["heart", "hrv", "hr", "sleep", "spo2", "oxygen", "steps", "state", "biometric", "verse_text", "reference"]
        let all: [AnalyticsEvent] = [
            .verseDelivered(method: "auto"), .verseLoved, .verseSaved, .verseShared, .verseReadMore, .verseDetailOpened,
            .feelingPickerOpened, .feelingPicked(emotion: "grateful"), .feedbackFit(answer: "yes"),
            .feedbackHelpful(answer: "no"), .feedbackCorrection(emotion: "stressed"),
            .prayerStarted, .prayerCompleted(durationS: 60), .prayerAmenEarly,
            .onboardingStepViewed(step: "welcome"), .permissionResult(kind: "health", granted: true), .onboardingCompleted,
            .appOpened, .sessionEnd(durationS: 30), .settingChanged(setting: "translation"), .analyticsOptOut,
            .votdOpened, .streakViewed, .apiFallbackUsed, .notificationOpened(), .notificationAction(action: "love"),
            .screenViewed(screen: "Home", durationS: 5),
            .watchOpened(), .watchTabViewed(tab: "verse"), .watchPrayerStarted(), .watchFeelingRequested()
        ]
        for e in all {
            for key in e.properties.keys {
                for b in banned where b != "state" { // 'state' substring guard below
                    XCTAssertFalse(key.lowercased().contains(b), "event \(e.name) has banned key \(key)")
                }
                XCTAssertNotEqual(key.lowercased(), "state")
            }
        }
    }
}
