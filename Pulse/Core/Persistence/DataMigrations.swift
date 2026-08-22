import Foundation
import SwiftData
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "DataMigrations")

// MARK: - DataMigrations

/// One-time, idempotent data backfills run at launch once the container is ready.
///
/// SwiftData handles *additive* schema changes automatically (new optional
/// fields start empty; existing rows are preserved). When data needs to *move*
/// between fields — as opposed to just appearing — add a backfill here. Every
/// backfill MUST be safe to run on every launch (guard with a predicate/flag)
/// so no user data is ever lost across an app update.
enum DataMigrations {

    @MainActor
    static func runOnLaunch(_ context: ModelContext) {
        backfillLovedAt(context)
        backfillEmotionRaw(context)
        enableTemperatureDefault(context)
    }

    /// Love state used to live in the shared `userReactionRaw` field; it now has
    /// its own `lovedAt` timestamp so a verse can be both loved and saved. Copy
    /// the old value forward for rows saved before the change, so users who
    /// update in place keep their loved verses. Idempotent: after the first run
    /// no rows match the predicate.
    @MainActor
    private static func backfillLovedAt(_ context: ModelContext) {
        let descriptor = FetchDescriptor<VerseDelivery>(
            predicate: #Predicate { $0.lovedAt == nil && $0.userReactionRaw == "loved" }
        )
        guard let stale = try? context.fetch(descriptor), !stale.isEmpty else { return }
        for delivery in stale {
            delivery.lovedAt = delivery.engagedAt ?? delivery.deliveredAt
        }
        try? context.save()
        logger.info("Backfilled lovedAt for \(stale.count, privacy: .public) deliveries")
    }

    /// One-time migration: enables wrist body-temperature collection for existing testers
    /// whose persisted `UserPreferences` row was created when the schema defaulted to `false`.
    /// Guard: runs exactly once; a `UserDefaults` flag is set after the first successful run
    /// so the row is never force-overridden again (a user who later disables temperature
    /// is not affected on subsequent launches).
    @MainActor
    private static func enableTemperatureDefault(_ context: ModelContext) {
        let flagKey = "migration.enableTemperatureDefault.v1"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        let prefs = UserPreferences.current(in: context)
        prefs.useBodyTemp = true
        try? context.save()
        UserDefaults.standard.set(true, forKey: flagKey)
        logger.info("Migration enableTemperatureDefault.v1: set useBodyTemp = true")
    }

    /// Backfills `emotionRaw` for deliveries created before the field existed.
    /// For each row where `emotionRaw == nil`, derives the emotion from the stored
    /// `biometricStateRaw` via `BiometricState.defaultEmotion`. Idempotent: after the
    /// first run no rows match the predicate.
    @MainActor
    private static func backfillEmotionRaw(_ context: ModelContext) {
        let descriptor = FetchDescriptor<VerseDelivery>(
            predicate: #Predicate { $0.emotionRaw == nil }
        )
        guard let stale = try? context.fetch(descriptor), !stale.isEmpty else { return }
        for delivery in stale {
            delivery.emotionRaw = delivery.biometricState?.defaultEmotion.rawValue ?? Emotion.steady.rawValue
        }
        try? context.save()
        logger.info("Backfilled emotionRaw for \(stale.count, privacy: .public) deliveries")
    }
}
