import Foundation

// MARK: - Types

public enum SleepStage: Sendable {
    case inBed
    case awake
    case core
    case deep
    case rem
    case unspecified
}

public struct SleepSample: Sendable {
    public let stage: SleepStage
    public let start: Date
    public let end: Date

    public init(stage: SleepStage, start: Date, end: Date) {
        self.stage = stage
        self.start = start
        self.end = end
    }
}

// MARK: - SleepAnalyzer

public struct SleepAnalyzer {
    public init() {}

    public func analyze(samples: [SleepSample], calendar: Calendar = .current) -> SleepBreakdown? {
        guard !samples.isEmpty else { return nil }

        // Separate samples by stage
        let inBedSamples = samples.filter { $0.stage == .inBed }
        let awakeSamples = samples.filter { $0.stage == .awake }
        let coreSamples = samples.filter { $0.stage == .core }
        let deepSamples = samples.filter { $0.stage == .deep }
        let remSamples = samples.filter { $0.stage == .rem }
        let unspecifiedSamples = samples.filter { $0.stage == .unspecified }

        // Calculate durations for each stage
        let lightSleepMinutes = (coreSamples.map { durationInMinutes(from: $0.start, to: $0.end) }.reduce(0, +))
        let deepSleepMinutes = deepSamples.map { durationInMinutes(from: $0.start, to: $0.end) }.reduce(0, +)
        let remMinutes = remSamples.map { durationInMinutes(from: $0.start, to: $0.end) }.reduce(0, +)
        let unspecifiedMinutes = unspecifiedSamples.map { durationInMinutes(from: $0.start, to: $0.end) }.reduce(0, +)

        // Total sleep = light + deep + rem + unspecified
        let totalSleepMinutes = lightSleepMinutes + deepSleepMinutes + remMinutes + unspecifiedMinutes

        // Calculate awake minutes and late night wake minutes
        var awakeMinutes: Double = 0
        var lateNightWakeMinutes: Double = 0

        if !awakeSamples.isEmpty {
            // Find the latest sample's end date to determine the "wake day"
            let latestSampleEnd = samples.max(by: { $0.end < $1.end })?.end ?? Date()
            let wakeDayMidnight = calendar.startOfDay(for: latestSampleEnd)

            for sample in awakeSamples {
                let duration = durationInMinutes(from: sample.start, to: sample.end)
                awakeMinutes += duration

                // Check if sample starts after midnight of the wake day
                if sample.start >= wakeDayMidnight {
                    lateNightWakeMinutes += duration
                }
            }
        }

        // Calculate bedtime (earliest sample start)
        let bedtime = samples.min(by: { $0.start < $1.start })?.start

        // Calculate wakeTime (latest asleep-sample end)
        // Asleep stages are: core, deep, rem, unspecified (not inBed, not awake)
        let asleepSamples = samples.filter { sample in
            switch sample.stage {
            case .core, .deep, .rem, .unspecified:
                return true
            case .inBed, .awake:
                return false
            }
        }
        let wakeTime = asleepSamples.max(by: { $0.end < $1.end })?.end

        // Calculate inBedMinutes
        let inBedMinutes: Double
        if inBedSamples.isEmpty {
            // Fall back to span from bedtime to wakeTime
            if let bedtime = bedtime, let wakeTime = wakeTime {
                inBedMinutes = durationInMinutes(from: bedtime, to: wakeTime)
            } else {
                inBedMinutes = 0
            }
        } else {
            inBedMinutes = inBedSamples.map { durationInMinutes(from: $0.start, to: $0.end) }.reduce(0, +)
        }

        // Calculate sleep onset minutes
        let sleepOnsetMinutes: Double
        if let firstInBedStart = inBedSamples.min(by: { $0.start < $1.start })?.start,
           let firstAsleepStart = asleepSamples.min(by: { $0.start < $1.start })?.start {
            sleepOnsetMinutes = durationInMinutes(from: firstInBedStart, to: firstAsleepStart)
        } else {
            sleepOnsetMinutes = 0
        }

        return SleepBreakdown(
            inBedMinutes: inBedMinutes,
            totalSleepMinutes: totalSleepMinutes,
            deepSleepMinutes: deepSleepMinutes,
            remMinutes: remMinutes,
            lightSleepMinutes: lightSleepMinutes,
            awakeMinutes: awakeMinutes,
            lateNightWakeMinutes: lateNightWakeMinutes,
            sleepOnsetMinutes: sleepOnsetMinutes,
            bedtime: bedtime,
            wakeTime: wakeTime
        )
    }

    private func durationInMinutes(from start: Date, to end: Date) -> Double {
        return end.timeIntervalSince(start) / 60.0
    }
}
