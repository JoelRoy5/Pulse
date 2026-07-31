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
        let stateEmoji   = state?.emoji          ?? "✨"

        let payload = WatchMessage.VerseDeliveryPayload(
            deliveryID:              delivery.id.uuidString,
            verseText:               delivery.verseText,
            verseReference:          delivery.verseReference,
            translationAbbreviation: delivery.translationAbbreviation,
            stateRaw:                delivery.biometricStateRaw,
            stateDisplayName:        state?.displayName  ?? delivery.biometricStateRaw,
            stateEmoji:              stateEmoji,
            stateBodyText:           delivery.stateBodyText,
            primaryColor:            primaryColor,
            timestamp:               delivery.deliveredAt.timeIntervalSince1970
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

    // MARK: - Handle Incoming Reaction

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard
            let typeRaw = message["type"] as? String,
            typeRaw == WatchMessage.MessageType.verseReaction.rawValue,
            let reaction = WatchMessage.ReactionPayload.from(message)
        else { return }

        logger.info("Received reaction \(reaction.reactionRaw, privacy: .public) for delivery \(reaction.deliveryID, privacy: .public)")
        persistReaction(reaction)
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
            let descriptor = FetchDescriptor<VerseDelivery>()
            guard let deliveries = try? context.fetch(descriptor) else { return }

            guard let delivery = deliveries.first(where: { $0.id.uuidString == deliveryIDString }) else {
                logger.warning("persistReaction: no VerseDelivery found for id \(deliveryIDString, privacy: .public)")
                return
            }

            delivery.userReaction = VerseReaction(rawValue: reactionRaw)
            delivery.engagedAt    = Date()
            try? context.save()
            logger.info("persistReaction: updated delivery \(deliveryIDString, privacy: .public) → \(reactionRaw, privacy: .public)")
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
        handleIncomingMessage(message)
        replyHandler([:])
    }

    // Guaranteed-delivery messages (transferUserInfo)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleIncomingMessage(userInfo)
    }
}
