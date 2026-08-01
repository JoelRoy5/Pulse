import SwiftUI
import PulseShared

struct WelcomeView: View {
    @Bindable var vm: OnboardingViewModel

    // Staggered animation state for 3 feature rows
    @State private var showRow1 = false
    @State private var showRow2 = false
    @State private var showRow3 = false
    @State private var showTagline = false

    var body: some View {
        ZStack {
            // Background gradient: deep navy → rich purple
            LinearGradient(
                colors: [Color.psDeepNavy, Color(hex: "#2D1B69")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Ambient PulseRing (particles = Phase 2)
                PulseRing(color: Color.psAccent, bpm: 60)
                    .frame(width: 100, height: 100)
                    .padding(.bottom, PSSpacing.lg)

                // Tagline (serif)
                Text("Scripture that meets you\nwhere you are")
                    .font(PSFont.verseText(size: 28))
                    .foregroundStyle(Color.psWhite)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .opacity(showTagline ? 1 : 0)
                    .offset(y: showTagline ? 0 : 12)

                Spacer().frame(height: PSSpacing.xxl)

                // 3 feature rows — staggered fade-in
                VStack(alignment: .leading, spacing: PSSpacing.lg) {
                    featureRow(emoji: "♥", text: "Reads your heartbeat", visible: showRow1)
                    featureRow(emoji: "🌙", text: "Watches while you sleep", visible: showRow2)
                    featureRow(emoji: "📖", text: "Speaks God's Word when you need it", visible: showRow3)
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)

                Spacer()

                // CTA
                PSButton(title: "Begin Your Journey →", style: .primary) {
                    vm.step = .permissions
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.bottom, PSSpacing.xxl)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { showTagline = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) { showRow1 = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) { showRow2 = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.7)) { showRow3 = true }
        }
    }

    private func featureRow(emoji: String, text: String, visible: Bool) -> some View {
        HStack(spacing: PSSpacing.md) {
            Text(emoji)
                .font(.system(size: 22))
            Text(text)
                .font(PSFont.label(size: 17, weight: .medium))
                .foregroundStyle(Color.psWhite)
        }
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : -20)
    }
}
