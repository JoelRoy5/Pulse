import SwiftUI
import PulseShared

// MARK: - MetricsGridView

/// 2×3 grid of health metric tiles. Taps are no-op (sparkline = Phase 2).
struct MetricsGridView: View {
    let snapshot: HealthSnapshot?

    private var hr: MetricData {
        guard let v = snapshot?.heartRate else { return .unavailable }
        let quality = HealthQuality.forHeartRate(v, restingBPM: snapshot?.restingHeartRate)
        return MetricData(icon: "heart.fill", value: "\(Int(v))", unit: "bpm", label: "Heart Rate", quality: quality)
    }

    private var hrv: MetricData {
        guard let v = snapshot?.heartRateVariability else { return .unavailable }
        return MetricData(icon: "waveform.path.ecg", value: "\(Int(v))", unit: "ms", label: "HRV", quality: HealthQuality.forHRV(v))
    }

    private var spo2: MetricData {
        guard let v = snapshot?.oxygenSaturation else { return .unavailable }
        return MetricData(icon: "lungs.fill", value: "\(Int(v * 100))", unit: "%", label: "Oxygen", quality: HealthQuality.forOxygen(v))
    }

    private var sleepEff: MetricData {
        guard let v = snapshot?.sleepEfficiency else { return .unavailable }
        return MetricData(icon: "moon.fill", value: "\(Int(v * 100))", unit: "%", label: "Sleep Eff.", quality: HealthQuality.forSleepEfficiency(v))
    }

    private var steps: MetricData {
        guard let v = snapshot?.stepCount else { return .unavailable }
        let quality: HealthQuality = v >= 10000 ? .good : v >= 5000 ? .fair : .poor
        return MetricData(icon: "figure.walk", value: "\(v.formatted())", unit: "", label: "Steps", quality: quality)
    }

    private var totalSleep: MetricData {
        guard let v = snapshot?.totalSleepMinutes else { return .unavailable }
        let hours = Int(v) / 60
        let mins = Int(v) % 60
        let label = mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        let quality: HealthQuality = v >= 420 ? .good : v >= 360 ? .fair : .poor
        return MetricData(icon: "bed.double.fill", value: label, unit: "", label: "Total Sleep", quality: quality)
    }

    private var tiles: [[MetricData]] {
        [
            [hr, hrv, spo2],
            [sleepEff, steps, totalSleep]
        ]
    }

    var body: some View {
        VStack(spacing: PSSpacing.sm) {
            ForEach(Array(tiles.enumerated()), id: \.offset) { _, row in
                HStack(spacing: PSSpacing.sm) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, tile in
                        MetricTile(
                            icon: tile.icon,
                            value: tile.value,
                            unit: tile.unit,
                            label: tile.label,
                            quality: tile.quality,
                            action: nil  // Phase 2: sparkline
                        )
                    }
                }
            }
        }
    }
}

// MARK: - MetricData

private struct MetricData {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let quality: HealthQuality

    static var unavailable: MetricData {
        MetricData(icon: "questionmark", value: "—", unit: "", label: "—", quality: .unavailable)
    }
}

#Preview {
    ZStack {
        Color.psDeepNavy.ignoresSafeArea()
        MetricsGridView(snapshot: HealthSnapshot(
            heartRate: 72,
            heartRateVariability: 48,
            restingHeartRate: 58,
            oxygenSaturation: 0.97,
            sleepEfficiency: 0.81,
            totalSleepMinutes: 440,
            stepCount: 4234
        ))
        .padding(PSSpacing.screenHorizontal)
    }
}
