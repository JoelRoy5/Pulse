import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "ModelContainer")

extension ModelContainer {

    /// Creates the persistent `ModelContainer` backed by the App Group container.
    /// Falls back to an in-memory store if the App Group path cannot be resolved
    /// or the on-disk store fails to initialise — never throws to the caller.
    static func makePulseContainer() throws -> ModelContainer {
        let schema = Schema([VerseDelivery.self, CachedVerse.self, UserPreferences.self])

        // Attempt to use the shared App Group container URL
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.joelroy.pulse"
        ) {
            let storeURL = groupURL.appendingPathComponent("PulseData.store")
            let config = ModelConfiguration(schema: schema, url: storeURL)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                logger.error("Failed to create on-disk ModelContainer at \(storeURL.path, privacy: .public): \(error.localizedDescription, privacy: .public). Falling back to in-memory store.")
            }
        } else {
            logger.warning("App Group container URL unavailable — falling back to in-memory store.")
        }

        // In-memory fallback
        let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [inMemoryConfig])
    }
}
