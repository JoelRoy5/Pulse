import Foundation
import WatchConnectivity
import SwiftData
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "PhoneSessionManager")

// MARK: - PhoneSessionManager

/// Manages the WatchConnectivity session on the iPhone side.
///
/// - Sends verse deliveries via `sendMessage` when the watch is reachable,
///   or `transferUserInfo` (guaranteed delivery) otherwise.
/// - Receives `ReactionPayload` from the watch and updates the matching
///   `VerseDelivery.userReaction` in SwiftData using `AppBridge.modelContainer`.
final class PhoneSessionManager: NSObject {

    // MARK: - Singleton

    static let shared = PhoneSessionManager()

    private override init() {
        super.init()
    }

    // MARK: - State

    private var session: WCSession { .default }

    // MARK: - Activation

    /// Call this once from `PulseApp.body` on the main thread.
    func activate() {
        guard WCSession.isSupported() else {
            logger.info("WCSession not supported on this device")
            return
        }
        session.delegate = self
        session.activate()
        logger.info("PhoneSessionManager: activating WCSession")
    }

    // MARK: - Send Verse

    /// Builds a `VerseDeliveryPayload` from a persisted `VerseDelivery` and
    /// sends it to the watch.  Prefers `sendMessage` (real-time) when the watch
    /// is reachable; falls back to `transferUserInfo` for guaranteed delivery.
    func sendVerse(_ delivery: VerseDelivery) {
        guard WCSession.isSupported(), session.activationState == .activated else {
            logger.warning("sendVerse: session not activated — skipping")
            return
        }

        let state = delivery.biometricState
        let primaryColor = state?.primaryColorHex ?? "#C9A96E"
        let stateSymbol   = state?.systemImageName ?? "sparkles"

        let payload = WatchMessage.VerseDeliveryPayload(
            deliveryID:              delivery.id.uuidString,
            verseText:               delivery.verseText,
            verseReference:          delivery.verseReference,
            translationAbbreviation: delivery.translationAbbreviation,
            stateRaw:                delivery.biometricStateRaw,
            stateDisplayName:        state?.displayName  ?? delivery.biometricStateRaw,
            stateSymbol:              stateSymbol,
            stateBodyText:           delivery.stateBodyText,
            primaryColor:            primaryColor,
            timestamp:               delivery.deliveredAt.timeIntervalSince1970,
            emotionName:             delivery.emotion.displayName,
            heartRate:               delivery.heartRateAtDelivery,
            hrv:                     delivery.hrvAtDelivery,
            sleepEfficiency:         delivery.sleepEfficiencyAtDelivery
        )

        let dict = payload.dictionary(type: .verseDelivery)

        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil) { error in
                logger.warning("sendMessage failed (\(error.localizedDescription, privacy: .public)) — falling back to transferUserInfo")
                self.session.transferUserInfo(dict)
            }
            logger.info("sendVerse: sent via sendMessage — \(delivery.verseReference, privacy: .public)")
        } else {
            session.transferUserInfo(dict)
            logger.info("sendVerse: sent via transferUserInfo — \(delivery.verseReference, privacy: .public)")
        }
    }

    // MARK: - Send Health Summary

    /// Sends the current health snapshot and classification state to the watch.
    func sendHealthSummary(snapshot: HealthSnapshot, state: BiometricState) {
        guard WCSession.isSupported(), session.activationState == .activated else { return }

        let payload = WatchMessage.HealthSummaryPayload(
            heartRate:        snapshot.heartRate,
            hrv:              snapshot.heartRateVariability,
            oxygenSaturation: snapshot.oxygenSaturation,
            sleepEfficiency:  snapshot.sleepEfficiency,
            stepCount:        snapshot.stepCount,
            stateRaw:         state.rawValue,
            lastUpdated:      snapshot.timestamp.timeIntervalSince1970
        )

        let dict = payload.dictionary(type: .healthSummary)

        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil) { error in
                logger.warning("sendHealthSummary sendMessage failed: \(error.localizedDescription, privacy: .public)")
                self.session.transferUserInfo(dict)
            }
        } else {
            session.transferUserInfo(dict)
        }
        logger.info("sendHealthSummary: dispatched for state \(state.rawValue, privacy: .public)")
    }

    // MARK: - Send Settings Update

    /// Sends a `settings_update` payload to the watch via `transferUserInfo` (guaranteed delivery).
    /// The watch currently ignores this payload; it is wired here so future watch versions can react.
    func sendSettingsUpdate(_ payload: [String: Any]) {
        guard WCSession.isSupported(), session.activationState == .activated else { return }
        session.transferUserInfo(payload)
        logger.info("sendSettingsUpdate: dispatched settings payload to watch")
    }

    // MARK: - Handle Incoming Messages

    /// Routes an incoming WC message. When `replyHandler` is provided (i.e. the
    /// message arrived via `session(_:didReceiveMessage:replyHandler:)`), this method
    /// is responsible for calling it exactly once — even asynchronously when a
    /// MainActor fetch is required.
    private func handleIncomingMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)? = nil
    ) {
        guard let typeRaw = message["type"] as? String,
              let type = WatchMessage.MessageType(rawValue: typeRaw) else {
            replyHandler?([:])
            return
        }

        switch type {
        case .verseReaction:
            guard let reaction = WatchMessage.ReactionPayload.from(message) else {
                replyHandler?([:])
                return
            }
            logger.info("Received reaction \(reaction.reactionRaw, privacy: .public) for delivery \(reaction.deliveryID, privacy: .public)")
            persistReaction(reaction)
            replyHandler?([:])

        case .requestLatestVerse:
            logger.info("Received request_latest_verse from watch")
            // Fetching the latest verse requires MainActor (AppBridge + mainContext).
            // If a replyHandler was supplied, call it after the fetch; otherwise fire-and-forget.
            Task { @MainActor in
                let dict = self.latestVersePayloadDict()
                replyHandler?(dict ?? [:])
            }

        case .requestVerseForState:
            let stateRaw = message["stateRaw"] as? String ?? ""
            logger.info("Received request_verse_for_state '\(stateRaw, privacy: .public)' from watch")
            // Run the live pipeline for the requested feeling and reply with the verse.
            // (persistDelivery also pushes it to the watch via onDelivery.)
            Task { @MainActor in
                let dict = await self.deliverVerseForState(stateRaw)
                replyHandler?(dict ?? [:])
            }

        default:
            replyHandler?([:])
        }
    }

    /// Runs the live verse pipeline for a watch-requested feeling and returns the
    /// resulting delivery as a payload dict (nil if the state or engine is missing).
    @MainActor
    private func deliverVerseForState(_ stateRaw: String) async -> [String: Any]? {
        guard let state = BiometricState(rawValue: stateRaw),
              let engine = AppBridge.shared.scriptureEngine else {
            logger.warning("deliverVerseForState: missing state or scriptureEngine")
            return nil
        }
        // No phone notification for a watch-initiated request — the user is
        // already looking at the verse on their wrist.
        let delivery = await engine.deliverFirstVerse(mockState: state, suppressNotification: true)
        return payloadDict(from: delivery)
    }

    /// Fetches the most recently delivered VerseDelivery and returns its payload
    /// dictionary for replying to the watch's background-refresh request.
    /// Must be called on the MainActor (uses AppBridge.shared and mainContext).
    @MainActor
    private func latestVersePayloadDict() -> [String: Any]? {
        guard let container = AppBridge.shared.modelContainer else {
            logger.error("latestVersePayloadDict: AppBridge.modelContainer is nil")
            return nil
        }
        let context = container.mainContext
        var descriptor = FetchDescriptor<VerseDelivery>(
            sortBy: [SortDescriptor(\.deliveredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let delivery = (try? context.fetch(descriptor))?.first else {
            logger.info("latestVersePayloadDict: no VerseDelivery found")
            return nil
        }
        return payloadDict(from: delivery)
    }

    /// Builds the WC payload dictionary for a delivery (shared by the latest-verse
    /// and verse-for-feeling reply paths).
    @MainActor
    private func payloadDict(from delivery: VerseDelivery) -> [String: Any] {
        let state = delivery.biometricState
        let payload = WatchMessage.VerseDeliveryPayload(
            deliveryID:              delivery.id.uuidString,
            verseText:               delivery.verseText,
            verseReference:          delivery.verseReference,
            translationAbbreviation: delivery.translationAbbreviation,
            stateRaw:                delivery.biometricStateRaw,
            stateDisplayName:        state?.displayName  ?? delivery.biometricStateRaw,
            stateSymbol:              state?.systemImageName ?? "sparkles",
            stateBodyText:           delivery.stateBodyText,
            primaryColor:            state?.primaryColorHex ?? "#C9A96E",
            timestamp:               delivery.deliveredAt.timeIntervalSince1970,
            emotionName:             delivery.emotion.displayName,
            heartRate:               delivery.heartRateAtDelivery,
            hrv:                     delivery.hrvAtDelivery,
            sleepEfficiency:         delivery.sleepEfficiencyAtDelivery
        )
        return payload.dictionary(type: .verseDelivery)
    }

    private func persistReaction(_ reaction: WatchMessage.ReactionPayload) {
        let deliveryIDString = reaction.deliveryID
        let reactionRaw      = reaction.reactionRaw

        Task { @MainActor in
            guard let container = AppBridge.shared.modelContainer else {
                logger.error("persistReaction: AppBridge.modelContainer is nil — reaction lost")
                return
            }

            let context = container.mainContext
            guard let uuid = UUID(uuidString: deliveryIDString) else {
                logger.warning("persistReaction: invalid UUID string \(deliveryIDString, privacy: .public)")
                return
            }
            let descriptor = FetchDescriptor<VerseDelivery>(
                predicate: #Predicate { $0.id == uuid }
            )
            guard let delivery = (try? context.fetch(descriptor))?.first else {
                logger.warning("persistReaction: no VerseDelivery found for id \(deliveryIDString, privacy: .public)")
                return
            }

            delivery.engagedAt = Date()
            // Love / Save are independent toggles; other reactions use the single field.
            switch VerseReaction(rawValue: reactionRaw) {
            case .loved: delivery.lovedAt = delivery.isLoved ? nil : Date()
            case .saved: delivery.savedAt = delivery.isSaved ? nil : Date()
            default:     delivery.userReaction = VerseReaction(rawValue: reactionRaw)
            }
            do {
                try context.save()
                logger.info("persistReaction: updated delivery \(deliveryIDString, privacy: .public) → \(reactionRaw, privacy: .public)")
            } catch {
                logger.error("persistReaction: save failed — \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneSessionManager: WCSessionDelegate {

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

    // Required on iOS
    func sessionDidBecomeInactive(_ session: WCSession) {
        logger.info("WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        logger.info("WCSession deactivated — reactivating")
        session.activate()
    }

    // Real-time messages (watch is in foreground)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingMessage(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        // replyHandler is forwarded into handleIncomingMessage so it can be called
        // asynchronously when a MainActor fetch is required (e.g. requestLatestVerse).
        handleIncomingMessage(message, replyHandler: replyHandler)
    }

    // Guaranteed-delivery messages (transferUserInfo)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleIncomingMessage(userInfo)
    }
}
