import SwiftUI
import SwiftData
import PulseShared

// MARK: - VerseDetailSheet

struct VerseDetailSheet: View {
    let delivery: VerseDelivery
    let preferredBibleID: Int
    let onReact: (VerseReaction) -> Void
    var onShare: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var whyExpanded = false

    private var state: BiometricState {
        delivery.biometricState ?? .peacefulSteady
    }

    private var chapterURL: URL {
        HomeViewModel.chapterURL(for: delivery, bibleID: preferredBibleID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PSSpacing.lg) {

                // Drag handle
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.psGrayMuted.opacity(0.5))
                        .frame(width: 36, height: 5)
                    Spacer()
                }
                .padding(.top, PSSpacing.sm)

                // Small state banner
                SmallStateBanner(state: state, confidence: delivery.stateConfidence)

                // Verse text (22pt serif) — cream/paper aesthetic per spec
                PSCard(style: .verse) {
                    VStack(alignment: .leading, spacing: PSSpacing.sm) {
                        VerseTextView(
                            text: delivery.verseText,
                            reference: delivery.verseReference,
                            translation: delivery.translationAbbreviation,
                            fontSize: 22,
                            textColor: .psDeepNavy,
                            accentColor: .psAccent
                        )

                        if delivery.isOfflineFallback {
                            OfflineBadge(textColor: .psDeepNavy)
                        }
                    }
                }

                // Why this verse? — expandable
                WhyThisVerseSection(delivery: delivery, isExpanded: $whyExpanded)

                // Read Full Chapter
                Link(destination: chapterURL) {
                    HStack {
                        Image(systemName: "book.closed.fill")
                        Text("Read Full Chapter")
                            .font(PSFont.label(size: 15, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color.psAccent)
                    .padding(PSSpacing.md)
                    .background(Color.psNavy)
                    .clipShape(RoundedRectangle(cornerRadius: PSRadius.md))
                }
                .accessibilityLabel("Read Full Chapter on Bible.com")

                // Action row
                DetailActionRow(delivery: delivery, onReact: onReact, onShare: onShare)

                // Bottom safe area buffer
                Color.clear.frame(height: PSSpacing.xl)
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
        }
        .background(Color.psDeepNavy.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden) // we draw our own
    }
}

// MARK: - SmallStateBanner

private struct SmallStateBanner: View {
    let state: BiometricState
    let confidence: Double

    var body: some View {
        PSCard(style: .state(state)) {
            HStack {
                StateChip(state: state, showConfidence: true, confidence: confidence)
                Spacer()
            }
        }
    }
}

// MARK: - WhyThisVerseSection

private struct WhyThisVerseSection: View {
    let delivery: VerseDelivery
    @Binding var isExpanded: Bool

    private var explanation: String {
        var parts: [String] = []

        if let hr = delivery.heartRateAtDelivery {
            parts.append("Your heart rate was \(Int(hr)) bpm")
        }
        if let hrv = delivery.hrvAtDelivery {
            parts.append("your HRV was \(Int(hrv)) ms")
        }
        if let sleep = delivery.sleepEfficiencyAtDelivery {
            parts.append("your sleep efficiency was \(Int(sleep * 100))%")
        }

        var base: String
        if parts.isEmpty {
            base = "Pulse selected this verse for your current state."
        } else if parts.count == 1 {
            base = "\(parts[0]). "
        } else {
            let joined = parts.dropLast().joined(separator: ", ") + ", and " + parts.last!
            base = "\(joined.prefix(1).uppercased() + joined.dropFirst()). "
        }

        // Append state context
        base += delivery.stateBodyText

        // Append Gloo rationale if present
        if let rationale = delivery.glooRationale, !rationale.isEmpty,
           !rationale.hasPrefix("Fallback"), !rationale.hasPrefix("Emergency") {
            base += "\n\n\(rationale)"
        }

        return base
    }

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                Text(explanation)
                    .font(PSFont.label(size: 14))
                    .foregroundStyle(Color.psWhite.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, PSSpacing.sm)
            },
            label: {
                Text("Why this verse?")
                    .font(PSFont.label(size: 15, weight: .semibold))
                    .foregroundStyle(Color.psAccentLight)
            }
        )
        .padding(PSSpacing.md)
        .background(Color.psNavy)
        .clipShape(RoundedRectangle(cornerRadius: PSRadius.md))
        .tint(Color.psAccent)
    }
}

// MARK: - DetailActionRow

private struct DetailActionRow: View {
    let delivery: VerseDelivery
    let onReact: (VerseReaction) -> Void
    var onShare: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: PSSpacing.sm) {
            // Love
            DetailActionButton(
                icon: delivery.userReaction == .loved ? "heart.fill" : "heart",
                label: "Love",
                tint: delivery.userReaction == .loved ? .red : Color.psWhite.opacity(0.7)
            ) {
                onReact(.loved)
            }

            // Save
            DetailActionButton(
                icon: delivery.userReaction == .saved ? "bookmark.fill" : "bookmark",
                label: "Save",
                tint: delivery.userReaction == .saved ? Color.psAccent : Color.psWhite.opacity(0.7)
            ) {
                onReact(.saved)
            }

            // Share — presents ShareCardView when onShare is provided; falls back to plain ShareLink
            if let onShare {
                DetailActionButton(
                    icon: "square.and.arrow.up",
                    label: "Share",
                    tint: Color.psWhite.opacity(0.7),
                    action: onShare
                )
            } else {
                let shareText = "\"\(delivery.verseText)\" — \(delivery.verseReference) (\(delivery.translationAbbreviation))"
                ShareLink(item: shareText) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.psWhite.opacity(0.7))
                        Text("Share")
                            .font(PSFont.label(size: 12))
                            .foregroundStyle(Color.psGrayMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(PSSpacing.md)
        .background(Color.psNavy)
        .clipShape(RoundedRectangle(cornerRadius: PSRadius.md))
    }
}

private struct DetailActionButton: View {
    let icon: String
    let label: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(tint)
                Text(label)
                    .font(PSFont.label(size: 12))
                    .foregroundStyle(Color.psGrayMuted)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
