import Foundation
import UserNotifications
import SwiftData
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "NotificationService")

// MARK: - NotificationService

/// Handles local verse notification scheduling and action responses.
///
/// Notification category `verse_notification` with actions:
///   - `LOVE_VERSE` → VerseReaction.loved
///   - `SAVE_VERSE`  → VerseReaction.saved
///   - `DISMISS`     → VerseReaction.dismissed
final class NotificationService: NSObject {

    // MARK: - Singleton

    static let shared = NotificationService()

    // MARK: - Private

    private let center = UNUserNotificationCenter.current()

    // MARK: - Init

    private override init() {
        super.init()
        registerCategories()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            logger.info("Notification authorization: \(granted ? "granted" : "denied", privacy: .public)")
            return granted
        } catch {
            logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Scheduling

    /// Schedules a local notification for a verse delivery.
    ///
    /// - Parameters:
    ///   - delivery: The verse delivery to notify about.
    ///   - style: Controls notification content format:
    ///       - `"title_only"` → title banner only, no body text.
    ///       - `"with_reference"` → title + verse reference as subtitle; no verse body.
    ///       - `"full"` (default) → title + reference + excerpt of verse text.
    func scheduleVerseNotification(_ delivery: VerseDelivery, style: String = "full") async {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.categoryIdentifier = "verse_notification"
        content.userInfo = ["deliveryID": delivery.id.uuidString]

        // Title template per state (shared across all styles)
        if let state = delivery.biometricState {
            switch state {
            case .energizedPostWorkout:
                content.title = "Well done \u{2014} here's your verse"
            case .morningAwakening, .deepRestRecovered:
                content.title = "Good morning \u{2014} new mercies today"
            default:
                content.title = "A word for you right now"
            }
        } else {
            content.title = "A word for you right now"
        }

        // Body template controlled by notificationStyle preference
        switch style {
        case "title_only":
            // Banner only — no subtitle or body
            break
        case "with_reference":
            content.subtitle = delivery.verseReference
        default: // "full"
            content.subtitle = "Tap to read the full verse"
            content.body = "\"\(delivery.verseText.excerpt())\" \u{2014} \(delivery.verseReference)"
        }

        // Fire immediately (trigger = nil means deliver right away)
        let request = UNNotificationRequest(
            identifier: delivery.id.uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
            logger.info("Scheduled notification for delivery: \(delivery.id, privacy: .public) style=\(style, privacy: .public)")
        } catch {
            logger.error("Failed to schedule notification: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Category Registration

    func registerCategories() {
        let loveAction = UNNotificationAction(
            identifier: "LOVE_VERSE",
            title: "Love",
            options: []
        )
        let saveAction = UNNotificationAction(
            identifier: "SAVE_VERSE",
            title: "Save",
            options: []
        )
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )

        let category = UNNotificationCategory(
            identifier: "verse_notification",
            actions: [loveAction, saveAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])
        logger.debug("Notification categories registered")
    }

    // MARK: - Reaction Handling

    /// Updates `VerseDelivery.userReaction` in SwiftData for the given delivery ID and action.
    func handleAction(_ actionIdentifier: String, deliveryID: UUID, context: ModelContext) {
        let reaction: VerseReaction?
        switch actionIdentifier {
        case "LOVE_VERSE": reaction = .loved
        case "SAVE_VERSE":  reaction = .saved
        case "DISMISS":     reaction = .dismissed
        default:            reaction = nil
        }

        guard let reaction else { return }

        let descriptor = FetchDescriptor<VerseDelivery>(
            predicate: #Predicate { $0.id == deliveryID }
        )
        if let delivery = try? context.fetch(descriptor).first {
            delivery.engagedAt = .now
            switch reaction {
            case .loved: delivery.lovedAt = delivery.isLoved ? nil : .now
            case .saved: delivery.savedAt = delivery.isSaved ? nil : .now
            default:     delivery.userReaction = reaction
            }
            try? context.save()
            logger.info("Reaction '\(reaction.rawValue, privacy: .public)' saved for delivery \(deliveryID, privacy: .public)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {

    /// Allow notifications to appear as banners with sound when app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Handle notification action taps.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard
            let idString = userInfo["deliveryID"] as? String,
            let deliveryID = UUID(uuidString: idString)
        else {
            completionHandler()
            return
        }

        let actionIdentifier = response.actionIdentifier
        logger.info("Notification action '\(actionIdentifier, privacy: .public)' for delivery \(deliveryID, privacy: .public)")

        Task { @MainActor in
            // Build a temporary context for the reaction update.
            // AppDelegate wires the shared container; we use it here.
            if let container = try? ModelContainer.makePulseContainer() {
                let ctx = ModelContext(container)
                self.handleAction(actionIdentifier, deliveryID: deliveryID, context: ctx)
            }
            completionHandler()
        }
    }
}

// MARK: - BibleVerse excerpt convenience

private extension String {
    func excerpt(maxChars: Int = 60) -> String {
        if count <= maxChars { return self }
        let truncated = prefix(maxChars)
        let lastSpace = truncated.lastIndex(of: " ") ?? truncated.endIndex
        return String(truncated[..<lastSpace]) + "..."
    }
}
