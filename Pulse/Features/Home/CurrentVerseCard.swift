import SwiftUI
import PulseShared

// MARK: - CurrentVerseCard

/// The hero verse card on HomeView. Uses PSCard(.verse) for the spec's
/// cream/paper aesthetic with dark text on cream background.
struct CurrentVerseCard: View {
    let delivery: VerseDelivery
    let onLove: () -> Void
    let onSave: () -> Void
    let onShare: () -> Void
    let onReadMore: () -> Void

    private var state: BiometricState {
        delivery.biometricState ?? .peacefulSteady
    }

    var body: some View {
        PSCard(style: .verse) {
            VStack(alignment: .leading, spacing: PSSpacing.md) {

                // Verse text — dark navy text on cream background
                VerseTextView(
                    text: delivery.verseText,
                    reference: delivery.verseReference,
                    translation: delivery.translationAbbreviation,
                    fontSize: 20,
                    textColor: .psDeepNavy,
                    accentColor: .psAccent
                )

                // Offline badge
                if delivery.isOfflineFallback {
                    OfflineBadge()
                }

                Divider()
                    .overlay(Color.psDeepNavy.opacity(0.15))

                // Action row
                HStack(spacing: 0) {
                    ActionButton(icon: "heart", label: "Love", isActive: delivery.userReaction == .loved, tint: Color.psDeepNavy, action: onLove)
                    ActionButton(icon: "bookmark", label: "Save", isActive: delivery.userReaction == .saved, tint: Color.psDeepNavy, action: onSave)
                    ActionButton(icon: "square.and.arrow.up", label: "Share", isActive: false, tint: Color.psDeepNavy, action: onShare)
                    ActionButton(icon: "book.closed", label: "Read More", isActive: false, tint: Color.psDeepNavy, action: onReadMore)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onReadMore)
        .accessibilityElement(children: .contain)
        .accessibilityHint("Tap to open verse detail")
    }
}

// MARK: - Empty State Verse Card

struct EmptyVerseCard: View {
    let isLoading: Bool
    let onDeliver: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        if isLoading {
            // Skeleton: redacted placeholder verse card with psPulse opacity animation
            PSCard(style: .verse) {
                VerseTextView(
                    text: "Commit your way to the Lord; trust in him and he will act on your behalf.",
                    reference: "Psalm 37:5",
                    translation: "ESV",
                    textColor: .psDeepNavy,
                    accentColor: .psAccent
                )
            }
            .redacted(reason: .placeholder)
            .opacity(reduceMotion ? 1 : pulseOpacity)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.psPulse) {
                    pulseOpacity = 0.4
                }
            }
            .accessibilityLabel("Loading verse…")
        } else {
            PSCard(style: .standard) {
                VStack(spacing: PSSpacing.md) {
                    Text("Your verse is on its way")
                        .font(PSFont.verseText(size: 20))
                        .foregroundStyle(Color.psWhite.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, PSSpacing.md)

                    PSButton(title: "Get my verse", style: .primary, action: onDeliver)
                }
            }
        }
    }
}

// MARK: - Helpers

private struct ActionButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isActive ? icon + ".fill" : icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isActive ? Color.psAccent : tint.opacity(0.7))
                Text(label)
                    .font(PSFont.label(size: 10))
                    .foregroundStyle(isActive ? Color.psAccent : tint.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct OfflineBadge: View {
    var textColor: Color = Color.psDeepNavy

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 10))
            Text("Offline verse")
                .font(PSFont.label(size: 11))
        }
        .foregroundStyle(textColor.opacity(0.6))
        .padding(.horizontal, PSSpacing.sm)
        .padding(.vertical, PSSpacing.xs)
        .background(textColor.opacity(0.08))
        .clipShape(Capsule())
    }
}
