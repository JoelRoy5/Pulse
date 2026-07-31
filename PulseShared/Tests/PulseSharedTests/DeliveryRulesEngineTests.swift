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
}
