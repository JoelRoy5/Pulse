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
        delivery.userReaction = reaction
        switch reaction {
        case .loved:
            delivery.engagedAt = .now
        case .saved:
            delivery.engagedAt = .now
            delivery.savedAt = .now
        case .shared:
            delivery.engagedAt = .now
            delivery.sharedAt = .now
        case .dismissed:
            // Dismissed: record engagement but do not overwrite a more positive timestamp
            if delivery.engagedAt == nil {
                delivery.engagedAt = .now
            }
        case .prayed:
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
