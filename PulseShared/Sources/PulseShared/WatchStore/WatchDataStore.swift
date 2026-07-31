import Foundation
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "WatchDataStore")

/// Persists the current verse, delivery history (capped at 20), and health summary
/// to the App Group container so both the watch app and widget extension can read it.
///
/// All I/O is synchronous and Foundation-only (no SwiftUI / WatchKit imports) so this
/// compiles into PulseShared, which is consumed by both targets.
public struct WatchDataStore {

    // MARK: - Constants

    private static let appGroupID = "group.com.joelroy.pulse"
    private static let currentVerseFile = "current_verse.json"
    private static let historyFile = "history.json"
    private static let healthSummaryFile = "health_summary.json"
    private static let historyLimit = 20

    // MARK: - Public Init

    public init() {}

    // MARK: - Container URL

    /// Returns the App Group container URL, falling back to the app's documents
    /// directory when the group is unavailable (e.g. simulator unit tests).
    private var containerURL: URL {
        if let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupID
        ) {
            return url
        }
        logger.warning("App Group container unavailable — using documents directory fallback")
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func fileURL(named name: String) -> URL {
        containerURL.appendingPathComponent(name)
    }

    // MARK: - Encode / Decode Helpers

    private func write<T: Encodable>(_ value: T, to name: String) {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileURL(named: name), options: .atomic)
        } catch {
            logger.error("WatchDataStore write(\(name)) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func read<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let url = fileURL(named: name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.error("WatchDataStore read(\(name)) failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Current Verse

    public func save(current verse: WatchMessage.VerseDeliveryPayload) {
        write(verse, to: Self.currentVerseFile)
        logger.debug("WatchDataStore: saved current verse \(verse.deliveryID, privacy: .public)")
    }

    public func loadCurrent() -> WatchMessage.VerseDeliveryPayload? {
        read(WatchMessage.VerseDeliveryPayload.self, from: Self.currentVerseFile)
    }

    // MARK: - History

    public func appendHistory(_ verse: WatchMessage.VerseDeliveryPayload) {
        var history = loadHistory()
        // Avoid duplicates
        history.removeAll { $0.deliveryID == verse.deliveryID }
        history.insert(verse, at: 0)
        if history.count > Self.historyLimit {
            history = Array(history.prefix(Self.historyLimit))
        }
        write(history, to: Self.historyFile)
    }

    public func loadHistory() -> [WatchMessage.VerseDeliveryPayload] {
        read([WatchMessage.VerseDeliveryPayload].self, from: Self.historyFile) ?? []
    }

    // MARK: - Health Summary

    public func save(summary: WatchMessage.HealthSummaryPayload) {
        write(summary, to: Self.healthSummaryFile)
    }

    public func loadSummary() -> WatchMessage.HealthSummaryPayload? {
        read(WatchMessage.HealthSummaryPayload.self, from: Self.healthSummaryFile)
    }
}
