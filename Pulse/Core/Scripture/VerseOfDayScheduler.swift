import Foundation
import UserNotifications
import SwiftData
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "VerseOfDayScheduler")

// MARK: - VerseOfDayScheduler

/// Manages the Verse of the Day feature: a repeating 8 AM local notification and a
/// SwiftData-persisted `VerseDelivery` with `deliveryMethod == "votd"`.
///
/// - Schedules / removes the daily `UNCalendarNotificationTrigger` based on
///   `UserPreferences.includeVerseOfDay`.
/// - Fetches the YouVersion VOTD (live or offline-fallback) exactly once per
///   calendar day and stores it as a `VerseDelivery` so the Home card can display it.
@Observable
@MainActor
final class VerseOfDayScheduler {

    // MARK: - Constants

    static let notificationIdentifier = "com.joelroy.pulse.votd"
    static let deliveryMethod = "votd"

    // MARK: - Dependencies

    private let cache: VerseCache
    private let client: YouVersionClient?
    private let notifications: NotificationService

    // MARK: - Init

    init(cache: VerseCache, client: YouVersionClient?, notifications: NotificationService) {
        self.cache = cache
        self.client = client
        self.notifications = notifications
    }

    // MARK: - Daily Notification

    /// Schedules (or removes) the repeating 8:00 AM VOTD notification based on
    /// `UserPreferences.includeVerseOfDay`.  Safe to call at launch and on every
    /// settings toggle — idempotent when called repeatedly.
    func scheduleDailyNotification() {
        let prefs = fetchPreferences()
        let includeVOTD = prefs?.includeVerseOfDay ?? true

        let center = UNUserNotificationCenter.current()

        if includeVOTD {
            var components = DateComponents()
            components.hour = 8
            components.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let content = UNMutableNotificationContent()
            content.title = "Verse of the Day"
            content.body = "Your daily scripture is ready \u{2014} tap to read."
            content.sound = .default
            content.categoryIdentifier = "verse_notification"

            let request = UNNotificationRequest(
                identifier: Self.notificationIdentifier,
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error {
                    logger.error("VOTD notification schedule failed: \(error.localizedDescription, privacy: .public)")
                } else {
                    logger.info("VOTD daily notification scheduled at 08:00")
                }
            }
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
            logger.info("VOTD daily notification removed (setting off)")
        }
    }

    // MARK: - Ensure Today's VOTD

    /// Ensures a `VerseDelivery` with `deliveryMethod == "votd"` exists for today.
    ///
    /// - Skips entirely if `includeVerseOfDay` is `false`.
    /// - Skips if a VOTD delivery already exists for the current calendar day.
    /// - Fetches live VOTD when keys are configured and network is available;
    ///   falls back to `FallbackVerseProvider.emergencyVerse(for: .morningAwakening)`.
    func ensureTodaysVOTD() async {
        // Check preference
        let prefs = fetchPreferences()
        guard prefs?.includeVerseOfDay ?? true else {
            logger.debug("VOTD skipped \u{2014} setting off")
            return
        }

        // Decide "which day" exactly once, from a single captured instant, and
        // thread it through both the fetch and the persisted timestamp so the
        // day can't shift between reads (recompute at midnight / timezone edge).
        let now = Date()
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 1

        // Skip if already delivered today
        if todaysVOTD() != nil {
            logger.debug("VOTD already delivered today \u{2014} skipping")
            return
        }

        // Preferred translation
        let bibleID = prefs?.preferredBibleID ?? DefaultBible.id
        let abbreviation = prefs?.preferredBibleAbbreviation ?? DefaultBible.abbreviation

        // Fetch verse with offline-chain fallback for the decided day
        let (verse, isOffline) = await fetchVOTDWithFallback(
            bibleID: bibleID, abbreviation: abbreviation, dayOfYear: dayOfYear)

        // Persist delivery, stamped with the same instant used to pick the day
        let state = BiometricState.morningAwakening
        let delivery = VerseDelivery(
            verseID: verse.id,
            verseReference: verse.reference,
            verseText: verse.text,
            translationAbbreviation: verse.translationAbbreviation,
            verseTheme: "verse_of_the_day",
            themeDisplayName: "Verse of the Day",
            biometricStateRaw: state.rawValue,
            stateConfidence: 1.0,
            stateBodyText: state.bodyInterpretation,
            deliveredAt: now,
            deliveryMethod: Self.deliveryMethod,
            isOfflineFallback: isOffline
        )

        delivery.emotionRaw = BiometricState.morningAwakening.defaultEmotion.rawValue
        cache.saveDelivery(delivery)
        cache.store(verse)

        // Track analytics
        Analytics.shared.track(.verseDelivered(method: "votd"))
        if isOffline {
            Analytics.shared.track(.apiFallbackUsed)
        }

        logger.info("VOTD persisted: \(verse.reference, privacy: .public) offline=\(isOffline, privacy: .public)")
    }

    // MARK: - Today's VOTD Query

    /// Returns today's VOTD `VerseDelivery`, or nil if none has been persisted yet.
    func todaysVOTD() -> VerseDelivery? {
        cache.todaysDelivery(deliveryMethod: Self.deliveryMethod)
    }

    // MARK: - Private Helpers

    /// Attempts a live YouVersion VOTD fetch for the given day-of-year; falls back
    /// to the emergency verse on any error. Returns `(verse, isOfflineFallback)`.
    private func fetchVOTDWithFallback(bibleID: Int, abbreviation: String, dayOfYear: Int) async -> (BibleVerse, Bool) {
        if AppConfig.isConfigured && !AppConfig.forceOffline, let client {
            do {
                let verse = try await client.fetchVerseOfTheDay(
                    bibleID: bibleID, abbreviation: abbreviation, day: dayOfYear)
                return (verse, false)
            } catch {
                logger.warning("VOTD live fetch failed (\(error.localizedDescription, privacy: .public)) \u{2014} using fallback")
            }
        }

        // Guaranteed non-nil fallback
        let fallback = FallbackVerseProvider().emergencyVerse(for: .morningAwakening)
        return (fallback, true)
    }

    /// Fetches the single `UserPreferences` row from SwiftData, or nil if none exists.
    private func fetchPreferences() -> UserPreferences? {
        let descriptor = FetchDescriptor<UserPreferences>(
            predicate: #Predicate { $0.id == 1 }
        )
        return try? cache.modelContext.fetch(descriptor).first
    }
}
