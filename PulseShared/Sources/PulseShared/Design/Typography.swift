import SwiftUI

public enum PSFont {
    // Serif — verse text (spiritual, dignified)
    public static func verseText(size: CGFloat) -> Font {
        .system(size: size, design: .serif)
    }

    // Rounded Sans — UI labels (warm, approachable)
    public static func label(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // Monospaced — metrics/numbers (precise, clinical)
    public static func metric(size: CGFloat) -> Font {
        .system(size: size, design: .monospaced).monospacedDigit()
    }
}
