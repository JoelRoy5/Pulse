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

    /// Optional custom quiet-hours window (hour of day, 0–23).
    /// When nil, falls back to the built-in `DeliveryRules.nightSilenceHours` (0...5).
    /// Supports wrap-around ranges (e.g. start=22, end=6 means 22:00–06:00).
    public var quietHoursStart: Int?
    public var quietHoursEnd: Int?

    /// When false, urgency-state override of cooldowns is disabled even for high-urgency states.
    /// Defaults to true (existing behaviour preserved).
    public var allowUrgencyOverride: Bool

    public init(
        now: Date = .now,
        todayDeliveryCount: Int = 0,
        lastDeliveryAt: Date? = nil,
        lastSameStateDeliveryAt: Date? = nil,
        maxDailyDeliveries: Int = 5,
        quietHoursStart: Int? = nil,
        quietHoursEnd: Int? = nil,
        allowUrgencyOverride: Bool = true
    ) {
        self.now = now
        self.todayDeliveryCount = todayDeliveryCount
        self.lastDeliveryAt = lastDeliveryAt
        self.lastSameStateDeliveryAt = lastSameStateDeliveryAt
        self.maxDailyDeliveries = maxDailyDeliveries
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.allowUrgencyOverride = allowUrgencyOverride
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
        // Rule 1: Night silence — except spiritualAlert.
        // Uses custom quiet hours (quietHoursStart/End) when present; otherwise built-in 0...5.
        let hour = calendar.component(.hour, from: context.now)
        let inQuietHours: Bool
        if let start = context.quietHoursStart, let end = context.quietHoursEnd {
            if start <= end {
                // Simple contiguous range, e.g. 0...5
                inQuietHours = hour >= start && hour < end
            } else {
                // Wrap-around range, e.g. 22...6 (22:00 through 05:59)
                inQuietHours = hour >= start || hour < end
            }
        } else {
            inQuietHours = DeliveryRules.nightSilenceHours.contains(hour)
        }
        if inQuietHours && result.state != .spiritualAlert {
            return DeliveryDecision(approved: false, reason: "night_silence")
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

        // Check for urgency override conditions (requires allowUrgencyOverride flag)
        let isUrgent = context.allowUrgencyOverride
            && result.state.deliveryUrgency == .high
            && result.confidence > DeliveryRules.urgencyOverrideConfidence

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
