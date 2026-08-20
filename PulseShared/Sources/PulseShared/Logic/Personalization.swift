import Foundation

/// Pure, stateless personalization math.
public struct Personalization {

    private init() {}

    /// Computes a mood-bias scalar from a list of user corrections.
    ///
    /// Each correction contributes a signed step:
    /// - `+0.1` when the corrected tone is more positive than the shown tone
    /// - `-0.1` when the corrected tone is more negative than the shown tone
    /// - `0`   when shown and corrected have the same valence
    ///
    /// The signed steps are summed, then clamped to `[-0.3, 0.3]`. Note: when all
    /// corrections agree (e.g. 50 positive-direction corrections), the raw sum can
    /// exceed the clamp bounds — the clamp is what drives the test expectation of
    /// 0.3 for a large uniform batch.
    ///
    /// - Parameter corrections: Pairs of `(shown: MoodTone, corrected: MoodTone)`.
    /// - Returns: A `Double` in `[-0.3, 0.3]`.
    public static func moodBias(fromCorrections corrections: [(shown: MoodTone, corrected: MoodTone)]) -> Double {
        guard !corrections.isEmpty else { return 0 }

        let sum: Double = corrections.reduce(0) { acc, pair in
            let shownRank = rank(pair.shown)
            let corrRank  = rank(pair.corrected)
            if corrRank > shownRank { return acc + 0.1 }
            if corrRank < shownRank { return acc - 0.1 }
            return acc
        }

        return min(0.3, max(-0.3, sum))
    }

    // MARK: - Private helpers

    private static func rank(_ tone: MoodTone) -> Int {
        switch tone {
        case .negative: return 0
        case .neutral:  return 1
        case .positive: return 2
        }
    }
}
