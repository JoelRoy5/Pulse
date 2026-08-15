import SwiftUI
import PulseShared

// MARK: - HistoryDetailView
//
// Standalone detail view for a VerseDelivery from the history list.
// Shows: full verse (cream card), state chip, "Delivered <date+time>",
// horizontal metric chips (heart rate / HRV / sleep efficiency — omit nils),
// user reaction, and a Share button that presents ShareCardView.
// Satisfies doc-05:275-283.

struct HistoryDetailView: View {
    let delivery: VerseDelivery
    let preferredBibleID: Int
    let onReact: (VerseReaction) -> Void
    let onShare: () -> Void

    private var state: BiometricState {
        delivery.biometricState ?? .peacefulSteady
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

                // State chip row
                HStack {
                    StateChip(state: state, showConfidence: true, confidence: delivery.stateConfidence)
                    Spacer()
                }

                // Full verse — cream card, dark text (VerseDetailSheet style)
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

                // Delivered timestamp
                DeliveredTimestampRow(deliveredAt: delivery.deliveredAt)

                // Horizontal metric chips (omit nils)
                HistoryMetricChips(delivery: delivery)

                // Reaction display (icon + displayName when present)
                if let reaction = delivery.userReaction {
                    ReactionDisplayRow(reaction: reaction)
                }

                // Share button
                Button(action: onShare) {
                    HStack(spacing: PSSpacing.sm) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17))
                        Text("Share")
                            .font(PSFont.label(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(Color.psDeepNavy)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(Color.psAccent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share verse card")

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

// MARK: - DeliveredTimestampRow

private struct DeliveredTimestampRow: View {
    let deliveredAt: Date

    private var formatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: deliveredAt)
    }

    var body: some View {
        HStack(spacing: PSSpacing.xs) {
            Image(systemName: "clock")
                .font(.system(size: 13))
                .foregroundStyle(Color.psGrayMuted)
            Text("Delivered \(formatted)")
                .font(PSFont.label(size: 13))
                .foregroundStyle(Color.psGrayMuted)
        }
    }
}

// MARK: - HistoryMetricChips
//
// Horizontal row of small capsule chips for the stored health metrics.
// Omits any metric that is nil.

private struct HistoryMetricChips: View {
    let delivery: VerseDelivery

    var body: some View {
        let chips = buildChips()
        if !chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PSSpacing.sm) {
                    ForEach(chips) { chip in
                        MetricCapsuleChip(chip: chip)
                    }
                }
            }
        }
    }

    private func buildChips() -> [MetricChipData] {
        var result: [MetricChipData] = []

        if let hr = delivery.heartRateAtDelivery {
            result.append(MetricChipData(
                id: "hr",
                icon: "HR",
                label: "Heart Rate",
                value: "\(Int(hr))",
                unit: "bpm"
            ))
        }
        if let hrv = delivery.hrvAtDelivery {
            result.append(MetricChipData(
                id: "hrv",
                icon: "HRV",
                label: "HRV",
                value: "\(Int(hrv))",
                unit: "ms"
            ))
        }
        if let sleep = delivery.sleepEfficiencyAtDelivery {
            result.append(MetricChipData(
                id: "sleep",
                icon: "Sleep",
                label: "Sleep",
                value: "\(Int(sleep * 100))",
                unit: "%"
            ))
        }

        return result
    }
}

private struct MetricChipData: Identifiable {
    let id: String
    let icon: String
    let label: String
    let value: String
    let unit: String
}

private struct MetricCapsuleChip: View {
    let chip: MetricChipData

    var body: some View {
        HStack(spacing: 4) {
            Text(chip.icon)
                .font(PSFont.label(size: 11, weight: .semibold))
                .foregroundStyle(Color.psAccentLight)
            Text("\(chip.value) \(chip.unit)")
                .font(PSFont.label(size: 12, weight: .medium))
                .foregroundStyle(Color.psWhite)
        }
        .padding(.horizontal, PSSpacing.sm)
        .padding(.vertical, 5)
        .background(Color.psNavy)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.psAccent.opacity(0.3), lineWidth: 1)
        )
        .accessibilityLabel("\(chip.label): \(chip.value) \(chip.unit)")
    }
}

// MARK: - ReactionDisplayRow

private struct ReactionDisplayRow: View {
    let reaction: VerseReaction

    private var tint: Color {
        switch reaction {
        case .loved:  return .red
        case .saved:  return Color.psAccent
        default:      return Color.psWhite.opacity(0.7)
        }
    }

    var body: some View {
        HStack(spacing: PSSpacing.xs) {
            Image(systemName: reaction.icon)
                .font(.system(size: 13))
                .foregroundStyle(tint)
            Text(reaction.displayName)
                .font(PSFont.label(size: 13))
                .foregroundStyle(Color.psGrayMuted)
        }
    }
}
