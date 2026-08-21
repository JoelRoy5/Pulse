import Foundation

// MARK: - Verse Selection Context

/// Privacy-safe context sent to Gloo AI. Contains ONLY state/time/behavioral fields.
/// No raw health numbers (heart rate, HRV, bpm, etc.) are included.
public struct VerseSelectionContext: Sendable {
    public var state: BiometricState
    /// The user-facing emotion this delivery represents. The on-device library
    /// keys its verse pools on this. Defaults to `state.defaultEmotion`.
    public var emotion: Emotion
    public var timeOfDay: TimeOfDay
    public var confidence: Double
    public var recentStates: [BiometricState]
    /// Abbreviation string of the preferred Bible translation (e.g. "BSB", "ESV").
    /// Defaults to DefaultBible.abbreviation ("BSB"), which is confirmed accessible
    /// via the YouVersion app key. Stored as a plain String rather than BibleTranslationID
    /// to avoid implying that numeric IDs here are suitable for API fetching.
    public var translationAbbreviation: String
    public var preferredThemes: [String]
    public var avoidRepeats: [String]

    public init(
        state: BiometricState,
        timeOfDay: TimeOfDay,
        confidence: Double,
        recentStates: [BiometricState] = [],
        translationAbbreviation: String = DefaultBible.abbreviation,
        preferredThemes: [String] = [],
        avoidRepeats: [String] = [],
        emotion: Emotion? = nil
    ) {
        self.state = state
        self.emotion = emotion ?? state.defaultEmotion
        self.timeOfDay = timeOfDay
        self.confidence = confidence
        self.recentStates = recentStates
        self.translationAbbreviation = translationAbbreviation
        self.preferredThemes = preferredThemes
        self.avoidRepeats = avoidRepeats
    }
}

// MARK: - Verse Selection

public struct VerseSelection: Sendable {
    public let reference: String         // e.g. "Matthew 11:28" or "Matthew 11:28-30"
    public let theme: String             // e.g. "rest_renewal"
    public let themeDisplayName: String  // e.g. "Rest & Renewal"
    public let rationale: String?
    public let alternates: [String]
    public let isFallback: Bool

    public init(
        reference: String,
        theme: String,
        themeDisplayName: String,
        rationale: String?,
        alternates: [String],
        isFallback: Bool
    ) {
        self.reference = reference
        self.theme = theme
        self.themeDisplayName = themeDisplayName
        self.rationale = rationale
        self.alternates = alternates
        self.isFallback = isFallback
    }
}

// MARK: - Protocols

public protocol VerseSelecting: Sendable {
    func selectVerse(for context: VerseSelectionContext) async throws -> VerseSelection
}

public protocol VerseFetching: Sendable {
    /// Fetches a verse using numeric YouVersion bible ID and abbreviation.
    /// The abbreviation is passed through into BibleVerse.translationAbbreviation
    /// since the passage response does not include it.
    func fetchVerse(reference: String, bibleID: Int, abbreviation: String) async throws -> BibleVerse
}

// MARK: - API Errors

public enum ScriptureAPIError: Error, Equatable {
    case notConfigured
    case authFailed
    case requestFailed(status: Int)
    case decodingFailed
    case timedOut
}

// MARK: - Default Bible

/// Default Bible version: Berean Standard Bible (BSB, ID 3034).
/// Confirmed available for this App Key via GET /v1/bibles?language_ranges[]=eng.
public enum DefaultBible {
    public static let id = 3034
    public static let abbreviation = "BSB"
    public static let title = "Berean Standard Bible"
}

// MARK: - Bible Version

/// A Bible version returned by YouVersion's GET /v1/bibles?language_ranges[]=eng.
/// Decoded tolerantly: title comes from "name" or "local_title" or "title" field.
public struct BibleVersion: Codable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let abbreviation: String
    public let title: String

    public init(id: Int, abbreviation: String, title: String) {
        self.id = id
        self.abbreviation = abbreviation
        self.title = title
    }
}

// MARK: - USFM Conversion

/// Converts human-readable Bible references to USFM format for the YouVersion API.
///
/// Examples:
///   "Matthew 11:28"    → "MAT.11.28"
///   "Matthew 11:28-30" → "MAT.11.28-30"  (short range, chapter prefix omitted on end)
///   "Psalm 34:18"      → "PSA.34.18"
///   "1 John 4:19"      → "1JN.4.19"
///
/// The YouVersion API path uses the form BOOK.C.VS-VE for same-chapter ranges.
public enum USFM {
    // 66-book abbreviation table mapping common English names to USFM codes
    private static let bookTable: [String: String] = [
        // Old Testament
        "genesis": "GEN", "exodus": "EXO", "leviticus": "LEV", "numbers": "NUM",
        "deuteronomy": "DEU", "joshua": "JOS", "judges": "JDG", "ruth": "RUT",
        "1 samuel": "1SA", "2 samuel": "2SA", "1 kings": "1KI", "2 kings": "2KI",
        "1 chronicles": "1CH", "2 chronicles": "2CH", "ezra": "EZR", "nehemiah": "NEH",
        "esther": "EST", "job": "JOB", "psalm": "PSA", "psalms": "PSA",
        "proverbs": "PRO", "ecclesiastes": "ECC", "song of solomon": "SNG",
        "song of songs": "SNG", "isaiah": "ISA", "jeremiah": "JER",
        "lamentations": "LAM", "ezekiel": "EZK", "daniel": "DAN", "hosea": "HOS",
        "joel": "JOL", "amos": "AMO", "obadiah": "OBA", "jonah": "JON",
        "micah": "MIC", "nahum": "NAM", "habakkuk": "HAB", "zephaniah": "ZEP",
        "haggai": "HAG", "zechariah": "ZEC", "malachi": "MAL",
        // New Testament
        "matthew": "MAT", "mark": "MRK", "luke": "LUK", "john": "JHN",
        "acts": "ACT", "romans": "ROM", "1 corinthians": "1CO", "2 corinthians": "2CO",
        "galatians": "GAL", "ephesians": "EPH", "philippians": "PHP", "colossians": "COL",
        "1 thessalonians": "1TH", "2 thessalonians": "2TH", "1 timothy": "1TI",
        "2 timothy": "2TI", "titus": "TIT", "philemon": "PHM", "hebrews": "HEB",
        "james": "JAS", "1 peter": "1PE", "2 peter": "2PE", "1 john": "1JN",
        "2 john": "2JN", "3 john": "3JN", "jude": "JUD", "revelation": "REV"
    ]

    /// Converts a human-readable reference to USFM path format for the YouVersion API.
    ///
    /// Single verse: "Matthew 11:28"    → "MAT.11.28"
    /// Range (same chapter): "Matthew 11:28-30" → "MAT.11.28-30"
    ///
    /// Returns nil if the book name is unrecognized.
    public static func usfm(for reference: String) -> String? {
        // Split on first colon to get book+chapter and verse(s)
        let colonParts = reference.split(separator: ":", maxSplits: 1)
        guard colonParts.count == 2 else { return nil }

        let bookChapterPart = String(colonParts[0])
        let versePart = String(colonParts[1]).trimmingCharacters(in: .whitespaces)

        // Split book+chapter: last word-segment is chapter number
        // Handle "1 Samuel 3" → book="1 samuel", chapter="3"
        // Handle "Matthew 11" → book="matthew", chapter="11"
        let trimmed = bookChapterPart.trimmingCharacters(in: .whitespaces)
        guard let lastSpaceIdx = trimmed.lastIndex(of: " ") else { return nil }

        let bookName = String(trimmed[..<lastSpaceIdx]).lowercased()
        let chapterStr = String(trimmed[trimmed.index(after: lastSpaceIdx)...])

        guard let usfmBook = bookTable[bookName],
              let _ = Int(chapterStr) else { return nil }

        // verse part: either "28" or "28-30"
        if versePart.contains("-") {
            let vsParts = versePart.split(separator: "-", maxSplits: 1)
            guard vsParts.count == 2,
                  let _ = Int(vsParts[0]),
                  let _ = Int(vsParts[1]) else { return nil }
            // Short range format: BOOK.C.VS-VE (chapter prefix omitted on end)
            return "\(usfmBook).\(chapterStr).\(vsParts[0])-\(vsParts[1])"
        } else {
            guard let _ = Int(versePart) else { return nil }
            return "\(usfmBook).\(chapterStr).\(versePart)"
        }
    }
}
