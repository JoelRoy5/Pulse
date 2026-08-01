import Foundation

/// Adaptive heartbeat model that eases from a start BPM down to a calm target BPM over a session.
public struct PrayerCadence: Sendable {
    public let clampedStartBPM: Double
    public let clampedTargetBPM: Double
    public let durationSeconds: Double

    /// Initializes a PrayerCadence with adaptive heartbeat parameters.
    ///
    /// - Parameters:
    ///   - startBPM: Initial BPM; clamped to [50, 120]
    ///   - targetBPM: Desired end BPM; clamped to [50, start]
    ///   - durationSeconds: Session duration; minimum 1 second
    public init(startBPM: Double, targetBPM: Double, durationSeconds: Double) {
        // Clamp start: [50, 120]
        self.clampedStartBPM = min(max(startBPM, 50), 120)

        // Clamp target: [50, start] (target never above start, never below 50)
        self.clampedTargetBPM = max(min(targetBPM, self.clampedStartBPM), 50)

        // Duration minimum 1 second
        self.durationSeconds = max(durationSeconds, 1)
    }

    /// Returns the BPM at a given elapsed time using ease-out cubic easing.
    ///
    /// The BPM eases from startBPM to targetBPM over the duration using cubic ease-out.
    /// Progress is clamped to [0, 1] and the result is clamped to [targetBPM, startBPM].
    ///
    /// - Parameter elapsed: Elapsed time in seconds
    /// - Returns: BPM at the given elapsed time
    public func bpm(atElapsed elapsed: Double) -> Double {
        // Calculate normalized progress [0, 1]
        let progress = min(max(elapsed / durationSeconds, 0), 1)

        // Ease-out cubic: 1 - (1 - progress)^3
        let eased = 1 - pow(1 - progress, 3)

        // Interpolate from start to target
        let result = clampedStartBPM + (clampedTargetBPM - clampedStartBPM) * eased

        // Clamp result to [target, start]
        return min(max(result, clampedTargetBPM), clampedStartBPM)
    }

    /// Returns the beat interval (time between beats) at a given elapsed time.
    ///
    /// - Parameter elapsed: Elapsed time in seconds
    /// - Returns: Beat interval in seconds (60.0 / BPM)
    public func beatInterval(atElapsed elapsed: Double) -> TimeInterval {
        60.0 / bpm(atElapsed: elapsed)
    }
}
