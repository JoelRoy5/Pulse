import SwiftUI
import PulseShared

// MARK: - VerseOfDayCard

/// Home card that shows today's Verse of the Day.
///
/// Uses the `.morningAwakening` gradient and a sunburst label to distinguish
/// it from the biometric-driven verse card.  Tapping opens the verse detail sheet.
struct VerseOfDayCard: View {
    let delivery: VerseDelivery
    let onTap: () -> Void

    private let state = BiometricState.morningAwakening

    // Verse excerpt length (characters) shown in the card
    private static let excerptLength = 120

    private var excerptText: String {
        let text = delivery.verseText
        guard text.count > Self.excerptLength else { return text }
        let truncated = text.prefix(Self.excerptLength)
        let lastSpace = truncated.lastIndex(of: " ") ?? truncated.endIndex
        return String(truncated[..<lastSpace]) + "\u{2026}"
    }

    var body: some View {
        Button(action: onTap) {
            PSCard(style: .state(state)) {
                VStack(alignment: .leading, spacing: PSSpacing.sm) {

                    // Label row
                    HStack(spacing: PSSpacing.xs) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("Verse of the Day")
                            .font(PSFont.label(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .kerning(0.5)
                        Spacer()
                        if delivery.isOfflineFallback {
                            OfflineBadge(textColor: .white)
                        }
                    }

                    // Verse excerpt
                    Text("\u{201C}\(excerptText)\u{201D}")
                        .font(PSFont.verseText(size: 17))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    // Reference + translation
                    HStack {
                        Text("\u{2014} \(delivery.verseReference)")
                            .font(PSFont.label(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                        Text(delivery.translationAbbreviation)
                            .font(PSFont.label(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    // Read more hint
                    HStack {
                        Spacer()
                        Text("Tap to read in full")
                            .font(PSFont.label(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Verse of the Day: \(delivery.verseText). \(delivery.verseReference)")
        .accessibilityHint("Tap to open full verse")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.psDeepNavy.ignoresSafeArea()

        ScrollView {
            VStack(spacing: PSSpacing.md) {
                VerseOfDayCard(
                    delivery: previewVOTDDelivery(),
                    onTap: {}
                )

                VerseOfDayCard(
                    delivery: previewVOTDDelivery(offline: true),
                    onTap: {}
                )
            }
            .padding(PSSpacing.screenHorizontal)
        }
    }
}

private func previewVOTDDelivery(offline: Bool = false) -> VerseDelivery {
    VerseDelivery(
        verseID: "PSA.118.24",
        verseReference: "Psalm 118:24",
        verseText: "This is the day the Lord has made; let us rejoice and be glad in it.",
        translationAbbreviation: "BSB",
        verseTheme: "verse_of_the_day",
        themeDisplayName: "Verse of the Day",
        biometricStateRaw: BiometricState.morningAwakening.rawValue,
        stateConfidence: 1.0,
        stateBodyText: BiometricState.morningAwakening.bodyInterpretation,
        deliveryMethod: "votd",
        isOfflineFallback: offline
    )
}
