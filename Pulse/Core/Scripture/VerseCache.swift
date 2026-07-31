import Foundation
import SwiftData
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "VerseCache")

// MARK: - VerseCache

/// SwiftData-backed cache for Bible verses and delivery history.
/// Enforces LRU eviction beyond 500 entries (by lastAccessedAt).
@MainActor
final class VerseCache {

    private let context: ModelContext

    private static let maxCachedVerses = 500

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Verse Lookup

    /// Returns a cached `BibleVerse` for the given reference and translation abbreviation,
    /// updating `accessCount` and `lastAccessedAt` on a hit.
    func verse(reference: String, translationAbbreviation: String) -> BibleVerse? {
        let key = "\(reference)_\(translationAbbreviation)"
        let descriptor = FetchDescriptor<CachedVerse>(
            predicate: #Predicate { $0.cacheKey == key }
        )
        guard let cached = try? context.fetch(descriptor).first else {
            return nil
        }
        cached.accessCount += 1
        cached.lastAccessedAt = .now
        try? context.save()
        logger.debug("Cache HIT: \(reference, privacy: .public) (\(translationAbbreviation, privacy: .public))")
        return BibleVerse(
            id: cached.verseID,
            reference: cached.reference,
            text: cached.text,
            translationAbbreviation: cached.translationAbbreviation,
            copyright: cached.copyright,
            chapterURLString: cached.chapterURLString
        )
    }

    // MARK: - Verse Storage

    /// Stores a `BibleVerse` in the cache. Runs LRU eviction if the cache exceeds 500 entries.
    func store(_ verse: BibleVerse) {
        let key = "\(verse.reference)_\(verse.translationAbbreviation)"
        // Avoid duplicates
        let descriptor = FetchDescriptor<CachedVerse>(
            predicate: #Predicate { $0.cacheKey == key }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.accessCount += 1
            existing.lastAccessedAt = .now
            try? context.save()
            return
        }
        let cached = CachedVerse(verse: verse)
        context.insert(cached)
        try? context.save()
        logger.debug("Cached verse: \(verse.reference, privacy: .public)")
        evictIfNeeded()
    }

    // MARK: - Delivery Persistence

    /// Persists a `VerseDelivery` to the SwiftData store.
    func saveDelivery(_ delivery: VerseDelivery) {
        context.insert(delivery)
        try? context.save()
        logger.info("Saved delivery: \(delivery.verseReference, privacy: .public) [\(delivery.id, privacy: .public)]")
    }

    // MARK: - Delivery Queries

    /// Returns the count of deliveries made today (local calendar day).
    func todayDeliveryCount() -> Int {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<VerseDelivery>(
            predicate: #Predicate { $0.deliveredAt >= startOfDay }
        )
        return (try? context.fetch(descriptor).count) ?? 0
    }

    /// Returns the most recent `VerseDelivery`, or nil if none exists.
    func lastDelivery() -> VerseDelivery? {
        var descriptor = FetchDescriptor<VerseDelivery>(
            sortBy: [SortDescriptor(\.deliveredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Returns the most recent `VerseDelivery` for a specific `BiometricState`, or nil.
    func lastDelivery(for state: BiometricState) -> VerseDelivery? {
        let rawValue = state.rawValue
        var descriptor = FetchDescriptor<VerseDelivery>(
            predicate: #Predicate { $0.biometricStateRaw == rawValue },
            sortBy: [SortDescriptor(\.deliveredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Returns up to `limit` recently-delivered verse references (most recent first).
    func recentReferences(limit: Int) -> [String] {
        var descriptor = FetchDescriptor<VerseDelivery>(
            sortBy: [SortDescriptor(\.deliveredAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let deliveries = (try? context.fetch(descriptor)) ?? []
        return deliveries.map(\.verseReference)
    }

    // MARK: - LRU Eviction

    private func evictIfNeeded() {
        let descriptor = FetchDescriptor<CachedVerse>(
            sortBy: [SortDescriptor(\.lastAccessedAt, order: .forward)]
        )
        guard let all = try? context.fetch(descriptor), all.count > Self.maxCachedVerses else {
            return
        }
        let excess = all.count - Self.maxCachedVerses
        for i in 0..<excess {
            context.delete(all[i])
        }
        try? context.save()
        logger.debug("LRU eviction: removed \(excess) verse(s) from cache")
    }
}
