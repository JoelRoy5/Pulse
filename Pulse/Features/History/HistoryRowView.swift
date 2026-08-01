import SwiftUI
import PulseShared

// MARK: - HistoryRowView

struct HistoryRowView: View {
    let delivery: VerseDelivery
    let onShare: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var state: BiometricState {
        delivery.biometricState ?? .peacefulSteady
    }

    private var formattedDate: String {
        delivery.deliveredAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private var excerpt: String {
        let words = delivery.verseText.split(separator: " ")
        if words.count <= 10 {
            return delivery.verseText
        }
        return words.prefix(10).joined(separator: " ") + "…"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PSSpacing.xs) {

            // Row 1: emoji + state name · date+time
            HStack(spacing: PSSpacing.xs) {
                Text(state.emoji)
                    .font(.system(size: 14))
                Text(state.displayName)
                    .font(PSFont.label(size: 13, weight: .semibold))
                    .foregroundStyle(state.primaryColor)
                Text("·")
                    .foregroundStyle(Color.psGrayMuted)
                Text(formattedDate)
                    .font(PSFont.label(size: 12))
                    .foregroundStyle(Color.psGrayMuted)
                Spacer()
            }

            // Row 2: verse reference
            Text(delivery.verseReference)
                .font(PSFont.label(size: 14, weight: .semibold))
                .foregroundStyle(Color.psWhite)

            // Row 3: one-line excerpt
            Text("\u{201C}\(excerpt)\u{201D}")
                .font(PSFont.verseText(size: 13))
                .foregroundStyle(Color.psWhite.opacity(0.75))
                .lineLimit(2)

            // Row 4: reaction icon (if any)
            if let reaction = delivery.userReaction {
                HStack(spacing: 4) {
                    Image(systemName: reaction.icon)
                        .font(.system(size: 11))
                    Text(reaction.displayName)
                        .font(PSFont.label(size: 11))
                }
                .foregroundStyle(reactionColor(for: reaction))
            }
        }
        .padding(.vertical, PSSpacing.sm)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onShare()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(state.displayName), \(delivery.verseReference), \(delivery.verseText)")
    }

    private func reactionColor(for reaction: VerseReaction) -> Color {
        switch reaction {
        case .loved:     return .red
        case .saved:     return Color.psAccent
        case .shared:    return Color.psAccentLight
        case .prayed:    return Color.psSuccess
        case .dismissed: return Color.psGrayMuted
        }
    }
}
