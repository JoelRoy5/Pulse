import SwiftUI
import HealthKit
import WatchKit
import PulseShared

// MARK: - PrayerTimeView

/// "A Time of Prayer" — a short, guided time of stillness before God on the wrist.
///
/// A heartbeat-style haptic eases from the wearer's live rate toward a calm rate
/// while rotating prayer + scripture lines appear. Prayer-centric throughout —
/// there is intentionally no breathing or meditation language anywhere here.
struct PrayerTimeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The current verse delivery, used for the session gradient, prompt theme,
    /// closing verse, and the reaction target. May be nil (no verse yet).
    let currentVerse: WatchMessage.VerseDeliveryPayload?

    private let sessionDuration: TimeInterval = 120

    @State private var player: PrayerHapticPlayer?
    @State private var prompts: [String] = PrayerPrompts.general
    @State private var promptIndex = 0
    @State private var beatScale: CGFloat = 1.0
    @State private var elapsed: TimeInterval = 0
    @State private var isClosing = false
    @State private var finalized = false
    @State private var startedAt = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let promptClock = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    // MARK: - Derived

    private var state: BiometricState {
        BiometricState(rawValue: currentVerse?.stateRaw ?? "") ?? .spiritualAlert
    }

    private var closingVerse: BibleVerse {
        if let v = currentVerse, !v.verseText.isEmpty {
            return BibleVerse(
                id: v.deliveryID,
                reference: v.verseReference,
                text: v.verseText,
                translationAbbreviation: v.translationAbbreviation,
                copyright: "",
                chapterURLString: nil
            )
        }
        return FallbackVerseProvider().emergencyVerse(for: state)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            state.gradient.ignoresSafeArea()
            if isClosing {
                closingScreen
            } else {
                sessionScreen
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { startSession() }
        .onDisappear { player?.stop() }
        .onReceive(ticker) { _ in
            guard !isClosing else { return }
            elapsed = Date().timeIntervalSince(startedAt)
            if elapsed >= sessionDuration { completeSession() }
        }
        .onReceive(promptClock) { _ in
            guard !isClosing, !prompts.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                promptIndex = (promptIndex + 1) % prompts.count
            }
        }
    }

    // MARK: - Session screen

    private var sessionScreen: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 4)

            // Heartbeat ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 2)
                Circle()
                    .stroke(Color.white.opacity(0.7), lineWidth: 3)
                    .scaleEffect(beatScale)
                Image(systemName: "heart.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.9))
                    .scaleEffect(beatScale)
            }
            .frame(width: 74, height: 74)

            // Rotating prayer prompt
            Text(prompts.isEmpty ? "" : prompts[promptIndex])
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .id(promptIndex)
                .transition(.opacity)

            Spacer(minLength: 4)

            Button("Amen") { endEarly() }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.25))
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.vertical, 8)
    }

    // MARK: - Closing screen

    private var closingScreen: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Peace be with you")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 6)

                Divider().overlay(.white.opacity(0.2))

                Text(closingVerse.text)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(closingVerse.reference)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.25))
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Lifecycle

    private func startSession() {
        startedAt = Date()
        prompts = PrayerPrompts.prompts(for: currentVerse?.stateRaw)
        requestMindfulAuthorization()

        let hr = WatchHealthEngine.shared.snapshot?.heartRate ?? 70
        let cadence = PrayerCadence(
            startBPM: hr,
            targetBPM: min(60, hr),
            durationSeconds: sessionDuration
        )
        let player = PrayerHapticPlayer(cadence: cadence)
        self.player = player
        player.start {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.16)) { beatScale = 1.18 }
            withAnimation(.easeIn(duration: 0.45).delay(0.16)) { beatScale = 1.0 }
        }
    }

    /// Amen tapped — finalize and leave immediately.
    private func endEarly() {
        WKInterfaceDevice.current().play(.success)
        finalize()
        dismiss()
    }

    /// Full duration reached — finalize and show the closing screen.
    private func completeSession() {
        finalize()
        withAnimation(.easeInOut(duration: 0.5)) { isClosing = true }
    }

    /// Stops haptics, records the mindful session and the prayed reaction. Idempotent.
    private func finalize() {
        guard !finalized else { return }
        finalized = true
        player?.stop()
        writeMindfulSession(start: startedAt, end: Date())
        WatchSessionManager.shared.sendReaction(
            .prayed,
            deliveryID: currentVerse?.deliveryID ?? "prayer"
        )
    }

    /// Ask for mindfulSession share access at session start, so the prompt is
    /// resolved before the write at the end (otherwise the first session's write
    /// races the permission sheet and is silently dropped).
    private func requestMindfulAuthorization() {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }
        Task { try? await HKHealthStore().requestAuthorization(toShare: [type], read: []) }
    }

    /// Best-effort write of an HKCategoryType.mindfulSession for the elapsed span.
    /// Any failure (unavailable, denied) is silently ignored.
    private func writeMindfulSession(start: Date, end: Date) {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKObjectType.categoryType(forIdentifier: .mindfulSession),
              end > start else { return }
        let store = HKHealthStore()
        Task {
            try? await store.requestAuthorization(toShare: [type], read: [])
            let sample = HKCategorySample(
                type: type,
                value: HKCategoryValue.notApplicable.rawValue,
                start: start,
                end: end
            )
            try? await store.save(sample)
        }
    }
}
