import Foundation

/// A value type that can be sent to PostHog.
public enum AnalyticsValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    /// Convert to a JSON-serializable type.
    public var json: Any {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .bool(let value):
            return value
        }
    }
}

/// A closed, health-safe analytics event. Constructed only via static factories.
public struct AnalyticsEvent: Sendable {
    public let name: String
    public let properties: [String: AnalyticsValue]

    private init(name: String, properties: [String: AnalyticsValue] = [:]) {
        self.name = name
        self.properties = properties
    }

    // MARK: - Verse Events

    public static func verseDelivered(method: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "verse_delivered", properties: ["method": .string(method)])
    }

    public static let verseLoved = AnalyticsEvent(name: "verse_loved")
    public static let verseSaved = AnalyticsEvent(name: "verse_saved")
    public static let verseShared = AnalyticsEvent(name: "verse_shared")
    public static let verseReadMore = AnalyticsEvent(name: "verse_read_more")
    public static let verseDetailOpened = AnalyticsEvent(name: "verse_detail_opened")

    // MARK: - Feeling Events

    public static let feelingPickerOpened = AnalyticsEvent(name: "feeling_picker_opened")

    public static func feelingPicked(emotion: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "feeling_picked", properties: ["emotion": .string(emotion)])
    }

    // MARK: - Feedback Events

    public static func feedbackFit(answer: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "feedback_fit", properties: ["answer": .string(answer)])
    }

    public static func feedbackHelpful(answer: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "feedback_helpful", properties: ["answer": .string(answer)])
    }

    public static func feedbackCorrection(emotion: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "feedback_correction", properties: ["emotion": .string(emotion)])
    }

    // MARK: - Prayer Events

    public static let prayerStarted = AnalyticsEvent(name: "prayer_started")

    public static func prayerCompleted(durationS: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "prayer_completed", properties: ["duration_s": .int(durationS)])
    }

    public static let prayerAmenEarly = AnalyticsEvent(name: "prayer_amen_early")

    // MARK: - Onboarding Events

    public static func onboardingStepViewed(step: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "onboarding_step_viewed", properties: ["step": .string(step)])
    }

    public static func permissionResult(kind: String, granted: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "permission_result", properties: ["kind": .string(kind), "granted": .bool(granted)])
    }

    public static let onboardingCompleted = AnalyticsEvent(name: "onboarding_completed")

    // MARK: - Session Events

    public static let appOpened = AnalyticsEvent(name: "app_opened")

    public static func sessionEnd(durationS: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "session_end", properties: ["duration_s": .int(durationS)])
    }

    // MARK: - Settings Events

    public static func settingChanged(setting: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "setting_changed", properties: ["setting": .string(setting)])
    }

    public static let analyticsOptOut = AnalyticsEvent(name: "analytics_opt_out")

    // MARK: - Home/Dashboard Events

    public static let votdOpened = AnalyticsEvent(name: "votd_opened")
    public static let streakViewed = AnalyticsEvent(name: "streak_viewed")
    public static let apiFallbackUsed = AnalyticsEvent(name: "api_fallback_used")

    // MARK: - Notification Events

    public static func notificationOpened() -> AnalyticsEvent {
        AnalyticsEvent(name: "notification_opened")
    }

    public static func notificationAction(action: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "notification_action", properties: ["action": .string(action)])
    }

    // MARK: - Screen Events

    public static func screenViewed(screen: String, durationS: Int?) -> AnalyticsEvent {
        var props: [String: AnalyticsValue] = ["screen": .string(screen)]
        if let durationS = durationS {
            props["duration_s"] = .int(durationS)
        }
        return AnalyticsEvent(name: "screen_viewed", properties: props)
    }

    // MARK: - Watch Events

    public static func watchOpened() -> AnalyticsEvent {
        AnalyticsEvent(name: "watch_opened")
    }

    public static func watchTabViewed(tab: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "watch_tab_viewed", properties: ["tab": .string(tab)])
    }

    public static func watchPrayerStarted() -> AnalyticsEvent {
        AnalyticsEvent(name: "watch_prayer_started")
    }

    public static func watchFeelingRequested() -> AnalyticsEvent {
        AnalyticsEvent(name: "watch_feeling_requested")
    }

    // MARK: - Insights Events

    public static let insightsSelfReportTapped = AnalyticsEvent(name: "insights_self_report_tapped")

    // MARK: - PostHog Payload

    private static let iso8601 = ISO8601DateFormatter()

    public func payload(distinctID: String, appVersion: String, platform: String, timestamp: Double) -> [String: Any] {
        let iso8601 = AnalyticsEvent.iso8601.string(from: Date(timeIntervalSince1970: timestamp))

        var mergedProps: [String: Any] = properties.mapValues { $0.json }
        mergedProps["platform"] = platform
        mergedProps["$app_version"] = appVersion
        mergedProps["$lib"] = "pulse"

        return [
            "event": name,
            "distinct_id": distinctID,
            "properties": mergedProps,
            "timestamp": iso8601
        ]
    }
}
