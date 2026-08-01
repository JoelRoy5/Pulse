import SwiftUI
import PulseShared

struct PSButton: View {
    let title: String
    let style: Style
    let action: () -> Void

    enum Style {
        case primary    // gold capsule with dark navy text
        case secondary  // stroked capsule
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PSFont.label(size: 17, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(backgroundColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(strokeColor, lineWidth: strokeWidth)
                )
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return Color.psDeepNavy
        case .secondary:
            return Color.psAccent
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return Color.psAccent
        case .secondary:
            return Color.clear
        }
    }

    private var strokeColor: Color {
        switch style {
        case .primary:
            return Color.clear
        case .secondary:
            return Color.psAccent
        }
    }

    private var strokeWidth: CGFloat {
        switch style {
        case .primary:
            return 0
        case .secondary:
            return 1.5
        }
    }
}

#Preview {
    ZStack {
        Color.psDeepNavy
            .ignoresSafeArea()

        VStack(spacing: 16) {
            PSButton(title: "Primary Button", style: .primary) {
                print("Primary tapped")
            }

            PSButton(title: "Secondary Button", style: .secondary) {
                print("Secondary tapped")
            }

            Spacer()
        }
        .padding(PSSpacing.screenHorizontal)
    }
}
