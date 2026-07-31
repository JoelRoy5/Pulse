import Foundation

public struct FallbackVerseProvider {
    public init() {}

    public func emergencyVerse(for state: BiometricState) -> BibleVerse {
        // Try to decode the bundled JSON
        guard let jsonURL = Bundle.module.url(forResource: "emergency_verses", withExtension: "json") else {
            return hardcodedMatthew1128()
        }

        do {
            let data = try Data(contentsOf: jsonURL)
            let decoder = JSONDecoder()
            let versesDict = try decoder.decode([String: VerseDictEntry].self, from: data)

            guard let verseEntry = versesDict[state.rawValue] else {
                return hardcodedMatthew1128()
            }

            return BibleVerse(
                id: verseEntry.reference,
                reference: verseEntry.reference,
                text: verseEntry.text,
                translationAbbreviation: verseEntry.translation,
                copyright: "NIV. Bundled for offline use.",
                chapterURLString: nil
            )
        } catch {
            return hardcodedMatthew1128()
        }
    }

    public static func fallbackReference(for state: BiometricState) -> String {
        switch state {
        case .energizedPostWorkout:   return "Philippians 4:13"
        case .stressedAnxious:        return "John 14:27"
        case .exhaustedDepleted:      return "Matthew 11:28-30"
        case .deepRestRecovered:      return "Lamentations 3:22-23"
        case .peacefulSteady:         return "Psalm 23:2-3"
        case .morningAwakening:       return "Psalm 118:24"
        case .eveningWindingDown:     return "Psalm 4:8"
        case .activeEngaged:          return "Colossians 3:23-24"
        case .sadWithdrawn:           return "Psalm 34:18"
        case .sickUnwell:             return "Psalm 103:2-3"
        case .peakPerformance:        return "Isaiah 40:31"
        case .spiritualAlert:         return "Isaiah 26:3"
        }
    }

    private func hardcodedMatthew1128() -> BibleVerse {
        BibleVerse(
            id: "Matthew 11:28",
            reference: "Matthew 11:28",
            text: "Come to me, all you who are weary and burdened, and I will give you rest.",
            translationAbbreviation: "NIV",
            copyright: "NIV. Bundled for offline use.",
            chapterURLString: nil
        )
    }
}

// MARK: - Decodable Helper

private struct VerseDictEntry: Codable {
    let reference: String
    let text: String
    let translation: String
}
