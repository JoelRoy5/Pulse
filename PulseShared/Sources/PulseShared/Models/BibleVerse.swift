import Foundation

public struct BibleVerse: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let reference: String
    public let text: String
    public let translationAbbreviation: String
    public let copyright: String
    public let chapterURLString: String?

    public var chapterURL: URL? {
        chapterURLString.flatMap(URL.init(string:))
    }

    public func excerpt(maxChars: Int = 60) -> String {
        if text.count <= maxChars { return text }
        let truncated = text.prefix(maxChars)
        let lastSpace = truncated.lastIndex(of: " ") ?? truncated.endIndex
        return String(truncated[..<lastSpace]) + "..."
    }

    public init(
        id: String,
        reference: String,
        text: String,
        translationAbbreviation: String,
        copyright: String,
        chapterURLString: String?
    ) {
        self.id = id
        self.reference = reference
        self.text = text
        self.translationAbbreviation = translationAbbreviation
        self.copyright = copyright
        self.chapterURLString = chapterURLString
    }
}
