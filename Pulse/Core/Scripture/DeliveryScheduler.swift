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
    /// Reads `UserPreferences.maxDailyVerses` from the cache's model context to honour
    /// the user's daily limit setting. Falls back to `DeliveryRules.defaultMaxDailyDeliveries`
    /// when no preferences row exists (<=0 values are handled downstream by the rules engine).
    func shouldDeliver(for result: ClassificationResult) -> Bool {
        let maxDailyVerses = cache.fetchMaxDailyVerses()
        let todayCount = cache.todayDeliveryCount()
        let lastDelivery = cache.lastDelivery()
        let lastSameState = cache.lastDelivery(for: result.state)

        let ctx = DeliveryContext(
            now: .now,
            todayDeliveryCount: todayCount,
            lastDeliveryAt: lastDelivery?.deliveredAt,
            lastSameStateDeliveryAt: lastSameState?.deliveredAt,
            maxDailyDeliveries: maxDailyVerses
        )

        let decision = rulesEngine.shouldDeliver(for: result, context: ctx)
        logger.info(
            "Delivery decision for \(result.state.rawValue, privacy: .public): \(decision.approved ? "APPROVED" : "DENIED") (\(decision.reason, privacy: .public))"
        )
        return decision.approved
    }
}
