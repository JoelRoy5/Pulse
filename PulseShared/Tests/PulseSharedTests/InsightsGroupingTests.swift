import XCTest
@testable import PulseShared

final class InsightsGroupingTests: XCTestCase {

    private let cal = Calendar(identifier: .gregorian)

    private func entry(_ day: Int, _ emotion: String, fallback: Bool = false) -> ClassificationEntry {
        var c = DateComponents(); c.year = 2026; c.month = 8; c.day = day; c.hour = 9
        return ClassificationEntry(date: cal.date(from: c)!, emotionRaw: emotion,
                                   confidence: fallback ? 0.5 : 0.8, wasNeutralFallback: fallback, signalsPresent: ["hrv"])
    }

    func testGroupsByDayPickingMostRecentNonFallback() {
        let entries = [
            entry(3, "steady", fallback: true),   // earlier, neutral
            entry(3, "stressed"),                 // later, real → representative
            entry(2, "drained")
        ]
        let groups = InsightsGrouping.byDay(entries, calendar: cal)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.first?.emotionRaw, "stressed")   // most recent day first
        XCTAssertEqual(groups.first?.isNeutral, false)
    }

    func testDayWithOnlyFallbackIsNeutral() {
        let groups = InsightsGrouping.byDay([entry(5, "steady", fallback: true)], calendar: cal)
        XCTAssertEqual(groups.first?.isNeutral, true)
    }

    func testEmptyEntriesYieldNoGroups() {
        XCTAssertTrue(InsightsGrouping.byDay([], calendar: cal).isEmpty)
    }

    func testSignalLabelIsHumanReadable() {
        XCTAssertEqual(InsightsGrouping.signalLabel("hrv"), "HRV")
        XCTAssertEqual(InsightsGrouping.signalLabel("hrRecovery"), "HR recovery")
    }

    func testSelfReportEventIsNeutral() {
        let e = AnalyticsEvent.insightsSelfReportTapped
        XCTAssertEqual(e.name, "insights_self_report_tapped")
        XCTAssertTrue(e.properties.isEmpty)
    }
}
