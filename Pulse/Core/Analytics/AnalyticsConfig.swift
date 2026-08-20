import Foundation

// MARK: - AnalyticsConfig

/// Reads PostHog credentials from the app's `Info.plist` (injected at build time
/// via xcconfig variables). Mirrors the pattern established by `AppConfig`.
enum AnalyticsConfig {

    // MARK: - Credential Keys

    static var postHogKey: String {
        Bundle.main.object(forInfoDictionaryKey: "PostHogKey") as? String ?? ""
    }

    static var postHogHost: String {
        let host = Bundle.main.object(forInfoDictionaryKey: "PostHogHost") as? String ?? ""
        return host.isEmpty ? "https://us.i.posthog.com" : host
    }

    // MARK: - Configuration State

    /// `true` when a real PostHog key is present (non-empty, no placeholder text).
    static var isConfigured: Bool {
        let key = postHogKey
        return !key.isEmpty && !key.contains("your_")
    }
}
