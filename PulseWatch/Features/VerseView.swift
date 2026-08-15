import SwiftUI
import WatchKit
import PulseShared

// MARK: - VerseView

struct VerseView: View {
    @Environment(WatchState.self) private var watchState
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        ZStack {
            if isLuminanceReduced {
                AODVerseView(verse: watchState.currentVerse)
            } else {
                FullVerseView(verse: watchState.currentVerse)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - AOD Variant

private struct AODVerseView: View {
    let verse: WatchMessage.VerseDeliveryPayload?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 4) {
                Image(systemName: verse?.stateSymbol ?? "heart.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                if let verse {
                    Text(verse.verseText.verseExcerpt(maxChars: 30))
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                    Text(verse.verseReference)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Full Verse View

private struct FullVerseView: View {
    let verse: WatchMessage.VerseDeliveryPayload?
    @Environment(WatchState.self) private var watchState
    @State private var showFullText = false
    @State private var breatheOpacity: Double = 0.7
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var biometricState: BiometricState? {
        verse.flatMap { BiometricState(rawValue: $0.stateRaw) }
    }

    var body: some View {
        ZStack {
            // Full-bleed gradient background
            backgroundGradient
                .ignoresSafeArea()
                .opacity(breatheOpacity)
                .animation(
                    reduceMotion ? nil : Animation.easeInOut(duration: 4.0).repeatForever(autoreverses: true),
                    value: breatheOpacity
                )
                .onAppear {
                    if !reduceMotion {
                        breatheOpacity = 1.0
                    } else {
                        breatheOpacity = 0.85
                    }
                }

            if let verse {
                verseContent(verse)
            } else {
                emptyStateView
            }
        }
        .sheet(isPresented: $showFullText) {
            if let verse {
                FullTextSheetView(verse: verse)
            }
        }
    }

    @ViewBuilder
    private var backgroundGradient: some View {
        if let state = biometricState {
            state.gradient
        } else {
            LinearGradient(
                colors: [Color.psDeepNavy, Color.psNavy],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func verseContent(_ verse: WatchMessage.VerseDeliveryPayload) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // State pill
            statePill(verse: verse)
                .padding(.top, 4)
                .padding(.horizontal, 8)

            Spacer(minLength: 4)

            // Verse text — long-press 1.5s → full text sheet
            Text(verse.verseText)
                .font(.system(size: 14, design: .serif))
                .minimumScaleFactor(0.6)
                .lineLimit(4)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 10)
                .onLongPressGesture(minimumDuration: 1.5) {
                    WKInterfaceDevice.current().play(.click)
                    showFullText = true
                }

            Spacer(minLength: 4)

            // Reference right-aligned
            Text(verse.verseReference)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 10)

            Spacer(minLength: 6)

            // Action row
            actionRow(verse: verse)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func statePill(verse: WatchMessage.VerseDeliveryPayload) -> some View {
        let stateColor = biometricState?.primaryColor ?? Color(hex: verse.primaryColor)
        HStack(spacing: 3) {
            Image(systemName: verse.stateSymbol)
                .font(.system(size: 10))
                .foregroundStyle(stateColor)
            Text((BiometricState(rawValue: verse.stateRaw)?.abbreviation ?? verse.stateDisplayName).uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(stateColor.opacity(0.35))
        .clipShape(Capsule())
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func actionRow(verse: WatchMessage.VerseDeliveryPayload) -> some View {
        HStack(spacing: 0) {
            // Love
            Button {
                WKInterfaceDevice.current().play(.success)
                WatchSessionManager.shared.sendReaction(.loved, deliveryID: verse.deliveryID)
            } label: {
                Image(systemName: "heart")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            // Save
            Button {
                WKInterfaceDevice.current().play(.click)
                WatchSessionManager.shared.sendReaction(.saved, deliveryID: verse.deliveryID)
            } label: {
                Image(systemName: "bookmark")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            // Share
            Button {
                WKInterfaceDevice.current().play(.click)
                WatchSessionManager.shared.sendReaction(.shared, deliveryID: verse.deliveryID)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.psAccent)
            Text("Gathering your\nhealth data...")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            Text("Check back in\na few minutes")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button("Check for verse") {
                Task { await WatchSessionManager.shared.requestLatestVerse() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.psAccent)
            .font(.system(size: 12, weight: .semibold))
            .padding(.top, 4)
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Full Text Sheet

private struct FullTextSheetView: View {
    let verse: WatchMessage.VerseDeliveryPayload

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(verse.verseText)
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(verse.verseReference)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .background(
            (BiometricState(rawValue: verse.stateRaw)?.gradient) ??
            LinearGradient(colors: [Color.psDeepNavy], startPoint: .top, endPoint: .bottom)
        )
    }
}

// MARK: - String Extension

extension String {
    func verseExcerpt(maxChars: Int = 50) -> String {
        guard self.count > maxChars else { return self }
        let prefix = String(self.prefix(maxChars))
        // Trim to last word boundary
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace]) + "..."
        }
        return prefix + "..."
    }
}
