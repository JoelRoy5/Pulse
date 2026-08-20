import Foundation
import Observation
import SwiftData
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "HistoryViewModel")

// MARK: - HistoryFilter

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all    = "All"
    case loved  = "Loved"
    case saved  = "Saved"

    var id: String { rawValue }
}

// MARK: - HistorySection

enum HistorySection: String, CaseIterable {
    case today     = "Today"
    case yesterday = "Yesterday"
    case thisWeek  = "This Week"
    case earlier   = "Earlier"
}

// MARK: - HistoryViewModel

@Observable
@MainActor
final class HistoryViewModel {

    // MARK: - State

    var filter: HistoryFilter = .all
    var emotionFilter: Emotion? = nil

    // MARK: - Context

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Filtering

    func filtered(_ deliveries: [VerseDelivery]) -> [VerseDelivery] {
        deliveries.filter { delivery in
            // Reaction filter
            let passesReaction: Bool
            switch filter {
            case .all:
                passesReaction = true
            case .loved:
                passesReaction = delivery.isLoved
            case .saved:
                passesReaction = delivery.isSaved
            }

            // Emotion filter
            let passesState: Bool
            if let emotionFilter {
                passesState = delivery.emotion == emotionFilter
            } else {
                passesState = true
            }

            return passesReaction && passesState
        }
    }

    func sections(from deliveries: [VerseDelivery]) -> [(section: HistorySection, items: [VerseDelivery])] {
        let calendar = Calendar.current
        let now = Date.now

        var today:     [VerseDelivery] = []
        var yesterday: [VerseDelivery] = []
        var thisWeek:  [VerseDelivery] = []
        var earlier:   [VerseDelivery] = []

        for delivery in deliveries {
            if calendar.isDateInToday(delivery.deliveredAt) {
                today.append(delivery)
            } else if calendar.isDateInYesterday(delivery.deliveredAt) {
                yesterday.append(delivery)
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                      delivery.deliveredAt >= weekAgo {
                thisWeek.append(delivery)
            } else {
                earlier.append(delivery)
            }
        }

        var result: [(section: HistorySection, items: [VerseDelivery])] = []
        if !today.isEmpty     { result.append((.today,     today))     }
        if !yesterday.isEmpty { result.append((.yesterday, yesterday)) }
        if !thisWeek.isEmpty  { result.append((.thisWeek,  thisWeek))  }
        if !earlier.isEmpty   { result.append((.earlier,   earlier))   }
        return result
    }

    // MARK: - React

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
        default:
            delivery.userReaction = reaction
            delivery.engagedAt = delivery.engagedAt ?? .now
        }
        do {
            try context.save()
            logger.info("Persisted reaction \(reaction.rawValue, privacy: .public) for \(delivery.verseReference, privacy: .public)")
        } catch {
            logger.error("Failed to save reaction: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Mark Shared

    func markShared(_ delivery: VerseDelivery) {
        // Note: sharedAt is set when the share sheet is presented (approximation —
        // ShareLink completion is not observable).
        delivery.sharedAt = .now
        delivery.engagedAt = delivery.engagedAt ?? .now
        do {
            try context.save()
        } catch {
            logger.error("Failed to persist sharedAt: \(error.localizedDescription, privacy: .public)")
        }
    }
}
