import SwiftUI
import SwiftData
import PulseShared

// MARK: - Feedback Answer Types

private enum FitAnswer { case yes, notQuite }
private enum HelpfulAnswer { case yes, no }

// MARK: - VerseDetailSheet

struct VerseDetailSheet: View {
    let delivery: VerseDelivery
    let preferredBibleID: Int
    let onReact: (VerseReaction) -> Void
    var onShare: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ScriptureEngine.self) private var scriptureEngine

    @State private var whyExpanded = false

    // Feedback state
    @State private var fitAnswer: FitAnswer? = nil
    @State private var helpfulAnswer: HelpfulAnswer? = nil
    @State private var showingFeelingPicker = false

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
                SmallStateBanner(state: state, confidence: delivery.stateConfidence, emotion: delivery.emotion)

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

                // Feedback row
                VerseFeedbackRow(
                    delivery: delivery,
                    fitAnswer: $fitAnswer,
                    helpfulAnswer: $helpfulAnswer,
                    showingFeelingPicker: $showingFeelingPicker
                )

                // Bottom safe area buffer
                Color.clear.frame(height: PSSpacing.xl)
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
        }
        .background(Color.psDeepNavy.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden) // we draw our own
        .sheet(isPresented: $showingFeelingPicker) {
            FeelingPickerView { emotion in
                // Record: emotion was not accurate, user corrected to chosen emotion
                let helpful = helpfulAnswer.map { $0 == .yes } ?? true
                let feedback = EmotionFeedback(
                    shownEmotionRaw: delivery.emotion.rawValue,
                    wasAccurate: false,
                    correctedEmotionRaw: emotion.rawValue,
                    verseReference: delivery.verseReference,
                    verseID: delivery.verseID,
                    wasHelpful: helpful
                )
                PersonalizationStore(context: modelContext).record(feedback)
                dismiss()
                Task {
                    await scriptureEngine.deliverFirstVerse(
                        mockState: emotion.biometricState,
                        suppressNotification: true
                    )
                }
            }
        }
    }
}

// MARK: - VerseFeedbackRow

private struct VerseFeedbackRow: View {
    let delivery: VerseDelivery
    @Binding var fitAnswer: FitAnswer?
    @Binding var helpfulAnswer: HelpfulAnswer?
    @Binding var showingFeelingPicker: Bool

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: PSSpacing.md) {

            // "Did this fit?" section
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                Text("Did this fit?")
                    .font(PSFont.label(size: 13, weight: .semibold))
                    .foregroundStyle(Color.psGrayMuted)

                HStack(spacing: PSSpacing.sm) {
                    FeedbackChip(
                        label: "Yes",
                        icon: "checkmark",
                        isSelected: fitAnswer == .yes,
                        isDisabled: fitAnswer != nil
                    ) {
                        fitAnswer = .yes
                        let helpful = helpfulAnswer.map { $0 == .yes } ?? true
                        recordFeedback(wasAccurate: true, correctedEmotionRaw: nil, wasHelpful: helpful)
                    }

                    FeedbackChip(
                        label: "Not quite",
                        icon: "arrow.triangle.2.circlepath",
                        isSelected: fitAnswer == .notQuite,
                        isDisabled: fitAnswer != nil
                    ) {
                        fitAnswer = .notQuite
                        showingFeelingPicker = true
                        // Actual recording happens in the FeelingPickerView callback
                    }

                    Spacer()
                }
            }

            Divider()
                .background(Color.psGrayMuted.opacity(0.3))

            // "Was this helpful?" section
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                Text("Was this helpful?")
                    .font(PSFont.label(size: 13, weight: .semibold))
                    .foregroundStyle(Color.psGrayMuted)

                HStack(spacing: PSSpacing.sm) {
                    FeedbackChip(
                        label: "Yes",
                        icon: "hand.thumbsup",
                        isSelected: helpfulAnswer == .yes,
                        isDisabled: helpfulAnswer != nil
                    ) {
                        helpfulAnswer = .yes
                        let accurate = fitAnswer.map { $0 == .yes } ?? true
                        recordFeedback(wasAccurate: accurate, correctedEmotionRaw: nil, wasHelpful: true)
                    }

                    FeedbackChip(
                        label: "No",
                        icon: "hand.thumbsdown",
                        isSelected: helpfulAnswer == .no,
                        isDisabled: helpfulAnswer != nil
                    ) {
                        helpfulAnswer = .no
                        let accurate = fitAnswer.map { $0 == .yes } ?? true
                        recordFeedback(wasAccurate: accurate, correctedEmotionRaw: nil, wasHelpful: false)
                    }

                    Spacer()
                }
            }
        }
        .padding(PSSpacing.md)
        .background(Color.psNavy)
        .clipShape(RoundedRectangle(cornerRadius: PSRadius.md))
    }

    private func recordFeedback(wasAccurate: Bool, correctedEmotionRaw: String?, wasHelpful: Bool) {
        let feedback = EmotionFeedback(
            shownEmotionRaw: delivery.emotion.rawValue,
            wasAccurate: wasAccurate,
            correctedEmotionRaw: correctedEmotionRaw,
            verseReference: delivery.verseReference,
            verseID: delivery.verseID,
            wasHelpful: wasHelpful
        )
        PersonalizationStore(context: modelContext).record(feedback)
    }
}

// MARK: - FeedbackChip

private struct FeedbackChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(PSFont.label(size: 14, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.psDeepNavy : Color.psWhite.opacity(0.8))
            .padding(.horizontal, PSSpacing.md)
            .padding(.vertical, PSSpacing.sm)
            .frame(minHeight: 44)
            .background(isSelected ? Color.psAccent : Color.psDeepNavy.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: PSRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: PSRadius.sm)
                    .stroke(isSelected ? Color.clear : Color.psGrayMuted.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled && !isSelected ? 0.45 : 1)
        .accessibilityLabel(label)
    }
}

// MARK: - SmallStateBanner

private struct SmallStateBanner: View {
    let state: BiometricState
    let confidence: Double
    let emotion: Emotion

    var body: some View {
        PSCard(style: .state(state)) {
            HStack {
                StateChip(state: state, showConfidence: true, confidence: confidence, emotion: emotion)
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
                icon: delivery.isLoved ? "heart.fill" : "heart",
                label: "Love",
                tint: delivery.isLoved ? .red : Color.psWhite.opacity(0.7)
            ) {
                onReact(.loved)
            }

            // Save
            DetailActionButton(
                icon: delivery.isSaved ? "bookmark.fill" : "bookmark",
                label: "Save",
                tint: delivery.isSaved ? Color.psAccent : Color.psWhite.opacity(0.7)
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
