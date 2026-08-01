import SwiftUI
import PulseShared

// MARK: - StateBannerCard

struct StateBannerCard: View {
    let state: BiometricState
    let confidence: Double
    let snapshot: HealthSnapshot?

    var body: some View {
        PSCard(style: .state(state)) {
            VStack(alignment: .leading, spacing: PSSpacing.sm) {

                // Row 1: emoji + state name + confidence
                HStack(alignment: .firstTextBaseline) {
                    Text(state.emoji)
                        .font(.system(size: 32))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.displayName.uppercased())
                            .font(PSFont.label(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .kerning(1.2)
                        Text(state.bodyInterpretation)
                            .font(PSFont.label(size: 13))
                            .foregroundStyle(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Text("\(Int(confidence * 100))%")
                        .font(PSFont.label(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }

                // Row 2: metric chips
                if let snapshot {
                    MetricChipsRow(snapshot: snapshot)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(state.displayName), \(Int(confidence * 100))% match. \(state.bodyInterpretation)")
    }
}

// MARK: - MetricChipsRow

private struct MetricChipsRow: View {
    let snapshot: HealthSnapshot

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PSSpacing.sm) {
                if let hr = snapshot.heartRate {
                    MetricChip(icon: "♥", value: "\(Int(hr))", unit: "bpm")
                }
                if let hrv = snapshot.heartRateVariability {
                    MetricChip(icon: "〜", value: "\(Int(hrv))", unit: "ms HRV")
                }
                if let sleep = snapshot.sleepEfficiency {
                    MetricChip(icon: "🌙", value: "\(Int(sleep * 100))", unit: "% Sleep")
                }
                if let spo2 = snapshot.oxygenSaturation {
                    MetricChip(icon: "🫁", value: "\(Int(spo2 * 100))", unit: "% O₂")
                }
            }
        }
    }
}

// MARK: - MetricChip

private struct MetricChip: View {
    let icon: String
    let value: String
    let unit: String

    var body: some View {
        HStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 13))
            Text(value)
                .font(PSFont.metric(size: 13))
                .foregroundStyle(.white)
            Text(unit)
                .font(PSFont.label(size: 11))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, PSSpacing.sm)
        .padding(.vertical, PSSpacing.xs)
        .background(.white.opacity(0.15))
        .clipShape(Capsule())
    }
}

#Preview {
    ZStack {
        Color.psDeepNavy.ignoresSafeArea()
        StateBannerCard(
            state: .exhaustedDepleted,
            confidence: 0.87,
            snapshot: HealthSnapshot(
                heartRate: 58,
                heartRateVariability: 31,
                oxygenSaturation: 0.97,
                sleepEfficiency: 0.68
            )
        )
        .padding(PSSpacing.screenHorizontal)
    }
}
