import SwiftUI
import WidgetKit
import PulseShared

// MARK: - String Excerpt Helper

extension String {
    /// Returns the first `maxChars` characters trimmed at a word boundary, appending "..."
    func verseExcerpt(maxChars: Int = 50) -> String {
        guard self.count > maxChars else { return self }
        let prefix = String(self.prefix(maxChars))
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace]) + "..."
        }
        return prefix + "..."
    }
}

// MARK: - accessoryRectangular

struct RectangularComplicationView: View {
    let verse: WatchMessage.VerseDeliveryPayload?

    private var biometricState: BiometricState? {
        verse.flatMap { BiometricState(rawValue: $0.stateRaw) }
    }

    var body: some View {
        if let verse {
            VStack(alignment: .leading, spacing: 2) {
                // State line: emoji + abbreviation
                HStack(spacing: 4) {
                    Text(verse.stateEmoji)
                        .font(.system(size: 10))
                    Text((biometricState?.abbreviation ?? verse.stateDisplayName).uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }

                // 2-line serif excerpt ~50 chars
                Text(verse.verseText.verseExcerpt(maxChars: 50))
                    .font(.system(size: 12, design: .serif))
                    .lineLimit(2)
                    .foregroundStyle(.white)

                // Reference
                Text(verse.verseReference)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 4) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 18))
                .foregroundStyle(.white)
            Text("Pulse")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - accessoryCircular

struct CircularComplicationView: View {
    let verse: WatchMessage.VerseDeliveryPayload?

    private var biometricState: BiometricState? {
        verse.flatMap { BiometricState(rawValue: $0.stateRaw) }
    }

    private var stateColor: Color {
        biometricState?.primaryColor ?? Color(hex: verse?.primaryColor ?? "#C9A96E")
    }

    var body: some View {
        if let verse {
            Gauge(value: 0.7, in: 0...1) {
                Text(verse.stateEmoji)
                    .font(.system(size: 14))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(stateColor)
        } else {
            Gauge(value: 0.5, in: 0...1) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(.red)
        }
    }
}

// MARK: - accessoryInline

struct InlineComplicationView: View {
    let verse: WatchMessage.VerseDeliveryPayload?

    var body: some View {
        if let verse {
            Text("\(verse.stateEmoji) \(verse.verseReference)")
        } else {
            Label("Pulse", systemImage: "heart.text.square")
        }
    }
}

// MARK: - accessoryCorner

struct CornerComplicationView: View {
    let verse: WatchMessage.VerseDeliveryPayload?

    private var biometricState: BiometricState? {
        verse.flatMap { BiometricState(rawValue: $0.stateRaw) }
    }

    private var stateColor: Color {
        biometricState?.primaryColor ?? Color(hex: verse?.primaryColor ?? "#C9A96E")
    }

    var body: some View {
        if let verse {
            Gauge(value: 0.7, in: 0...1) {
                Text(verse.stateEmoji)
                    .font(.system(size: 12))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(stateColor)
            .widgetLabel {
                Text(verse.verseReference)
                    .foregroundStyle(stateColor)
            }
        } else {
            Gauge(value: 0.5, in: 0...1) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(.red)
            .widgetLabel {
                Text("Pulse")
            }
        }
    }
}

// MARK: - Xcode Previews (for widget gallery verification)

#if DEBUG
// Shared sample payload for previews
private let sampleVerse = WatchMessage.VerseDeliveryPayload(
    deliveryID: "preview-001",
    verseText: "Come to me, all you who are weary and burdened, and I will give you rest.",
    verseReference: "Matthew 11:28",
    translationAbbreviation: "NIV",
    stateRaw: "exhausted_depleted",
    stateDisplayName: "Weary Soul",
    stateEmoji: "🌙",
    stateBodyText: "Your body is asking for rest.",
    primaryColor: "#6366F1",
    timestamp: Date().timeIntervalSince1970
)

#Preview("Rectangular", as: .accessoryRectangular) {
    PulseComplication()
} timeline: {
    PulseEntry(date: .now, verse: sampleVerse)
    PulseEntry(date: .now, verse: nil)
}

#Preview("Circular", as: .accessoryCircular) {
    PulseComplication()
} timeline: {
    PulseEntry(date: .now, verse: sampleVerse)
    PulseEntry(date: .now, verse: nil)
}

#Preview("Inline", as: .accessoryInline) {
    PulseComplication()
} timeline: {
    PulseEntry(date: .now, verse: sampleVerse)
    PulseEntry(date: .now, verse: nil)
}

#Preview("Corner", as: .accessoryCorner) {
    PulseComplication()
} timeline: {
    PulseEntry(date: .now, verse: sampleVerse)
    PulseEntry(date: .now, verse: nil)
}
#endif
