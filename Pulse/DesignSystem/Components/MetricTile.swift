import SwiftUI
import PulseShared

struct MetricTile: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let quality: HealthQuality
    let action: (() -> Void)?

    var body: some View {
        if let action {
            // When action is provided, use a button
            Button(action: action) {
                tileContent
            }
        } else {
            // When action is nil, use a plain container
            tileContent
        }
    }

    private var tileContent: some View {
        VStack(spacing: PSSpacing.xs) {
            HStack(spacing: 4) {
                Circle()
                    .fill(quality.color)
                    .frame(width: 6, height: 6)
                Text(icon)
                    .font(.system(size: 16))
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(PSFont.metric(size: 24))
                    .foregroundStyle(Color.psWhite)
                Text(unit)
                    .font(PSFont.label(size: 11))
                    .foregroundStyle(Color.psGrayMuted)
            }

            Text(label)
                .font(PSFont.label(size: 11))
                .foregroundStyle(Color.psGrayMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(PSSpacing.md)
        .background(Color.psNavy)
        .clipShape(RoundedRectangle(cornerRadius: PSRadius.md))
        .accessibilityLabel("\(label): \(value) \(unit)")
    }
}

#Preview {
    ZStack {
        Color.psDeepNavy
            .ignoresSafeArea()

        VStack(spacing: 16) {
            Text("Metric Tiles")
                .font(PSFont.label(size: 16, weight: .semibold))
                .foregroundStyle(Color.psWhite)

            // Tile with action (good quality)
            MetricTile(
                icon: "❤️",
                value: "72",
                unit: "bpm",
                label: "Heart Rate",
                quality: .good,
                action: { print("Heart rate tapped") }
            )

            // Tile with action (fair quality)
            MetricTile(
                icon: "📊",
                value: "42",
                unit: "ms",
                label: "Heart Rate Variability",
                quality: .fair,
                action: { print("HRV tapped") }
            )

            // Tile with action (poor quality)
            MetricTile(
                icon: "💨",
                value: "94",
                unit: "%",
                label: "Oxygen Saturation",
                quality: .poor,
                action: { print("SpO2 tapped") }
            )

            // Tile without action (unavailable)
            MetricTile(
                icon: "😴",
                value: "—",
                unit: "",
                label: "Sleep Score",
                quality: .unavailable,
                action: nil
            )

            Spacer()
        }
        .padding(PSSpacing.screenHorizontal)
    }
}
