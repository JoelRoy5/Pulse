import SwiftUI
import PulseShared

struct StateChip: View {
    let state: BiometricState
    let showConfidence: Bool
    let confidence: Double?

    var body: some View {
        HStack(spacing: PSSpacing.xs) {
            Text(state.emoji)
                .font(.system(size: 14))
            Text(state.displayName.uppercased())
                .font(PSFont.label(size: 11, weight: .semibold))
                .kerning(1.5)
            if showConfidence, let confidence {
                Text("\(Int(confidence * 100))%")
                    .font(PSFont.label(size: 10))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, PSSpacing.sm)
        .padding(.vertical, PSSpacing.xs)
        .background(state.primaryColor.opacity(0.25))
        .overlay(
            Capsule()
                .stroke(state.primaryColor.opacity(0.5), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

#Preview {
    ZStack {
        Color.psDeepNavy
            .ignoresSafeArea()

        VStack(spacing: 16) {
            Text("State Chips")
                .font(PSFont.label(size: 16, weight: .semibold))
                .foregroundStyle(Color.psWhite)

            VStack(spacing: 12) {
                StateChip(state: .peacefulSteady, showConfidence: false, confidence: nil)

                StateChip(state: .energizedPostWorkout, showConfidence: true, confidence: 0.92)

                StateChip(state: .exhaustedDepleted, showConfidence: true, confidence: 0.78)

                StateChip(state: .stressedAnxious, showConfidence: true, confidence: 0.65)

                StateChip(state: .activeEngaged, showConfidence: false, confidence: nil)

                StateChip(state: .spiritualAlert, showConfidence: true, confidence: 0.88)
            }

            Spacer()
        }
        .padding(PSSpacing.screenHorizontal)
    }
}
