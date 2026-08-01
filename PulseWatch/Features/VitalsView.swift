import SwiftUI
import PulseShared

// MARK: - VitalsView

struct VitalsView: View {
    @Environment(WatchState.self) private var watchState
    @StateObject private var engine = WatchHealthEngine.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR VITALS")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 4)

                // 3×2 metric grid
                metricGrid

                // Freshness line
                freshnessLine
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
        .background(Color.psDeepNavy.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        if !engine.isAuthorized {
                            await engine.requestAuthorization()
                        } else {
                            await engine.refreshMetrics()
                        }
                    }
                } label: {
                    Image(systemName: engine.isFetching ? "arrow.clockwise" : "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .disabled(engine.isFetching)
            }
        }
    }

    // MARK: - Metric Grid

    @ViewBuilder
    private var metricGrid: some View {
        let summary = watchState.healthSummary
        let local = engine.snapshot

        VStack(spacing: 6) {
            HStack(spacing: 6) {
                MetricTile(
                    icon: "♥",
                    label: "Heart Rate",
                    value: resolvedHeartRate(summary: summary, local: local),
                    unit: "bpm",
                    quality: resolvedHRQuality(summary: summary, local: local)
                )
                MetricTile(
                    icon: "📊",
                    label: "HRV",
                    value: resolvedHRV(summary: summary, local: local),
                    unit: "ms",
                    quality: resolvedHRVQuality(summary: summary, local: local)
                )
            }
            HStack(spacing: 6) {
                MetricTile(
                    icon: "🫁",
                    label: "Oxygen",
                    value: resolvedSpO2(summary: summary, local: local),
                    unit: "%",
                    quality: resolvedSpO2Quality(summary: summary, local: local)
                )
                MetricTile(
                    icon: "🌙",
                    label: "Sleep Eff.",
                    value: summary.flatMap { $0.sleepEfficiency.map { String(format: "%.0f", $0 * 100) } },
                    unit: "%",
                    quality: summary?.sleepEfficiency.map { HealthQuality.forSleepEfficiency($0) }
                )
            }
            HStack(spacing: 6) {
                MetricTile(
                    icon: "🏃",
                    label: "Steps",
                    value: resolvedSteps(summary: summary, local: local),
                    unit: nil,
                    quality: nil
                )
                // Spacer tile
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Resolved Metrics (watch-local wins when fresher)

    private func resolvedHeartRate(summary: WatchMessage.HealthSummaryPayload?, local: WatchHealthSnapshot?) -> String? {
        if let localHR = local?.heartRate {
            return String(format: "%.0f", localHR)
        }
        return summary?.heartRate.map { String(format: "%.0f", $0) }
    }

    private func resolvedHRQuality(summary: WatchMessage.HealthSummaryPayload?, local: WatchHealthSnapshot?) -> HealthQuality? {
        let hr = local?.heartRate ?? summary?.heartRate
        guard let hr else { return .unavailable }
        return HealthQuality.forHeartRate(hr, restingBPM: 65)
    }

    private func resolvedHRV(summary: WatchMessage.HealthSummaryPayload?, local: WatchHealthSnapshot?) -> String? {
        if let localHRV = local?.hrv {
            return String(format: "%.0f", localHRV)
        }
        return summary?.hrv.map { String(format: "%.0f", $0) }
    }

    private func resolvedHRVQuality(summary: WatchMessage.HealthSummaryPayload?, local: WatchHealthSnapshot?) -> HealthQuality? {
        let hrv = local?.hrv ?? summary?.hrv
        guard let hrv else { return .unavailable }
        return HealthQuality.forHRV(hrv)
    }

    private func resolvedSpO2(summary: WatchMessage.HealthSummaryPayload?, local: WatchHealthSnapshot?) -> String? {
        if let localSpo2 = local?.oxygenSaturation {
            return String(format: "%.0f", localSpo2 * 100)
        }
        return summary?.oxygenSaturation.map { String(format: "%.0f", $0 * 100) }
    }

    private func resolvedSpO2Quality(summary: WatchMessage.HealthSummaryPayload?, local: WatchHealthSnapshot?) -> HealthQuality? {
        let spo2 = local?.oxygenSaturation ?? summary?.oxygenSaturation
        guard let spo2 else { return .unavailable }
        return HealthQuality.forOxygen(spo2)
    }

    private func resolvedSteps(summary: WatchMessage.HealthSummaryPayload?, local: WatchHealthSnapshot?) -> String? {
        if let localSteps = local?.stepCount {
            return "\(localSteps.formatted())"
        }
        return summary?.stepCount.map { "\($0.formatted())" }
    }

    // MARK: - Freshness Line

    @ViewBuilder
    private var freshnessLine: some View {
        let lastUpdated: Date? = {
            if let localSnap = engine.snapshot {
                return localSnap.fetchedAt
            }
            if let ts = watchState.healthSummary?.lastUpdated {
                return Date(timeIntervalSince1970: ts)
            }
            return nil
        }()

        if let updated = lastUpdated {
            let minutes = Int(Date().timeIntervalSince(updated) / 60)
            let color: Color = minutes < 5 ? .psSuccess : minutes < 15 ? .psWarning : .psAlert
            let label: String = {
                if minutes < 1 { return "Updated just now" }
                return "Updated \(minutes)m ago"
            }()
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(color)
        } else {
            Text("No data yet")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.psGrayMuted)
        }
    }
}

// MARK: - MetricTile

private struct MetricTile: View {
    let icon: String
    let label: String
    let value: String?
    let unit: String?
    let quality: HealthQuality?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Circle()
                    .fill(quality?.color ?? Color.psGrayMuted)
                    .frame(width: 6, height: 6)
                Text(icon)
                    .font(.system(size: 12))
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value ?? "—")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                if let unit, value != nil {
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.psNavy.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
