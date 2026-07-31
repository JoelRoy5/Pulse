import SwiftUI

extension Color {
    /// Initialize a Color from a hex string like "#RRGGBB".
    /// Tolerates bad input by falling back to black.
    public init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))

        guard cleaned.count == 6,
              let hexValue = UInt32(cleaned, radix: 16) else {
            // Fallback to black on bad input
            self.init(red: 0, green: 0, blue: 0)
            return
        }

        let r = Double((hexValue >> 16) & 0xFF) / 255.0
        let g = Double((hexValue >> 8) & 0xFF) / 255.0
        let b = Double(hexValue & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    // Primary Brand
    static let psDeepNavy    = Color(hex: "#0A0E1A")  // App background
    static let psNavy        = Color(hex: "#111827")  // Card backgrounds
    static let psAccent      = Color(hex: "#C9A96E")  // Gold — primary interactive
    static let psAccentLight = Color(hex: "#E8C98A")  // Lighter gold for text
    static let psCream       = Color(hex: "#F5F0E8")  // Verse card background
    static let psWhite       = Color(hex: "#FAFAFA")  // Primary text on dark
    static let psGrayMuted   = Color(hex: "#6B7280")  // Secondary text

    // Semantic Colors
    static let psSuccess     = Color(hex: "#34D399")  // Good health metric
    static let psWarning     = Color(hex: "#FBBF24")  // Fair health metric
    static let psAlert       = Color(hex: "#F87171")  // Poor health metric
}
