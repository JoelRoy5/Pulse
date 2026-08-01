import Foundation

/// Computes consecutive-day engagement streaks and monthly engagement statistics.
public struct StreakCalculator: Sendable {
    /// Initializes a StreakCalculator.
    public init() {}

    /// Calculates the current consecutive-day engagement streak.
    ///
    /// The streak counts consecutive calendar days with ≥1 engagement, ending today OR yesterday.
    /// "Yesterday grace" rule: if there is engagement yesterday but not yet today, the streak still stands
    /// and includes through yesterday.
    ///
    /// Algorithm:
    /// 1. Reduce engagement dates to a set of `startOfDay` values.
    /// 2. If neither today nor yesterday is in the set, return 0.
    /// 3. Start the walk at today if present, else yesterday; step back one day while the day is in the set.
    /// 4. Return the count of consecutive days walked.
    ///
    /// - Parameters:
    ///   - engagementDates: Array of dates with engagement activity
    ///   - today: The reference date (explicit, not wall-clock now)
    ///   - calendar: Calendar for date arithmetic; default is `.current`
    /// - Returns: Count of consecutive calendar days in the streak
    public func currentStreak(
        engagementDates: [Date],
        today: Date,
        calendar: Calendar = .current
    ) -> Int {
        // Reduce to a set of startOfDay dates
        let engagedDays = Set(engagementDates.map { calendar.startOfDay(for: $0) })

        // Get startOfDay for today and yesterday
        let todayStart = calendar.startOfDay(for: today)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart)!
        let yesterdayStart = calendar.startOfDay(for: yesterday)

        // If neither today nor yesterday has engagement, streak is 0
        guard engagedDays.contains(todayStart) || engagedDays.contains(yesterdayStart) else {
            return 0
        }

        // Start walk from today if present, else yesterday
        var currentDay = engagedDays.contains(todayStart) ? todayStart : yesterdayStart
        var count = 0

        // Step back while the day is in the set
        while engagedDays.contains(currentDay) {
            count += 1
            let previous = calendar.date(byAdding: .day, value: -1, to: currentDay)!
            currentDay = calendar.startOfDay(for: previous)
        }

        return count
    }

    /// Calculates days engaged this month and total days elapsed this month.
    ///
    /// - Parameters:
    ///   - engagementDates: Array of dates with engagement activity
    ///   - today: The reference date (explicit, not wall-clock now)
    ///   - calendar: Calendar for date arithmetic; default is `.current`
    /// - Returns: Tuple with `engaged` (distinct days in today's month with engagement) and `total` (today's day-of-month)
    public func daysEngagedThisMonth(
        engagementDates: [Date],
        today: Date,
        calendar: Calendar = .current
    ) -> (engaged: Int, total: Int) {
        let todayStart = calendar.startOfDay(for: today)

        // Get today's month and year components
        let todayComponents = calendar.dateComponents([.year, .month], from: todayStart)
        let todayYear = todayComponents.year!
        let todayMonth = todayComponents.month!

        // Get today's day-of-month for total
        let todayDayComponent = calendar.dateComponents([.day], from: todayStart)
        let total = todayDayComponent.day!

        // Reduce to set of startOfDay dates and filter to this month
        let engagedDays = Set(engagementDates.map { calendar.startOfDay(for: $0) })
        var engagedThisMonth = Set<Date>()

        for date in engagedDays {
            let components = calendar.dateComponents([.year, .month], from: date)
            if components.year == todayYear && components.month == todayMonth {
                engagedThisMonth.insert(date)
            }
        }

        return (engaged: engagedThisMonth.count, total: total)
    }
}
