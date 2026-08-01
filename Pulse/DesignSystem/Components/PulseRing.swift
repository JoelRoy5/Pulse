import SwiftUI
import PulseShared

struct PulseRing: View {
    let color: Color
    let bpm: Double  // pulses per minute

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.6
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(color.opacity(opacity), lineWidth: 2)
                .scaleEffect(scale)

            // Inner solid ring
            Circle()
                .fill(color.opacity(opacity * 0.33))
                .scaleEffect(scale * 0.7)
        }
        .onAppear {
            if !reduceMotion {
                let interval = 60.0 / bpm
                withAnimation(
                    .easeInOut(duration: interval * 0.4)
                        .repeatForever(autoreverses: true)
                ) {
                    scale = 1.15
                    opacity = 0.9
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.psDeepNavy
            .ignoresSafeArea()

        VStack(spacing: 32) {
            Text("Pulse Ring Animation")
                .font(PSFont.label(size: 16, weight: .semibold))
                .foregroundStyle(Color.psWhite)

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    PulseRing(color: Color.psAccent, bpm: 60)
                        .frame(width: 120, height: 120)

                    Text("60 BPM")
                        .font(PSFont.label(size: 12))
                        .foregroundStyle(Color.psGrayMuted)
                }

                VStack(spacing: 8) {
                    PulseRing(color: Color.psSuccess, bpm: 80)
                        .frame(width: 120, height: 120)

                    Text("80 BPM")
                        .font(PSFont.label(size: 12))
                        .foregroundStyle(Color.psGrayMuted)
                }

                VStack(spacing: 8) {
                    PulseRing(color: Color.psAlert, bpm: 100)
                        .frame(width: 120, height: 120)

                    Text("100 BPM")
                        .font(PSFont.label(size: 12))
                        .foregroundStyle(Color.psGrayMuted)
                }
            }

            Spacer()
        }
        .padding(PSSpacing.screenHorizontal)
    }
}
