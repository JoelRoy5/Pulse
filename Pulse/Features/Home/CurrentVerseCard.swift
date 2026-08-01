import SwiftUI
import PulseShared

// MARK: - CurrentVerseCard

/// The hero verse card on HomeView. Uses PSCard(.state) so the verse text
/// renders white on the state gradient (matching the design doc's dark-on-cream
/// look is not possible with VerseTextView which hard-codes psWhite text; using
/// a state card keeps text legible while staying true to the palette).
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
        PSCard(style: .state(state)) {
            VStack(alignment: .leading, spacing: PSSpacing.md) {

                // Verse text — white on state gradient
                VerseTextView(
                    text: delivery.verseText,
                    reference: delivery.verseReference,
                    translation: delivery.translationAbbreviation,
                    fontSize: 20
                )

                // Offline badge
                if delivery.isOfflineFallback {
                    OfflineBadge()
                }

                Divider()
                    .overlay(Color.white.opacity(0.2))

                // Action row
                HStack(spacing: 0) {
                    ActionButton(icon: "heart", label: "Love", isActive: delivery.userReaction == .loved, action: onLove)
                    ActionButton(icon: "bookmark", label: "Save", isActive: delivery.userReaction == .saved, action: onSave)
                    ActionButton(icon: "square.and.arrow.up", label: "Share", isActive: false, action: onShare)
                    ActionButton(icon: "book.closed", label: "Read More", isActive: false, action: onReadMore)
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
        PSCard(style: .standard) {
            VStack(spacing: PSSpacing.md) {
                if isLoading {
                    // Skeleton placeholder
                    VStack(alignment: .leading, spacing: PSSpacing.sm) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.psGrayMuted.opacity(0.3))
                            .frame(height: 20)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.psGrayMuted.opacity(0.3))
                            .frame(height: 20)
                            .padding(.trailing, 40)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.psGrayMuted.opacity(0.3))
                            .frame(height: 16)
                            .padding(.trailing, 80)
                    }
                    .opacity(reduceMotion ? 1 : pulseOpacity)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.psPulse) {
                            pulseOpacity = 0.4
                        }
                    }
                } else {
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isActive ? icon + ".fill" : icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isActive ? Color.psAccent : .white.opacity(0.8))
                Text(label)
                    .font(PSFont.label(size: 10))
                    .foregroundStyle(isActive ? Color.psAccent : .white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct OfflineBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 10))
            Text("Offline verse")
                .font(PSFont.label(size: 11))
        }
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, PSSpacing.sm)
        .padding(.vertical, PSSpacing.xs)
        .background(.white.opacity(0.1))
        .clipShape(Capsule())
    }
}
