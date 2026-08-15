import XCTest
@testable import PulseShared

final class StreakCalculatorTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)
    private func d(_ y: Int, _ m: Int, _ day: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: day, hour: 12))!
    }
    private let calc = StreakCalculator()

    func testEmptyIsZero() {
        XCTAssertEqual(calc.currentStreak(engagementDates: [], today: d(2026,1,15), calendar: cal), 0)
    }
    func testTodayOnlyIsOne() {
        XCTAssertEqual(calc.currentStreak(engagementDates: [d(2026,1,15)], today: d(2026,1,15), calendar: cal), 1)
    }
    func testThreeConsecutiveEndingToday() {
        let dates = [d(2026,1,13), d(2026,1,14), d(2026,1,15)]
        XCTAssertEqual(calc.currentStreak(engagementDates: dates, today: d(2026,1,15), calendar: cal), 3)
    }
    func testYesterdayGraceWithoutToday() {
        let dates = [d(2026,1,13), d(2026,1,14)]  // no today (15th)
        XCTAssertEqual(calc.currentStreak(engagementDates: dates, today: d(2026,1,15), calendar: cal), 2)
    }
    func testGapResets() {
        let dates = [d(2026,1,10), d(2026,1,11), d(2026,1,15)]  // gap; only today
        XCTAssertEqual(calc.currentStreak(engagementDates: dates, today: d(2026,1,15), calendar: cal), 1)
    }
    func testStaleStreakIsZero() {
        let dates = [d(2026,1,10), d(2026,1,11)]  // neither today nor yesterday
        XCTAssertEqual(calc.currentStreak(engagementDates: dates, today: d(2026,1,15), calendar: cal), 0)
    }
    func testMultiplePerDayCountOnce() {
        let dates = [d(2026,1,14), d(2026,1,14), d(2026,1,15), d(2026,1,15)]
        XCTAssertEqual(calc.currentStreak(engagementDates: dates, today: d(2026,1,15), calendar: cal), 2)
    }
    func testMonthEngagement() {
        let dates = [d(2026,1,2), d(2026,1,2), d(2026,1,10), d(2025,12,31)]
        let r = calc.daysEngagedThisMonth(engagementDates: dates, today: d(2026,1,15), calendar: cal)
        XCTAssertEqual(r.engaged, 2)   // Jan 2 (dedup) + Jan 10
        XCTAssertEqual(r.total, 15)    // through the 15th
    }
}
