import Foundation
import WatchConnectivity
import WidgetKit
import WatchKit
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse.watchkitapp", category: "WatchSessionManager")

// MARK: - WatchState

/// Observable state container consumed by the root watch view.
@Observable
final class WatchState {
    var currentVerse: WatchMessage.VerseDeliveryPayload?
    var healthSummary: WatchMessage.HealthSummaryPayload?
    var history: [WatchMessage.VerseDeliveryPayload] = []
}

// MARK: - WatchSessionManager

/// Manages the WatchConnectivity session on the Apple Watch side.
///
/// - Receives verse deliveries and health summaries from the iPhone.
/// - Sends reaction payloads back to the iPhone.
/// - Persists received data via `WatchDataStore` for the widget extension.
final class WatchSessionManager: NSObject {

    // MARK: - Singleton

    static let shared = WatchSessionManager()

    private override init() {
        super.init()
    }

    // MARK: - Dependencies

    let watchState = WatchState()
    private let dataStore = WatchDataStore()
    private var session: WCSession { .default }

    // MARK: - Activation

    /// Call once from `PulseWatchApp` on startup.
    func activate() {
        guard WCSession.isSupported() else {
            logger.info("WCSession not supported on this device")
            return
        }
        session.delegate = self
        session.activate()

        // Restore persisted state so the UI is populated even before the phone sends anything
        if let saved = dataStore.loadCurrent() {
            watchState.currentVerse = saved
        }
        watchState.history = dataStore.loadHistory()
        if let summary = dataStore.loadSummary() {
            watchState.healthSummary = summary
        }

        logger.info("WatchSessionManager: activating WCSession")
    }

    // MARK: - Send Reaction

    /// Sends a `ReactionPayload` to the iPhone.
    /// Prefers `sendMessage` when reachable; falls back to `transferUserInfo`.
    func sendReaction(_ reaction: VerseReaction, deliveryID: String) {
        guard WCSession.isSupported(), session.activationState == .activated else {
            logger.warning("sendReaction: session not activated")
            return
        }

        let payload = WatchMessage.ReactionPayload(
            deliveryID:   deliveryID,
            reactionRaw:  reaction.rawValue,
            timestamp:    Date().timeIntervalSince1970
        )
        let dict = payload.dictionary(type: .verseReaction)

        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil) { error in
                logger.warning("sendReaction sendMessage failed: \(error.localizedDescription, privacy: .public) — falling back to transferUserInfo")
                self.session.transferUserInfo(dict)
            }
        } else {
            session.transferUserInfo(dict)
        }
        logger.info("sendReaction: \(reaction.rawValue, privacy: .public) for \(deliveryID, privacy: .public)")
    }

    // MARK: - Request Latest Verse (background refresh)

    /// Called from `WatchAppDelegate` during a background refresh task to prompt
    /// the phone to resend the current verse if available.
    func requestLatestVerse() async {
        guard WCSession.isSupported(), session.isReachable else {
            logger.info("requestLatestVerse: session not reachable — skipping")
            return
        }
        let request: [String: Any] = [
            "type": WatchMessage.MessageType.requestLatestVerse.rawValue
        ]
        await withCheckedContinuation { continuation in
            session.sendMessage(request, replyHandler: { reply in
                // Apply the returned verse payload through the standard receive path
                // so it is persisted and watchState is updated consistently.
                if let payload = WatchMessage.VerseDeliveryPayload.from(reply) {
                    self.receiveVerse(payload)
                    logger.info("requestLatestVerse: applied reply verse \(payload.verseReference, privacy: .public)")
                } else {
                    logger.info("requestLatestVerse: reply contained no verse payload")
                }
                continuation.resume()
            }, errorHandler: { error in
                logger.warning("requestLatestVerse failed: \(error.localizedDescription, privacy: .public)")
                continuation.resume()
            })
        }
    }

    /// Called from `WatchAppDelegate` for `WKWatchConnectivityRefreshBackgroundTask`.
    func handleBackgroundConnectivity() {
        logger.info("handleBackgroundConnectivity: processing pending transfers")
        // Outstanding transfers arrive via delegate callbacks automatically;
        // nothing explicit is needed beyond ensuring the session is active.
    }

    // MARK: - Internal Handler

    private func handleIncomingPayload(_ dict: [String: Any]) {
        guard let typeRaw = dict["type"] as? String,
              let type = WatchMessage.MessageType(rawValue: typeRaw) else {
            logger.warning("handleIncomingPayload: unknown or missing type — \(dict.keys.joined(separator: ","), privacy: .public)")
            return
        }

        switch type {
        case .verseDelivery:
            if let payload = WatchMessage.VerseDeliveryPayload.from(dict) {
                receiveVerse(payload)
            }
        case .healthSummary:
            if let payload = WatchMessage.HealthSummaryPayload.from(dict) {
                receiveHealthSummary(payload)
            }
        default:
            logger.info("handleIncomingPayload: unhandled type \(typeRaw, privacy: .public)")
        }
    }

    private func receiveVerse(_ payload: WatchMessage.VerseDeliveryPayload) {
        logger.info("receiveVerse: \(payload.verseReference, privacy: .public)")

        // Persist to App Group FIRST (synchronous file I/O on delegate queue)
        // so that the subsequent @MainActor Task observes the appended entry.
        dataStore.save(current: payload)
        dataStore.appendHistory(payload)

        // Update observable state on main thread after persistence is complete
        Task { @MainActor in
            self.watchState.currentVerse = payload
            self.watchState.history = self.dataStore.loadHistory()
        }

        // Haptic feedback
        WKInterfaceDevice.current().play(.notification)

        // Reload widget timelines
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func receiveHealthSummary(_ payload: WatchMessage.HealthSummaryPayload) {
        logger.info("receiveHealthSummary: state \(payload.stateRaw, privacy: .public)")

        Task { @MainActor in
            self.watchState.healthSummary = payload
        }
        dataStore.save(summary: payload)
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            logger.error("WCSession activation failed: \(error.localizedDescription, privacy: .public)")
        } else {
            logger.info("WCSession activated — state: \(activationState.rawValue, privacy: .public)")
        }
    }

    // Real-time messages (phone is in foreground)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingPayload(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handleIncomingPayload(message)
        replyHandler([:])
    }

    // Guaranteed-delivery channel — `transferUserInfo` arrives here, NOT didReceiveMessage
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleIncomingPayload(userInfo)
    }
}
