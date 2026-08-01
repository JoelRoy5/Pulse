import SwiftUI
import UIKit
import PulseShared

struct OnboardingCompleteView: View {
    @Bindable var vm: OnboardingViewModel
    var onComplete: () -> Void

    @State private var showVerseCard = false
    @State private var showTagline = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: PSSpacing.xl) {
                Spacer()

                // Gold pulsing ring
                PulseRing(color: Color.psAccent, bpm: 60)
                    .frame(width: 140, height: 140)

                // Header
                Text("Your first verse, chosen just for you")
                    .font(PSFont.label(size: 20, weight: .semibold))
                    .foregroundStyle(Color.psWhite.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PSSpacing.screenHorizontal)

                // Verse card — slides up (or fades in when reduce motion) after 1.5s pause
                if showVerseCard, let delivery = vm.firstVerse {
                    PSCard(style: .standard) {
                        VStack(alignment: .leading, spacing: PSSpacing.md) {
                            // State chip
                            if let state = delivery.biometricState {
                                StateChip(state: state, showConfidence: false, confidence: nil)
                            }
                            // Verse text
                            VerseTextView(
                                text: delivery.verseText,
                                reference: delivery.verseReference,
                                translation: delivery.translationAbbreviation,
                                fontSize: 18
                            )
                        }
                    }
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .transition(reduceMotion ? .opacity : .psSlideUp)
                } else if showVerseCard {
                    // Fallback if verse not yet set (race condition guard)
                    PSCard(style: .standard) {
                        Text("Preparing your verse…")
                            .font(PSFont.label(size: 15))
                            .foregroundStyle(Color.psWhite.opacity(0.7))
                            .padding()
                    }
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .transition(reduceMotion ? .opacity : .psSlideUp)
                }

                // Tagline
                if showTagline {
                    Text("This is just the beginning")
                        .font(PSFont.verseText(size: 17))
                        .foregroundStyle(Color.psWhite.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }

                Spacer()

                // Open Pulse button
                if showVerseCard {
                    PSButton(title: "Open Pulse", style: .primary) {
                        onComplete()
                    }
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .padding(.bottom, PSSpacing.xxl)
                    .transition(reduceMotion ? .opacity : .psSlideUp)
                }
            }
        }
        .task {
            // 1.5s pause (or no pause when reduce motion), then show verse card + success haptic
            if !reduceMotion {
                try? await Task.sleep(for: .seconds(1.5))
            }
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            withAnimation(reduceMotion ? .easeIn(duration: 0.3) : .psCardSpring) {
                showVerseCard = true
            }
            generator.notificationOccurred(.success)
            // Tagline fades in after card appears
            withAnimation(.easeIn(duration: 0.8).delay(reduceMotion ? 0 : 0.4)) {
                showTagline = true
            }
        }
    }
}
