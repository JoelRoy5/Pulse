import Foundation

public enum DeliveryRules {
    public static let minimumTimeBetweenDeliveries: TimeInterval = 2 * 3600
    public static let minimumSameStateDelay: TimeInterval = 12 * 3600
    public static let defaultMaxDailyDeliveries = 5
    public static let nightSilenceHours: ClosedRange<Int> = 0...5
    public static let minimumDataCompleteness = 0.40
    public static let minimumConfidence = 0.65
    public static let urgencyOverrideConfidence = 0.85
}

public struct DeliveryContext: Sendable {
    public var now: Date
    public var todayDeliveryCount: Int
    public var lastDeliveryAt: Date?
    public var lastSameStateDeliveryAt: Date?
    public var maxDailyDeliveries: Int   // 0 or less means "use default"

    public init(
        now: Date = .now,
        todayDeliveryCount: Int = 0,
        lastDeliveryAt: Date? = nil,
        lastSameStateDeliveryAt: Date? = nil,
        maxDailyDeliveries: Int = 5
    ) {
        self.now = now
        self.todayDeliveryCount = todayDeliveryCount
        self.lastDeliveryAt = lastDeliveryAt
        self.lastSameStateDeliveryAt = lastSameStateDeliveryAt
        self.maxDailyDeliveries = maxDailyDeliveries
    }
}

public struct DeliveryDecision: Sendable {
    public let approved: Bool
    public let reason: String            // machine-readable, e.g. "night_silence"

    public init(approved: Bool, reason: String) {
        self.approved = approved
        self.reason = reason
    }
}

public struct DeliveryRulesEngine {
    public init() {}

    public func shouldDeliver(
        for result: ClassificationResult,
        context: DeliveryContext,
        calendar: Calendar = .current
    ) -> DeliveryDecision {
        // Rule 1: Night silence (0-5) - except spiritualAlert
        let hour = calendar.component(.hour, from: context.now)
        if DeliveryRules.nightSilenceHours.contains(hour) {
            if result.state != .spiritualAlert {
                return DeliveryDecision(approved: false, reason: "night_silence")
            }
        }

        // Rule 2: Data completeness check
        if result.snapshot.dataCompleteness < DeliveryRules.minimumDataCompleteness {
            return DeliveryDecision(approved: false, reason: "insufficient_data")
        }

        // Rule 3: Confidence check
        if result.confidence < DeliveryRules.minimumConfidence {
            return DeliveryDecision(approved: false, reason: "low_confidence")
        }

        // Rule 4: Daily limit check
        let maxDaily = context.maxDailyDeliveries <= 0
            ? DeliveryRules.defaultMaxDailyDeliveries
            : context.maxDailyDeliveries
        if context.todayDeliveryCount >= maxDaily {
            return DeliveryDecision(approved: false, reason: "daily_limit")
        }

        // Check for urgency override conditions
        let isUrgent = result.state.deliveryUrgency == .high && result.confidence > DeliveryRules.urgencyOverrideConfidence

        // Rule 5: Global cooldown (2 hours)
        if let lastDelivery = context.lastDeliveryAt {
            let timeSinceLastDelivery = context.now.timeIntervalSince(lastDelivery)
            if timeSinceLastDelivery < DeliveryRules.minimumTimeBetweenDeliveries {
                if !isUrgent {
                    return DeliveryDecision(approved: false, reason: "cooldown")
                }
            }
        }

        // Rule 6: Same-state cooldown (12 hours)
        if let lastSameStateDelivery = context.lastSameStateDeliveryAt {
            let timeSinceSameStateDelivery = context.now.timeIntervalSince(lastSameStateDelivery)
            if timeSinceSameStateDelivery < DeliveryRules.minimumSameStateDelay {
                if !isUrgent {
                    return DeliveryDecision(approved: false, reason: "same_state_cooldown")
                }
            }
        }

        // All rules passed
        if isUrgent {
            return DeliveryDecision(approved: true, reason: "approved_urgent")
        } else {
            return DeliveryDecision(approved: true, reason: "approved")
        }
    }
}
