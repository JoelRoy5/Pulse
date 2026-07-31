public enum VerseReaction: String, Codable, Sendable {
    case loved     = "loved"
    case saved     = "saved"
    case dismissed = "dismissed"
    case prayed    = "prayed"    // user went to prayer view
    case shared    = "shared"

    public var displayName: String {
        switch self {
        case .loved:     return "Loved"
        case .saved:     return "Saved"
        case .dismissed: return "Dismissed"
        case .prayed:    return "Prayed"
        case .shared:    return "Shared"
        }
    }

    public var icon: String {
        switch self {
        case .loved:     return "heart.fill"
        case .saved:     return "bookmark.fill"
        case .dismissed: return "xmark"
        case .prayed:    return "hands.sparkles.fill"
        case .shared:    return "square.and.arrow.up"
        }
    }
}
