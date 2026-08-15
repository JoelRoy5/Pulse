import SwiftUI
import PulseShared

// MARK: - StreakWidget

/// Displays the user's current engagement streak and monthly progress bar.
struct StreakWidget: View {
    let engagementDates: [Date]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Computed

    private var calculator: StreakCalculator { StreakCalculator() }

    private var streak: Int {
        calculator.currentStreak(engagementDates: engagementDates, today: .now)
    }

    private var monthStats: (engaged: Int, total: Int) {
        calculator.daysEngagedThisMonth(engagementDates: engagementDates, today: .now)
    }

    private var encouragementMessage: String {
        switch streak {
        case 0:
            return "Open a verse today to begin your streak."
        case 1:
            return "Great start — come back tomorrow to keep it going!"
        case 2...6:
            return "You've engaged with Scripture every day this week."
        case 7...13:
            return "A full week of daily engagement — well done."
        case 14...29:
            return "Two strong weeks of consistent Scripture time."
        default:
            return "An incredible habit — \(streak) days of daily Scripture."
        }
    }

    // MARK: - Body

    var body: some View {
        PSCard(style: .standard) {
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                // Title row
                if streak == 0 {
                    Text("Start your streak — your first verse today")
                        .font(PSFont.label(size: 17, weight: .semibold))
                        .foregroundStyle(Color.psWhite)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.psAccentLight)
                        Text("\(streak)-Day Streak")
                            .font(PSFont.label(size: 20, weight: .bold))
                            .foregroundStyle(Color.psAccentLight)
                    }
                }

                // Encouragement
                Text(encouragementMessage)
                    .font(PSFont.label(size: 14))
                    .foregroundStyle(Color.psGrayMuted)
                    .fixedSize(horizontal: false, vertical: true)

                // Month progress bar
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    ProgressView(
                        value: Double(monthStats.engaged),
                        total: Double(max(monthStats.total, 1))
                    )
                    .tint(Color.psAccent)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: monthStats.engaged)

                    Text("\(monthStats.engaged) of \(monthStats.total) days this month")
                        .font(PSFont.label(size: 12))
                        .foregroundStyle(Color.psGrayMuted)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Active Streak") {
    let calendar = Calendar.current
    let today = Date.now
    // Build sample dates: today + 6 previous days = 7-day streak, some earlier in month
    var sampleDates: [Date] = []
    for offset in 0..<7 {
        if let d = calendar.date(byAdding: .day, value: -offset, to: today) {
            sampleDates.append(d)
        }
    }
    // Add a few earlier this month but not consecutive
    if let earlier = calendar.date(byAdding: .day, value: -10, to: today) {
        sampleDates.append(earlier)
    }
    if let earlier = calendar.date(byAdding: .day, value: -12, to: today) {
        sampleDates.append(earlier)
    }

    return ZStack {
        Color.psDeepNavy.ignoresSafeArea()
        VStack(spacing: PSSpacing.md) {
            StreakWidget(engagementDates: sampleDates)

            // Zero state
            StreakWidget(engagementDates: [])
        }
        .padding(PSSpacing.screenHorizontal)
    }
}

#Preview("Zero State") {
    ZStack {
        Color.psDeepNavy.ignoresSafeArea()
        StreakWidget(engagementDates: [])
            .padding(PSSpacing.screenHorizontal)
    }
}
