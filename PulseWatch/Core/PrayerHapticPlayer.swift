import Foundation
import WatchKit
import PulseShared

// MARK: - PrayerHapticPlayer

/// Plays a heartbeat-style haptic during "A Time of Prayer".
///
/// Each beat is a **lub-dub** pair of taps. The interval between beats is
/// recomputed every beat from `PrayerCadence`, so the felt heartbeat gently
/// eases from the wearer's live rate toward a calm resting rate over the
/// session. This is a prayer aid — not a breathing or meditation pacer.
@MainActor
final class PrayerHapticPlayer {

    private let cadence: PrayerCadence
    private var loop: Task<Void, Never>?
    private var startedAt: Date?

    /// Delay between the "lub" and the "dub" of a single beat.
    private let lubDubGap: TimeInterval = 0.14

    init(cadence: PrayerCadence) {
        self.cadence = cadence
    }

    /// Begins the self-rescheduling heartbeat. `onBeat` fires on the main actor
    /// at the start of each beat (e.g. to pulse a ring in the UI).
    func start(onBeat: (() -> Void)? = nil) {
        stop()
        let start = Date()
        startedAt = start

        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                let elapsed = Date().timeIntervalSince(start)
                onBeat?()
                self.playLubDub()

                let interval = self.cadence.beatInterval(atElapsed: elapsed)
                let nanos = UInt64(max(interval, 0.2) * 1_000_000_000)
                do {
                    try await Task.sleep(nanoseconds: nanos)
                } catch {
                    return // cancelled during sleep
                }
            }
        }
    }

    /// Stops the heartbeat. Safe to call repeatedly.
    func stop() {
        loop?.cancel()
        loop = nil
        startedAt = nil
    }

    /// Seconds elapsed since `start`, or 0 if not running.
    var elapsed: TimeInterval {
        guard let startedAt else { return 0 }
        return Date().timeIntervalSince(startedAt)
    }

    // MARK: - Private

    private func playLubDub() {
        let device = WKInterfaceDevice.current()
        device.play(.click)
        Task { [lubDubGap] in
            try? await Task.sleep(nanoseconds: UInt64(lubDubGap * 1_000_000_000))
            guard !Task.isCancelled else { return }
            WKInterfaceDevice.current().play(.click)
        }
    }
}
