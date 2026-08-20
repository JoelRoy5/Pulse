import Foundation
import Observation
import SwiftData
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "HomeViewModel")

// MARK: - HomeViewModel

@Observable
@MainActor
final class HomeViewModel {

    // MARK: - Dependencies

    private let context: ModelContext

    // MARK: - Init

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - React

    /// Persists a reaction for the given delivery and saves to SwiftData.
    func react(_ reaction: VerseReaction, to delivery: VerseDelivery) {
        switch reaction {
        case .loved:
            // Independent toggle — does not affect Save.
            delivery.lovedAt = delivery.isLoved ? nil : .now
            delivery.engagedAt = .now
            Analytics.shared.track(.verseLoved)
        case .saved:
            // Independent toggle — does not affect Love.
            delivery.savedAt = delivery.isSaved ? nil : .now
            delivery.engagedAt = .now
            Analytics.shared.track(.verseSaved)
        case .shared:
            delivery.userReaction = .shared
            delivery.engagedAt = .now
            delivery.sharedAt = .now
            Analytics.shared.track(.verseShared)
        case .dismissed:
            // Dismissed: record engagement but do not overwrite a more positive timestamp
            if delivery.engagedAt == nil {
                delivery.engagedAt = .now
            }
        case .prayed:
            delivery.userReaction = .prayed
            delivery.engagedAt = .now
        }
        do {
            try context.save()
            logger.info("Persisted reaction \(reaction.rawValue, privacy: .public) for \(delivery.verseReference, privacy: .public)")
        } catch {
            logger.error("Failed to save reaction: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Chapter URL

    /// Best-effort bible.com chapter URL for a delivery.
    static func chapterURL(for delivery: VerseDelivery, bibleID: Int) -> URL {
        // verseID may look like "MAT.11.28" — if it contains dots, use chapter portion
        let vID = delivery.verseID
        if vID.contains(".") {
            let chapterPart = vID.split(separator: ".").prefix(2).joined(separator: ".")
            if let url = URL(string: "https://www.bible.com/bible/\(bibleID)/\(chapterPart)") {
                return url
            }
        }
        // Fallback: search URL with reference
        let encoded = delivery.verseReference.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.bible.com/search/bible?q=\(encoded)")
            ?? URL(string: "https://www.bible.com")!
    }
}
