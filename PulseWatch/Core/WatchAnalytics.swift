import Foundation
import WatchConnectivity
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse.watch", category: "WatchAnalytics")

// MARK: - WatchAnalytics

/// Forwards analytics events to the paired iPhone via WatchConnectivity.
/// The phone is the PostHog gateway and opt-out gatekeeper — the watch never
/// posts directly to PostHog or reads PostHog credentials.
///
/// All public methods are `@MainActor`. Forwarding is fire-and-forget:
/// failures are logged silently and never surfaced to the UI.
@MainActor
final class WatchAnalytics {

    // MARK: - Shared

    static let shared = WatchAnalytics()

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Forward `event` to the iPhone. Uses `sendMessage` when the phone is
    /// reachable (real-time); falls back to `transferUserInfo` (guaranteed,
    /// queued by the system) when it is not.
    func track(_ event: AnalyticsEvent) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else {
            logger.debug("WatchAnalytics: WCSession not activated — dropping event '\(event.name, privacy: .public)'")
            return
        }

        let props: [String: Any] = event.properties.mapValues { $0.json }
        let message: [String: Any] = [
            "type": WatchMessage.MessageType.analyticsEvent.rawValue,
            "name": event.name,
            "props": props,
            "platform": "watchos",
            "ts": Date().timeIntervalSince1970
        ]

        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                logger.debug("WatchAnalytics: sendMessage failed for '\(event.name, privacy: .public)' — falling back to transferUserInfo (\(error.localizedDescription, privacy: .public))")
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }

        logger.debug("WatchAnalytics: forwarded '\(event.name, privacy: .public)' (reachable: \(session.isReachable, privacy: .public))")
    }
}
