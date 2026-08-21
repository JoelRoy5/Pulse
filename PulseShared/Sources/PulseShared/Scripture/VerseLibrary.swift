import Foundation

/// On-device curated verse library. Maps each user-facing `Emotion` to a vetted
/// pool of verse references (references only — text is fetched via YouVersion in
/// Phase 1). Loaded from the bundled `VerseLibrary.json`.
public struct VerseLibrary: Codable, Sendable {

    public struct Entry: Codable, Sendable {
        public let theme: String            // == Emotion.biometricState.verseTheme
        public let themeDisplayName: String // human-readable label
        public let verses: [String]         // e.g. ["Matthew 11:28-30", ...]

        public init(theme: String, themeDisplayName: String, verses: [String]) {
            self.theme = theme
            self.themeDisplayName = themeDisplayName
            self.verses = verses
        }
    }

    public let version: Int
    public let emotions: [String: Entry]    // keyed by Emotion.rawValue

    public init(version: Int, emotions: [String: Entry]) {
        self.version = version
        self.emotions = emotions
    }

    public subscript(_ emotion: Emotion) -> Entry? {
        emotions[emotion.rawValue]
    }

    // MARK: - Loading

    public enum LoadError: Error {
        case resourceMissing
    }

    /// Decodes the bundled `VerseLibrary.json`. Throws if the resource is missing
    /// or malformed — an integrity test guards against this shipping.
    public static func load(from bundle: Bundle? = nil) throws -> VerseLibrary {
        let bundle = bundle ?? .module
        guard let url = bundle.url(forResource: "VerseLibrary", withExtension: "json") else {
            throw LoadError.resourceMissing
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(VerseLibrary.self, from: data)
    }

    /// The bundled library, decoded once. Traps only on a missing/corrupt bundled
    /// resource (a build error caught by `VerseLibraryTests`), never at runtime.
    public static let bundled: VerseLibrary = {
        do {
            return try load()
        } catch {
            fatalError("VerseLibrary.json failed to load: \(error)")
        }
    }()
}
