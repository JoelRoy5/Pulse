public enum BibleTranslationID: Int, Codable, CaseIterable, Sendable {
    case NIV  = 111
    case ESV  = 59
    case NLT  = 116
    case KJV  = 1
    case CSB  = 1713
    case NASB = 2016
    case MSG  = 97
    case AMP  = 1588
    case NKJV = 114
    case NCV  = 105

    public var abbreviation: String {
        switch self {
        case .NIV: return "NIV"
        case .ESV: return "ESV"
        case .NLT: return "NLT"
        case .KJV: return "KJV"
        case .CSB: return "CSB"
        case .NASB: return "NASB"
        case .MSG: return "MSG"
        case .AMP: return "AMP"
        case .NKJV: return "NKJV"
        case .NCV: return "NCV"
        }
    }

    public var fullName: String {
        switch self {
        case .NIV:  return "New International Version"
        case .ESV:  return "English Standard Version"
        case .NLT:  return "New Living Translation"
        case .KJV:  return "King James Version"
        case .CSB:  return "Christian Standard Bible"
        case .NASB: return "New American Standard Bible 2020"
        case .MSG:  return "The Message"
        case .AMP:  return "Amplified Bible"
        case .NKJV: return "New King James Version"
        case .NCV:  return "New Century Version"
        }
    }

    public var previewVerse: String {
        // John 3:16 in each translation — used in TranslationPickerView preview
        switch self {
        case .NIV:  return "For God so loved the world that he gave his one and only Son..."
        case .ESV:  return "For God so loved the world, that he gave his only Son..."
        case .NLT:  return "For this is how God loved the world: He gave his one and only Son..."
        case .KJV:  return "For God so loved the world, that he gave his only begotten Son..."
        case .CSB:  return "For God loved the world in this way: He gave his one and only Son..."
        case .NASB: return "For God so loved the world, that He gave His only Son..."
        case .MSG:  return "This is how much God loved the world: He gave his Son, his one and only Son..."
        case .AMP:  return "For God so [greatly] loved and dearly prized the world..."
        case .NKJV: return "For God so loved the world that He gave His only begotten Son..."
        case .NCV:  return "God loved the world so much that he gave his one and only Son..."
        }
    }
}
