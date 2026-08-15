import SwiftUI
import SwiftData
import PulseShared

// MARK: - RecentVersesRow

struct RecentVersesRow: View {
    let deliveries: [VerseDelivery]
    let onSelect: (VerseDelivery) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            // Section header
            HStack {
                Text("Recent Verses")
                    .font(PSFont.label(size: 16, weight: .semibold))
                    .foregroundStyle(Color.psWhite)
                Spacer()
                // "See All" — Phase 2 (HistoryView)
                Text("See All →")
                    .font(PSFont.label(size: 13))
                    .foregroundStyle(Color.psAccent)
            }

            if deliveries.isEmpty {
                Text("No verses delivered yet")
                    .font(PSFont.label(size: 13))
                    .foregroundStyle(Color.psGrayMuted)
                    .padding(.vertical, PSSpacing.sm)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PSSpacing.sm) {
                        ForEach(deliveries) { delivery in
                            RecentVerseCard(delivery: delivery)
                                .onTapGesture { onSelect(delivery) }
                        }
                    }
                    .padding(.vertical, 2) // avoid shadow clipping
                }
            }
        }
    }
}

// MARK: - RecentVerseCard

private struct RecentVerseCard: View {
    let delivery: VerseDelivery

    private var state: BiometricState {
        delivery.biometricState ?? .peacefulSteady
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private var dateLabel: String {
        Self.dateFormatter.string(from: delivery.deliveredAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PSSpacing.xs) {
            // State indicator strip
            HStack(spacing: 4) {
                Image(systemName: state.systemImageName)
                    .font(.system(size: 11))
                    .foregroundStyle(state.primaryColor)
                Text(state.abbreviation.uppercased())
                    .font(PSFont.label(size: 10, weight: .semibold))
                    .foregroundStyle(state.primaryColor)
                    .kerning(0.8)
            }

            // Reference
            Text(delivery.verseReference)
                .font(PSFont.label(size: 13, weight: .semibold))
                .foregroundStyle(Color.psWhite)
                .lineLimit(1)

            // Date
            Text(dateLabel)
                .font(PSFont.label(size: 11))
                .foregroundStyle(Color.psGrayMuted)
        }
        .padding(PSSpacing.sm)
        .frame(width: 130, alignment: .leading)
        .background(
            state.gradient
                .opacity(0.4)
                .background(Color.psNavy)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PSRadius.sm)
                .stroke(state.primaryColor.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: PSRadius.sm))
        .psSubtleShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(delivery.verseReference), \(state.displayName), \(dateLabel)")
        .accessibilityAddTraits(.isButton)
    }
}
