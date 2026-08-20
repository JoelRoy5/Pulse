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

            // Row 1: state symbol + state name · date+time
            HStack(spacing: PSSpacing.xs) {
                Image(systemName: state.systemImageName)
                    .font(.system(size: 12))
                    .foregroundStyle(state.primaryColor)
                Text(delivery.emotion.displayName)
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

            // Row 4: engagement badges — Love and Save are independent, plus any
            // transient reaction (prayed / shared).
            HStack(spacing: 8) {
                if delivery.isLoved {
                    reactionBadge(icon: "heart.fill", label: "Loved", color: .red)
                }
                if delivery.isSaved {
                    reactionBadge(icon: "bookmark.fill", label: "Saved", color: Color.psAccent)
                }
                if let reaction = delivery.userReaction, reaction == .prayed || reaction == .shared {
                    reactionBadge(icon: reaction.icon, label: reaction.displayName, color: reactionColor(for: reaction))
                }
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
        .accessibilityLabel("\(delivery.emotion.displayName), \(delivery.verseReference), \(delivery.verseText)")
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

    @ViewBuilder
    private func reactionBadge(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(label)
                .font(PSFont.label(size: 11))
        }
        .foregroundStyle(color)
    }
}
