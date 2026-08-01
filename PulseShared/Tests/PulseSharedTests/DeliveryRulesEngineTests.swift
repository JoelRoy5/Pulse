import XCTest
@testable import PulseShared

final class DeliveryRulesEngineTests: XCTestCase {
    private let engine = DeliveryRulesEngine()
    private func result(_ state: BiometricState, confidence: Double,
                        completeness: Double = 0.8) -> ClassificationResult {
        var snap = HealthSnapshot(); snap.dataCompleteness = completeness
        let scores = BiometricSubScores(hrStress: 0.5, hrvRecovery: 0.5, sleepQuality: 0.5,
            oxygenLevel: 0.7, activityLevel: 0.5, respiratoryStress: 0.5, timeOfDay: .afternoon)
        return ClassificationResult(state: state, confidence: confidence,
                                    snapshot: snap, subScores: scores)
    }
    private func at(hour: Int) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 1; c.day = 15; c.hour = hour
        return Calendar.current.date(from: c)!
    }
    private func at(hour: Int, minute: Int) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 1; c.day = 15
        c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    func testNightSilenceBlocksExceptWatchman() {
        let ctx = DeliveryContext(now: at(hour: 3))
        XCTAssertFalse(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.9), context: ctx).approved)
        XCTAssertTrue(engine.shouldDeliver(for: result(.spiritualAlert, confidence: 0.9), context: ctx).approved)
    }
    func testDataAndConfidenceThresholds() {
        let ctx = DeliveryContext(now: at(hour: 10))
        XCTAssertEqual(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.9, completeness: 0.2), context: ctx).reason, "insufficient_data")
        XCTAssertEqual(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.5), context: ctx).reason, "low_confidence")
    }
    func testDailyLimitAndCooldowns() {
        var ctx = DeliveryContext(now: at(hour: 10))
        ctx.todayDeliveryCount = 5
        XCTAssertEqual(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.8), context: ctx).reason, "daily_limit")

        ctx = DeliveryContext(now: at(hour: 10))
        ctx.lastDeliveryAt = at(hour: 9)  // 1h ago < 2h cooldown
        XCTAssertEqual(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.8), context: ctx).reason, "cooldown")

        ctx = DeliveryContext(now: at(hour: 22))
        ctx.lastDeliveryAt = at(hour: 8)
        ctx.lastSameStateDeliveryAt = at(hour: 14) // 8h ago < 12h same-state
        XCTAssertEqual(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.8), context: ctx).reason, "same_state_cooldown")
    }
    func testUrgencyOverrideBypassesCooldownsOnly() {
        var ctx = DeliveryContext(now: at(hour: 10))
        ctx.lastDeliveryAt = at(hour: 9, minute: 30)
        let urgent = result(.stressedAnxious, confidence: 0.9)
        XCTAssertEqual(engine.shouldDeliver(for: urgent, context: ctx).reason, "approved_urgent")
        // but not the daily limit
        ctx.todayDeliveryCount = 5
        XCTAssertFalse(engine.shouldDeliver(for: urgent, context: ctx).approved)
        // and not night silence
        let night = DeliveryContext(now: at(hour: 2))
        XCTAssertFalse(engine.shouldDeliver(for: urgent, context: night).approved)
    }

    // MARK: - Custom Quiet Hours

    func testCustomQuietHoursBlocksWithinRange() {
        // Custom range 22...6 (wrap-around): hour 23 should be blocked
        var ctx = DeliveryContext(now: at(hour: 23))
        ctx.quietHoursStart = 22
        ctx.quietHoursEnd = 6
        XCTAssertFalse(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.9), context: ctx).approved)
        XCTAssertEqual(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.9), context: ctx).reason, "night_silence")
    }

    func testCustomQuietHoursAllowsOutsideRange() {
        // Custom range 22...6: hour 12 should be allowed
        var ctx = DeliveryContext(now: at(hour: 12))
        ctx.quietHoursStart = 22
        ctx.quietHoursEnd = 6
        XCTAssertTrue(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.9), context: ctx).approved)
    }

    func testCustomQuietHoursWrapAroundMidnight() {
        // Custom range 22...6: hour 0 (midnight) is inside the wrap-around range → blocked
        var ctx = DeliveryContext(now: at(hour: 0))
        ctx.quietHoursStart = 22
        ctx.quietHoursEnd = 6
        XCTAssertFalse(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.9), context: ctx).approved)

        // hour 5 is still inside 22...6 → blocked
        var ctx5 = DeliveryContext(now: at(hour: 5))
        ctx5.quietHoursStart = 22
        ctx5.quietHoursEnd = 6
        XCTAssertFalse(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.9), context: ctx5).approved)

        // hour 7 is outside 22...6 → allowed
        var ctx7 = DeliveryContext(now: at(hour: 7))
        ctx7.quietHoursStart = 22
        ctx7.quietHoursEnd = 6
        XCTAssertTrue(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.9), context: ctx7).approved)
    }

    func testCustomQuietHoursSpiritualAlertExempt() {
        // spiritualAlert is exempt even within custom quiet hours
        var ctx = DeliveryContext(now: at(hour: 23))
        ctx.quietHoursStart = 22
        ctx.quietHoursEnd = 6
        XCTAssertTrue(engine.shouldDeliver(for: result(.spiritualAlert, confidence: 0.9), context: ctx).approved)
    }

    func testNilQuietHoursUseBuiltInDefault() {
        // nil quietHoursStart/End falls back to built-in 0...5 range
        let ctx = DeliveryContext(now: at(hour: 3))   // hour 3 is within 0...5
        // quietHoursStart/End not set (nil) → default behavior
        XCTAssertFalse(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.9), context: ctx).approved)

        let ctx10 = DeliveryContext(now: at(hour: 10)) // hour 10 outside 0...5
        XCTAssertTrue(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.9), context: ctx10).approved)
    }

    // MARK: - allowUrgencyOverride

    func testUrgencyOverrideDisabledPreventsOverride() {
        // When allowUrgencyOverride is false, urgent states can no longer bypass cooldown
        var ctx = DeliveryContext(now: at(hour: 10))
        ctx.lastDeliveryAt = at(hour: 9, minute: 30)
        ctx.allowUrgencyOverride = false
        let urgent = result(.stressedAnxious, confidence: 0.9)
        XCTAssertEqual(engine.shouldDeliver(for: urgent, context: ctx).reason, "cooldown")
    }

    func testUrgencyOverrideEnabledByDefault() {
        // allowUrgencyOverride defaults to true → existing behavior preserved
        var ctx = DeliveryContext(now: at(hour: 10))
        ctx.lastDeliveryAt = at(hour: 9, minute: 30)
        let urgent = result(.stressedAnxious, confidence: 0.9)
        XCTAssertEqual(engine.shouldDeliver(for: urgent, context: ctx).reason, "approved_urgent")
    }
}
