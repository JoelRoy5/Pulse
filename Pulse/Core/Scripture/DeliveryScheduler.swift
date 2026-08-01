import Foundation
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "DeliveryScheduler")

// MARK: - DeliveryScheduler

/// Builds a `DeliveryContext` from `VerseCache` and `UserPreferences`, then consults
/// `DeliveryRulesEngine` to decide whether delivery should proceed.
@MainActor
final class DeliveryScheduler {

    private let cache: VerseCache
    private let rulesEngine = DeliveryRulesEngine()

    init(cache: VerseCache) {
        self.cache = cache
    }

    /// Returns `true` if the rules engine approves delivery for the given classification.
    ///
    /// Reads `UserPreferences` from the cache's model context to honour:
    ///   - `maxDailyVerses`        → daily delivery cap
    ///   - `quietHoursStart/End`   → custom quiet-hours window
    ///   - `enableEmergencyOverride` → whether urgent states can bypass cooldowns
    func shouldDeliver(for result: ClassificationResult) -> Bool {
        let prefs = cache.fetchUserPreferences()
        let todayCount = cache.todayDeliveryCount()
        let lastDelivery = cache.lastDelivery()
        let lastSameState = cache.lastDelivery(for: result.state)

        let ctx = DeliveryContext(
            now: .now,
            todayDeliveryCount: todayCount,
            lastDeliveryAt: lastDelivery?.deliveredAt,
            lastSameStateDeliveryAt: lastSameState?.deliveredAt,
            maxDailyDeliveries: prefs.maxDailyVerses,
            quietHoursStart: prefs.quietHoursStart,
            quietHoursEnd: prefs.quietHoursEnd,
            allowUrgencyOverride: prefs.enableEmergencyOverride
        )

        let decision = rulesEngine.shouldDeliver(for: result, context: ctx)
        logger.info(
            "Delivery decision for \(result.state.rawValue, privacy: .public): \(decision.approved ? "APPROVED" : "DENIED") (\(decision.reason, privacy: .public))"
        )
        return decision.approved
    }
}
