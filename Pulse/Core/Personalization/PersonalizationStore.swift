import Foundation
import SwiftData
import PulseShared

/// Persists user emotion-feedback and derives on-device personalization signals.
///
/// All public methods must be called on the main actor because they operate
/// on the main `ModelContext`.
@MainActor
final class PersonalizationStore {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Writing

    /// Inserts a new `EmotionFeedback` record and saves the context.
    func record(_ feedback: EmotionFeedback) {
        context.insert(feedback)
        try? context.save()
    }

    // MARK: - Reading

    /// Returns a mood-bias scalar derived from all correction records.
    ///
    /// Fetches every `EmotionFeedback` row where `correctedEmotionRaw` is non-nil,
    /// maps each pair of raw strings to `(shown: MoodTone, corrected: MoodTone)` via
    /// `Emotion(rawValue:)?.mood`, and delegates the math to `Personalization.moodBias`.
    func currentMoodBias() -> Double {
        let descriptor = FetchDescriptor<EmotionFeedback>()
        let all = (try? context.fetch(descriptor)) ?? []

        let corrections: [(shown: MoodTone, corrected: MoodTone)] = all.compactMap { row in
            guard
                let correctedRaw = row.correctedEmotionRaw,
                let shownMood    = Emotion(rawValue: row.shownEmotionRaw)?.mood,
                let corrMood     = Emotion(rawValue: correctedRaw)?.mood
            else { return nil }
            return (shown: shownMood, corrected: corrMood)
        }

        return Personalization.moodBias(fromCorrections: corrections)
    }

    /// Returns the deduplicated verse references the user has flagged as not helpful
    /// for a given emotion.
    ///
    /// - Parameter emotion: The shown emotion to filter on.
    /// - Returns: A deduplicated array of `verseReference` strings.
    func downweightedReferences(for emotion: Emotion) -> [String] {
        let emotionRaw = emotion.rawValue
        let descriptor = FetchDescriptor<EmotionFeedback>(
            predicate: #Predicate { row in
                row.wasHelpful == false && row.shownEmotionRaw == emotionRaw
            }
        )
        let results = (try? context.fetch(descriptor)) ?? []

        // Deduplicate while preserving order
        var seen: Set<String> = []
        return results.compactMap { row in
            seen.insert(row.verseReference).inserted ? row.verseReference : nil
        }
    }
}
