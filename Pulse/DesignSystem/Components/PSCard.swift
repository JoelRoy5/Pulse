import SwiftUI
import PulseShared

struct PSCard<Content: View>: View {
    let style: CardStyle
    @ViewBuilder let content: () -> Content

    enum CardStyle {
        case standard       // dark navy, subtle border
        case verse          // cream/paper texture, dark text
        case state(BiometricState)  // state gradient
        case transparent    // frosted glass
    }

    var body: some View {
        content()
            .padding(PSSpacing.cardPadding)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: PSRadius.card))
            .psCardShadow()
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .standard:
            Color.psNavy
                .overlay(
                    RoundedRectangle(cornerRadius: PSRadius.card)
                        .stroke(Color.psGrayMuted.opacity(0.2), lineWidth: 1)
                )
        case .verse:
            Color.psCream
        case .state(let state):
            state.gradient
        case .transparent:
            Rectangle()
                .fill(.ultraThinMaterial)
        }
    }
}

#Preview {
    ZStack {
        Color.psDeepNavy
            .ignoresSafeArea()

        VStack(spacing: 16) {
            // Standard card
            PSCard(style: .standard) {
                Text("Standard Card")
                    .font(PSFont.label(size: 16, weight: .semibold))
                    .foregroundStyle(Color.psWhite)
            }

            // Verse card
            PSCard(style: .verse) {
                Text("Verse Card")
                    .font(PSFont.label(size: 16, weight: .semibold))
                    .foregroundStyle(Color.psDeepNavy)
            }

            // State card
            PSCard(style: .state(.peacefulSteady)) {
                Text("State Card")
                    .font(PSFont.label(size: 16, weight: .semibold))
                    .foregroundStyle(Color.psWhite)
            }

            // Transparent card
            PSCard(style: .transparent) {
                Text("Transparent Card")
                    .font(PSFont.label(size: 16, weight: .semibold))
                    .foregroundStyle(Color.psWhite)
            }

            Spacer()
        }
        .padding(PSSpacing.screenHorizontal)
    }
}
