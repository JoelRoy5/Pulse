# Signal Expansion + Insights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add temperature (wired into `sick` detection) plus Time-in-Daylight and Heart-Rate-Recovery (observe-only), record every classification on-device, replace the "Journey" tab with an Insights view, and prompt for self-report when data is too thin to classify.

**Architecture:** Testable decision logic lives in `PulseShared` (unit-tested): new `HealthSnapshot` fields, the classifier's temperature term, signal-presence/insufficient-data helpers, Insights grouping, and the new analytics events. Thin app-target glue is build/simctl-verified: HealthKit collectors, a `ClassificationRecord` SwiftData model + recorder, the `HealthEngine` hook, and the SwiftUI views (Insights tab, Home prompt).

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData, HealthKit, XCTest, XcodeGen.

## Global Constraints

- **Graceful degradation:** every new signal is optional. A missing signal is `nil`, never an error, and never blocks classification. Temperature absent ⇒ `sickConfidence` is byte-for-byte today's value.
- **Observe-first:** Time-in-Daylight and Heart-Rate-Recovery are collected and recorded but MUST NOT enter any confidence function this spec.
- **`sick` gate unchanged:** `sickConfidence` still requires both `restingHeartRate` and `respiratoryRate` present; temperature refines, never opens a new path. Temperature alone must never fabricate a `sick` verdict.
- **Temperature thresholds (verbatim):** body-temp fever `feverScore = clamp((temp − 37.5)/1.5, 0, 1)`. Wrist-temp deviation `clamp((dev − 0.5)/1.0, 0, 1)`, requiring ≥ 3 baseline nights; `dev = wristTemp − baselineMean`. Combined `feverScore = max(available)`, `nil` when no temperature present. Blend into sick only when `feverScore > 0`: `raw = base*0.75 + feverScore*0.25`, else `raw = base`; then `min(1, raw*1.15)`.
- **`insufficientData`** = none of HRV, sleep (efficiency or total minutes), or resting HR present.
- **`wasNeutralFallback`** = `confidence < 0.65` (the classifier returns 0.5 for the time-of-day fallback and ≥ 0.65 for a real state).
- **Insights shows the user-facing `Emotion`**, never the raw 12-state `BiometricState`.
- **Analytics guardrail (`CLAUDE.md`):** new screen ⇒ `.trackScreen("Insights")`; new action ⇒ an `AnalyticsEvent` case with neutral properties only. `ClassificationRecord`, the Insights view, and all temperature values stay on-device; never send health metrics, state classification, temperature, or verse content to analytics.
- **Retention:** prune `ClassificationRecord` older than 90 days on write.
- **App target has no unit-test target.** Put testable logic in `PulseShared`; verify app-target changes with `xcodegen generate` + `xcodebuild ... build` (and simctl where a screen is added).

**Deferred (do NOT build here):** event-triggered deliveries / inferred workouts / notification cadence; State of Mind; menstrual cycle; "Stressed" tuning; wiring Daylight/HR-recovery into confidence.

---

## File Structure

- `PulseShared/Sources/PulseShared/Models/HealthSnapshot.swift` — **modify**: 3 new optional fields.
- `PulseShared/Sources/PulseShared/Logic/ClassificationSignals.swift` — **create**: `insufficientData`, `signalsPresent`, `shouldPromptSelfReport`, `TemperatureBaseline.mean`.
- `PulseShared/Sources/PulseShared/Logic/StateClassifier.swift` — **modify**: temperature term + `classify` baseline param.
- `PulseShared/Sources/PulseShared/Logic/InsightsGrouping.swift` — **create**: `ClassificationEntry`, `DayGroup`, `InsightsGrouping.byDay`, signal/emotion labels.
- `PulseShared/Sources/PulseShared/Analytics/AnalyticsEvent.swift` — **modify**: `insightsSelfReportTapped` event.
- `Pulse/Core/Health/MetricCollector.swift` — **modify**: 3 collectors + readTypes + toggles + assembly.
- `Pulse/Core/Persistence/ClassificationRecord.swift` — **create**: SwiftData `@Model`.
- `Pulse/Core/Persistence/ModelContainer+Setup.swift` — **modify**: register the model.
- `Pulse/Core/Health/ClassificationRecorder.swift` — **create**: build/insert/prune records, wrist-temp baseline.
- `Pulse/Core/Health/HealthEngine.swift` — **modify**: compute baseline, pass to `classify`, record result.
- `Pulse/App/PulseApp.swift` — **modify**: inject the recorder into `HealthEngine`.
- `Pulse/Features/Insights/InsightsView.swift` — **create**: the Insights tab UI.
- `Pulse/Features/MainTabView.swift` — **modify**: replace Journey tab with Insights.
- `Pulse/Features/Home/HomeView.swift` — **modify**: low-data self-report prompt.

Test files under `PulseShared/Tests/PulseSharedTests/`.

---

### Task 1: New `HealthSnapshot` fields + signal helpers

**Files:**
- Modify: `PulseShared/Sources/PulseShared/Models/HealthSnapshot.swift`
- Create: `PulseShared/Sources/PulseShared/Logic/ClassificationSignals.swift`
- Test: `PulseShared/Tests/PulseSharedTests/ClassificationSignalsTests.swift`

**Interfaces:**
- Produces on `HealthSnapshot`: `sleepingWristTemperature: Double?`, `timeInDaylightMinutes: Double?`, `heartRateRecoveryBPM: Double?` (init params appended, defaulting `nil`).
- Produces `enum ClassificationSignals`: `static func insufficientData(_ s: HealthSnapshot) -> Bool`, `static func signalsPresent(_ s: HealthSnapshot) -> [String]`, `static func shouldPromptSelfReport(latestInsufficientData: Bool?) -> Bool`.
- Produces `enum TemperatureBaseline`: `static func mean(of values: [Double]) -> (mean: Double, count: Int)?`.

- [ ] **Step 1: Write the failing tests**

Create `ClassificationSignalsTests.swift`:

```swift
import XCTest
@testable import PulseShared

final class ClassificationSignalsTests: XCTestCase {

    func testSnapshotCarriesNewOptionalFields() {
        let s = HealthSnapshot(
            sleepingWristTemperature: 34.2,
            timeInDaylightMinutes: 45,
            heartRateRecoveryBPM: 32
        )
        XCTAssertEqual(s.sleepingWristTemperature, 34.2)
        XCTAssertEqual(s.timeInDaylightMinutes, 45)
        XCTAssertEqual(s.heartRateRecoveryBPM, 32)
    }

    func testInsufficientDataTrueWhenCoreSignalsAbsent() {
        let s = HealthSnapshot(stepCount: 1000)   // no HRV/sleep/restingHR
        XCTAssertTrue(ClassificationSignals.insufficientData(s))
    }

    func testInsufficientDataFalseWhenAnyCoreSignalPresent() {
        XCTAssertFalse(ClassificationSignals.insufficientData(HealthSnapshot(heartRateVariability: 40)))
        XCTAssertFalse(ClassificationSignals.insufficientData(HealthSnapshot(restingHeartRate: 60)))
        XCTAssertFalse(ClassificationSignals.insufficientData(HealthSnapshot(totalSleepMinutes: 400)))
    }

    func testSignalsPresentReflectsSnapshot() {
        let s = HealthSnapshot(heartRateVariability: 40, totalSleepMinutes: 400, bodyTemperature: 37.0)
        let present = Set(ClassificationSignals.signalsPresent(s))
        XCTAssertTrue(present.contains("hrv"))
        XCTAssertTrue(present.contains("sleep"))
        XCTAssertTrue(present.contains("temperature"))
        XCTAssertFalse(present.contains("daylight"))
    }

    func testShouldPromptSelfReport() {
        XCTAssertTrue(ClassificationSignals.shouldPromptSelfReport(latestInsufficientData: true))
        XCTAssertFalse(ClassificationSignals.shouldPromptSelfReport(latestInsufficientData: false))
        XCTAssertFalse(ClassificationSignals.shouldPromptSelfReport(latestInsufficientData: nil))
    }

    func testTemperatureBaselineMean() {
        XCTAssertNil(TemperatureBaseline.mean(of: []))
        let r = TemperatureBaseline.mean(of: [34.0, 34.5, 35.0])
        XCTAssertEqual(r?.count, 3)
        XCTAssertEqual(r?.mean ?? 0, 34.5, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd PulseShared && swift test --filter ClassificationSignalsTests`
Expected: FAIL — new fields / `ClassificationSignals` / `TemperatureBaseline` don't exist.

- [ ] **Step 3: Add the `HealthSnapshot` fields**

In `HealthSnapshot.swift`: add stored properties in the "Vitals"/"Activity" sections:

```swift
    public var sleepingWristTemperature: Double?   // °C, Apple Watch nightly
```
(place near `bodyTemperature`), and

```swift
    public var timeInDaylightMinutes: Double?
    public var heartRateRecoveryBPM: Double?
```
(place near activity fields). Add three params to the initializer **immediately before** `timestamp: Date = .now` and assign them in the body:

```swift
        sleepingWristTemperature: Double? = nil,
        timeInDaylightMinutes: Double? = nil,
        heartRateRecoveryBPM: Double? = nil,
        timestamp: Date = .now,
        dataCompleteness: Double = 0.0
    ) {
        // ... existing assignments ...
        self.sleepingWristTemperature = sleepingWristTemperature
        self.timeInDaylightMinutes = timeInDaylightMinutes
        self.heartRateRecoveryBPM = heartRateRecoveryBPM
        self.timestamp = timestamp
        self.dataCompleteness = dataCompleteness
    }
```

- [ ] **Step 4: Create `ClassificationSignals.swift`**

```swift
import Foundation

/// Pure helpers over `HealthSnapshot` used by the recorder and UI.
public enum ClassificationSignals {

    /// True when none of the state-driving signals are present, so the classifier
    /// cannot meaningfully classify (drives the self-report prompt).
    public static func insufficientData(_ s: HealthSnapshot) -> Bool {
        let hasHRV = s.heartRateVariability != nil
        let hasSleep = s.sleepEfficiency != nil || s.totalSleepMinutes != nil
        let hasRestingHR = s.restingHeartRate != nil
        return !(hasHRV || hasSleep || hasRestingHR)
    }

    /// Compact list of which signals were present, for display + tuning.
    public static func signalsPresent(_ s: HealthSnapshot) -> [String] {
        var out: [String] = []
        if s.heartRateVariability != nil { out.append("hrv") }
        if s.restingHeartRate != nil { out.append("restingHR") }
        if s.sleepEfficiency != nil || s.totalSleepMinutes != nil { out.append("sleep") }
        if s.oxygenSaturation != nil { out.append("spo2") }
        if s.respiratoryRate != nil { out.append("respiration") }
        if s.bodyTemperature != nil || s.sleepingWristTemperature != nil { out.append("temperature") }
        if s.timeInDaylightMinutes != nil { out.append("daylight") }
        if s.heartRateRecoveryBPM != nil { out.append("hrRecovery") }
        if s.stepCount != nil || s.activeEnergyBurned != nil { out.append("activity") }
        return out
    }

    /// Whether Home should surface the "how are you feeling?" prompt.
    public static func shouldPromptSelfReport(latestInsufficientData: Bool?) -> Bool {
        latestInsufficientData == true
    }
}

/// Rolling wrist-temperature baseline.
public enum TemperatureBaseline {
    /// Mean of the provided recent nightly wrist temperatures. Returns nil when empty.
    public static func mean(of values: [Double]) -> (mean: Double, count: Int)? {
        guard !values.isEmpty else { return nil }
        return (values.reduce(0, +) / Double(values.count), values.count)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd PulseShared && swift test --filter ClassificationSignalsTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add PulseShared/Sources/PulseShared/Models/HealthSnapshot.swift PulseShared/Sources/PulseShared/Logic/ClassificationSignals.swift PulseShared/Tests/PulseSharedTests/ClassificationSignalsTests.swift
git commit -m "feat: add temperature/daylight/HR-recovery snapshot fields + signal helpers"
```

---

### Task 2: Temperature → `sick` detection

**Files:**
- Modify: `PulseShared/Sources/PulseShared/Logic/StateClassifier.swift`
- Test: `PulseShared/Tests/PulseSharedTests/StateClassifierTemperatureTests.swift`

**Interfaces:**
- Consumes: `HealthSnapshot` (with new temp fields), `TemperatureBaseline`.
- Produces: `StateClassifier.classify(_:at:calendar:wristTempBaseline:)` — new trailing param `wristTempBaseline: (mean: Double, count: Int)? = nil`. Internal `feverScore(_:wristTempBaseline:) -> Double?`; `sickConfidence` gains a `feverScore: Double?` argument.

- [ ] **Step 1: Write the failing tests**

Create `StateClassifierTemperatureTests.swift`:

```swift
import XCTest
@testable import PulseShared

final class StateClassifierTemperatureTests: XCTestCase {

    private let classifier = StateClassifier()

    /// A snapshot that clears the sick gate (restingHR + respiration present) with
    /// mildly-elevated respiration and low SpO2 so base sick is moderate.
    private func sickBase(bodyTemp: Double? = nil, wristTemp: Double? = nil) -> HealthSnapshot {
        HealthSnapshot(
            heartRateVariability: 25,
            restingHeartRate: 70,
            respiratoryRate: 20,
            oxygenSaturation: 0.95,
            bodyTemperature: bodyTemp,
            sleepingWristTemperature: wristTemp
        )
    }

    func testFeverBodyTempRaisesSick() {
        let scores = classifier.computeSubScores(sickBase())
        let withoutTemp = classifier.sickConfidenceForTest(sickBase(), scores, feverScore: nil)
        let scoresF = classifier.computeSubScores(sickBase(bodyTemp: 38.6))
        let withFever = classifier.sickConfidenceForTest(sickBase(bodyTemp: 38.6), scoresF,
                            feverScore: classifier.feverScoreForTest(sickBase(bodyTemp: 38.6), wristTempBaseline: nil))
        XCTAssertGreaterThan(withFever, withoutTemp)
    }

    func testNormalBodyTempDoesNotInflateSick() {
        let s = sickBase(bodyTemp: 36.8)   // present but not febrile
        let scores = classifier.computeSubScores(s)
        let base = classifier.sickConfidenceForTest(s, scores, feverScore: nil)
        let withNormal = classifier.sickConfidenceForTest(s, scores,
                            feverScore: classifier.feverScoreForTest(s, wristTempBaseline: nil))
        XCTAssertEqual(withNormal, base, accuracy: 0.0001)
    }

    func testTemperatureAbsentIsRegressionSafe() {
        let s = sickBase()
        XCTAssertNil(classifier.feverScoreForTest(s, wristTempBaseline: nil))
    }

    func testWristDeviationRaisesSickWithEnoughBaseline() {
        let s = sickBase(wristTemp: 35.6)               // +1.1 over a 34.5 baseline
        let base = (mean: 34.5, count: 5)
        let fever = classifier.feverScoreForTest(s, wristTempBaseline: base)
        XCTAssertNotNil(fever)
        XCTAssertGreaterThan(fever ?? 0, 0)
    }

    func testWristIgnoredWithoutEnoughBaseline() {
        let s = sickBase(wristTemp: 35.6)
        let base = (mean: 34.5, count: 2)               // < 3 nights
        XCTAssertNil(classifier.feverScoreForTest(s, wristTempBaseline: base))
    }

    func testDaylightAndHRRecoveryDoNotChangeClassification() {
        let plain = HealthSnapshot(heartRateVariability: 55, restingHeartRate: 55, totalSleepMinutes: 450, sleepEfficiency: 0.9)
        let withContext = HealthSnapshot(heartRateVariability: 55, restingHeartRate: 55, totalSleepMinutes: 450, sleepEfficiency: 0.9,
                                         timeInDaylightMinutes: 120, heartRateRecoveryBPM: 40)
        XCTAssertEqual(classifier.classify(plain).state, classifier.classify(withContext).state)
    }
}
```

Note: the tests use small `…ForTest` shims so the private helpers are exercisable. Add them in Step 3.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd PulseShared && swift test --filter StateClassifierTemperatureTests`
Expected: FAIL — `feverScoreForTest` / `sickConfidenceForTest` / baseline param don't exist.

- [ ] **Step 3: Implement the temperature term**

In `StateClassifier.swift`:

Add the trailing param to `classify` and compute the fever score once:

```swift
    public func classify(
        _ snapshot: HealthSnapshot,
        at date: Date = .now,
        calendar: Calendar = .current,
        wristTempBaseline: (mean: Double, count: Int)? = nil
    ) -> ClassificationResult {
        let scores = computeSubScores(snapshot, at: date, calendar: calendar)
        let fever = feverScore(snapshot, wristTempBaseline: wristTempBaseline)

        let candidates: [(BiometricState, Double)] = [
            // ... unchanged entries ...
            (.sickUnwell,           sickConfidence(snapshot, scores, feverScore: fever)),
            // ... unchanged entries ...
        ]
        // ... rest unchanged ...
    }
```
(Only the `.sickUnwell` line changes — every other candidate stays exactly as-is.)

Change `sickConfidence` to accept and blend the fever term (only when `> 0`):

```swift
    private func sickConfidence(
        _ snapshot: HealthSnapshot,
        _ scores: BiometricSubScores,
        feverScore: Double?
    ) -> Double {
        guard snapshot.restingHeartRate != nil,
              snapshot.respiratoryRate != nil else { return 0.0 }
        let base = (1.0 - scores.respiratoryStress) * 0.4
                 + (1.0 - scores.oxygenLevel)        * 0.4
                 + (1.0 - scores.hrvRecovery)         * 0.2
        let raw: Double
        if let fever = feverScore, fever > 0 {
            raw = base * 0.75 + fever * 0.25
        } else {
            raw = base
        }
        return min(1.0, raw * 1.15)
    }

    /// Optional fever score in [0,1]; nil when no temperature signal is present.
    /// Body temp uses an absolute fever threshold; wrist temp uses deviation from a
    /// rolling baseline (needs ≥ 3 nights). Returns the max of available sources.
    private func feverScore(
        _ snapshot: HealthSnapshot,
        wristTempBaseline: (mean: Double, count: Int)?
    ) -> Double? {
        var scores: [Double] = []
        if let bodyTemp = snapshot.bodyTemperature {
            scores.append(max(0, min(1, (bodyTemp - 37.5) / 1.5)))
        }
        if let wrist = snapshot.sleepingWristTemperature,
           let base = wristTempBaseline, base.count >= 3 {
            let dev = wrist - base.mean
            scores.append(max(0, min(1, (dev - 0.5) / 1.0)))
        }
        return scores.max()
    }

    // Test shims (internal) — expose the private helpers to the test target.
    func feverScoreForTest(_ s: HealthSnapshot, wristTempBaseline: (mean: Double, count: Int)?) -> Double? {
        feverScore(s, wristTempBaseline: wristTempBaseline)
    }
    func sickConfidenceForTest(_ s: HealthSnapshot, _ scores: BiometricSubScores, feverScore: Double?) -> Double {
        sickConfidence(s, scores, feverScore: feverScore)
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd PulseShared && swift test --filter StateClassifierTemperatureTests`
Expected: PASS.

- [ ] **Step 5: Run the full package suite (no regressions)**

Run: `cd PulseShared && swift test`
Expected: PASS — existing `StateClassifierTests` still green (temperature-absent path unchanged).

- [ ] **Step 6: Commit**

```bash
git add PulseShared/Sources/PulseShared/Logic/StateClassifier.swift PulseShared/Tests/PulseSharedTests/StateClassifierTemperatureTests.swift
git commit -m "feat: temperature raises sick confidence (graceful when absent)"
```

---

### Task 3: Insights grouping + self-report analytics event

**Files:**
- Create: `PulseShared/Sources/PulseShared/Logic/InsightsGrouping.swift`
- Modify: `PulseShared/Sources/PulseShared/Analytics/AnalyticsEvent.swift`
- Test: `PulseShared/Tests/PulseSharedTests/InsightsGroupingTests.swift`

**Interfaces:**
- Produces `struct ClassificationEntry: Sendable` `{ let date: Date; let emotionRaw: String; let confidence: Double; let wasNeutralFallback: Bool; let signalsPresent: [String] }`.
- Produces `struct DayGroup: Sendable, Equatable` `{ let day: Date; let emotionRaw: String?; let isNeutral: Bool }`.
- Produces `enum InsightsGrouping { static func byDay(_ entries: [ClassificationEntry], calendar: Calendar) -> [DayGroup]; static func signalLabel(_ key: String) -> String }`.
- Produces `AnalyticsEvent.insightsSelfReportTapped` (static let, name `"insights_self_report_tapped"`).

- [ ] **Step 1: Write the failing tests**

Create `InsightsGroupingTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd PulseShared && swift test --filter InsightsGroupingTests`
Expected: FAIL — types/event don't exist.

- [ ] **Step 3: Create `InsightsGrouping.swift`**

```swift
import Foundation

public struct ClassificationEntry: Sendable {
    public let date: Date
    public let emotionRaw: String
    public let confidence: Double
    public let wasNeutralFallback: Bool
    public let signalsPresent: [String]

    public init(date: Date, emotionRaw: String, confidence: Double,
                wasNeutralFallback: Bool, signalsPresent: [String]) {
        self.date = date; self.emotionRaw = emotionRaw; self.confidence = confidence
        self.wasNeutralFallback = wasNeutralFallback; self.signalsPresent = signalsPresent
    }
}

public struct DayGroup: Sendable, Equatable {
    public let day: Date          // start-of-day
    public let emotionRaw: String?
    public let isNeutral: Bool
}

public enum InsightsGrouping {

    /// Groups entries by calendar day, newest day first. A day's representative
    /// emotion is the most recent non-fallback entry; if all are fallbacks the day
    /// is marked neutral (using the most recent entry's emotion).
    public static func byDay(_ entries: [ClassificationEntry], calendar: Calendar = .current) -> [DayGroup] {
        let buckets = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        return buckets.keys.sorted(by: >).map { day in
            let dayEntries = buckets[day]!.sorted { $0.date > $1.date }
            if let real = dayEntries.first(where: { !$0.wasNeutralFallback }) {
                return DayGroup(day: day, emotionRaw: real.emotionRaw, isNeutral: false)
            }
            return DayGroup(day: day, emotionRaw: dayEntries.first?.emotionRaw, isNeutral: true)
        }
    }

    public static func signalLabel(_ key: String) -> String {
        switch key {
        case "hrv": return "HRV"
        case "restingHR": return "Resting HR"
        case "sleep": return "Sleep"
        case "spo2": return "Blood oxygen"
        case "respiration": return "Respiration"
        case "temperature": return "Temperature"
        case "daylight": return "Daylight"
        case "hrRecovery": return "HR recovery"
        case "activity": return "Activity"
        default: return key
        }
    }
}
```

- [ ] **Step 4: Add the analytics event**

In `AnalyticsEvent.swift`, under the "Screen Events" MARK (or a new "Insights Events" MARK):

```swift
    // MARK: - Insights Events

    public static let insightsSelfReportTapped = AnalyticsEvent(name: "insights_self_report_tapped")
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd PulseShared && swift test --filter InsightsGroupingTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add PulseShared/Sources/PulseShared/Logic/InsightsGrouping.swift PulseShared/Sources/PulseShared/Analytics/AnalyticsEvent.swift PulseShared/Tests/PulseSharedTests/InsightsGroupingTests.swift
git commit -m "feat: Insights day-grouping logic + self-report analytics event"
```

---

### Task 4: HealthKit collectors for the new signals

**Files:**
- Modify: `Pulse/Core/Health/MetricCollector.swift`

**Interfaces:**
- Consumes: `HealthSnapshot` new fields (Task 1).
- Produces: populated `sleepingWristTemperature`, `timeInDaylightMinutes`, `heartRateRecoveryBPM` on the snapshot when available.

- [ ] **Step 1: Add read types**

In `MetricCollector.readTypes`, add:

```swift
        HKQuantityType(.appleSleepingWristTemperature),
        HKQuantityType(.timeInDaylight),
        HKQuantityType(.heartRateRecoveryOneMinute),
```

- [ ] **Step 2: Enable temperature + add context toggle**

In `MetricToggles`, change the body-temp default to `true` and add a context toggle:

```swift
    var useBodyTemp:    Bool = true
    var useContextSignals: Bool = true   // Time in Daylight, HR recovery
```

- [ ] **Step 3: Add the three collector methods**

Add near the other fetch methods:

```swift
    // Sleeping Wrist Temperature — most recent nightly sample in last 3 days
    private func fetchSleepingWristTemperature() async -> Double? {
        let type = HKQuantityType(.appleSleepingWristTemperature)
        let start = Date().addingTimeInterval(-3 * 24 * 60 * 60)
        return await fetchMostRecentSample(type: type, start: start, end: .now, unit: .degreeCelsius())
    }

    // Time in Daylight — cumulative minutes today
    private func fetchTimeInDaylight() async -> Double? {
        let type = HKQuantityType(.timeInDaylight)
        let start = Calendar.current.startOfDay(for: .now)
        return await fetchQuantityStatistics(
            type: type, start: start, end: .now,
            options: .cumulativeSum, unit: .minute()
        )
    }

    // Heart Rate Recovery (1 min) — most recent sample in last 24 hours
    private func fetchHeartRateRecovery() async -> Double? {
        let type = HKQuantityType(.heartRateRecoveryOneMinute)
        let start = Date().addingTimeInterval(-24 * 60 * 60)
        return await fetchMostRecentSample(
            type: type, start: start, end: .now,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
    }
```

- [ ] **Step 4: Wire into the concurrent fetch + assembly**

In `fetchSnapshot()`, add the `async let` bindings (with the existing pattern), gating wrist temp on `useBodyTemp` and the others on `useContextSignals`:

```swift
        async let wristTemp   = t.useBodyTemp        ? fetchSleepingWristTemperature() : nil as Double?
        async let daylight    = t.useContextSignals  ? fetchTimeInDaylight()           : nil as Double?
        async let hrRecovery  = t.useContextSignals  ? fetchHeartRateRecovery()        : nil as Double?
```

Add the awaits:

```swift
        let wristTempValue   = await wristTemp
        let daylightValue    = await daylight
        let hrRecoveryValue  = await hrRecovery
```

And pass them into the `HealthSnapshot(...)` initializer (add before `timestamp`/at the tail, matching Task 1's param names):

```swift
            sleepingWristTemperature: wristTempValue,
            timeInDaylightMinutes: daylightValue,
            heartRateRecoveryBPM: hrRecoveryValue,
```

- [ ] **Step 5: Regenerate + build**

Run:
```bash
xcodegen generate
xcodebuild -project Pulse.xcodeproj -scheme Pulse -destination 'generic/platform=iOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add Pulse/Core/Health/MetricCollector.swift Pulse.xcodeproj
git commit -m "feat: collect wrist temperature, Time in Daylight, HR recovery"
```

---

### Task 5: `ClassificationRecord` model + schema registration

**Files:**
- Create: `Pulse/Core/Persistence/ClassificationRecord.swift`
- Modify: `Pulse/Core/Persistence/ModelContainer+Setup.swift`

**Interfaces:**
- Produces `@Model final class ClassificationRecord` with: `timestamp: Date`, `emotionRaw: String`, `stateRaw: String`, `confidence: Double`, `wasNeutralFallback: Bool`, `insufficientData: Bool`, `signalsPresent: [String]`, `sleepingWristTemperature: Double?`, `timeInDaylightMinutes: Double?`, `heartRateRecoveryBPM: Double?`, and a memberwise `init`.

- [ ] **Step 1: Create the model**

```swift
import Foundation
import SwiftData

/// One record per classification (delivered or not) — the on-device tuning log
/// that powers the Insights view. Never leaves the device.
@Model
final class ClassificationRecord {
    var timestamp: Date
    var emotionRaw: String          // Emotion.rawValue (user-facing)
    var stateRaw: String            // BiometricState.rawValue (internal)
    var confidence: Double
    var wasNeutralFallback: Bool
    var insufficientData: Bool
    var signalsPresent: [String]
    var sleepingWristTemperature: Double?   // raw °C, for baseline computation
    var timeInDaylightMinutes: Double?
    var heartRateRecoveryBPM: Double?

    init(
        timestamp: Date = .now,
        emotionRaw: String,
        stateRaw: String,
        confidence: Double,
        wasNeutralFallback: Bool,
        insufficientData: Bool,
        signalsPresent: [String],
        sleepingWristTemperature: Double? = nil,
        timeInDaylightMinutes: Double? = nil,
        heartRateRecoveryBPM: Double? = nil
    ) {
        self.timestamp = timestamp
        self.emotionRaw = emotionRaw
        self.stateRaw = stateRaw
        self.confidence = confidence
        self.wasNeutralFallback = wasNeutralFallback
        self.insufficientData = insufficientData
        self.signalsPresent = signalsPresent
        self.sleepingWristTemperature = sleepingWristTemperature
        self.timeInDaylightMinutes = timeInDaylightMinutes
        self.heartRateRecoveryBPM = heartRateRecoveryBPM
    }
}
```

- [ ] **Step 2: Register in the schema**

In `ModelContainer+Setup.swift`, add `ClassificationRecord.self` to the `Schema([...])` array:

```swift
        let schema = Schema([VerseDelivery.self, CachedVerse.self, UserPreferences.self, EmotionFeedback.self, ClassificationRecord.self])
```

- [ ] **Step 3: Regenerate + build**

Run:
```bash
xcodegen generate
xcodebuild -project Pulse.xcodeproj -scheme Pulse -destination 'generic/platform=iOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **` (SwiftData migrates additively — a new model is a lightweight change).

- [ ] **Step 4: Commit**

```bash
git add Pulse/Core/Persistence/ClassificationRecord.swift Pulse/Core/Persistence/ModelContainer+Setup.swift Pulse.xcodeproj
git commit -m "feat: ClassificationRecord SwiftData model"
```

---

### Task 6: `ClassificationRecorder` + `HealthEngine` hook

**Files:**
- Create: `Pulse/Core/Health/ClassificationRecorder.swift`
- Modify: `Pulse/Core/Health/HealthEngine.swift`
- Modify: `Pulse/App/PulseApp.swift`

**Interfaces:**
- Consumes: `ClassificationRecord` (Task 5), `ClassificationSignals` + `TemperatureBaseline` (Task 1), `ClassificationResult`, `HealthSnapshot`.
- Produces `@MainActor final class ClassificationRecorder`: `init(context: ModelContext)`; `func record(_ result: ClassificationResult, snapshot: HealthSnapshot)`; `func wristTempBaseline() -> (mean: Double, count: Int)?`.
- `HealthEngine` gains `var recorder: ClassificationRecorder?`; `refresh()` computes the baseline, passes it to `classify`, and records the result.

- [ ] **Step 1: Create the recorder**

```swift
import Foundation
import SwiftData
import PulseShared

/// Writes one ClassificationRecord per classification and prunes old ones.
/// On-device only. Also computes the rolling wrist-temperature baseline.
@MainActor
final class ClassificationRecorder {
    private let context: ModelContext
    private let retentionDays = 90
    private let baselineNights = 14

    init(context: ModelContext) {
        self.context = context
    }

    func record(_ result: ClassificationResult, snapshot: HealthSnapshot) {
        let record = ClassificationRecord(
            emotionRaw: result.emotion.rawValue,
            stateRaw: result.state.rawValue,
            confidence: result.confidence,
            wasNeutralFallback: result.confidence < 0.65,
            insufficientData: ClassificationSignals.insufficientData(snapshot),
            signalsPresent: ClassificationSignals.signalsPresent(snapshot),
            sleepingWristTemperature: snapshot.sleepingWristTemperature,
            timeInDaylightMinutes: snapshot.timeInDaylightMinutes,
            heartRateRecoveryBPM: snapshot.heartRateRecoveryBPM
        )
        context.insert(record)
        prune()
        try? context.save()
    }

    /// Mean of the most recent nightly wrist temperatures (last `baselineNights`
    /// records that have one). Nil when none.
    func wristTempBaseline() -> (mean: Double, count: Int)? {
        var descriptor = FetchDescriptor<ClassificationRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        let recent = (try? context.fetch(descriptor)) ?? []
        let temps = recent.compactMap { $0.sleepingWristTemperature }.prefix(baselineNights)
        return TemperatureBaseline.mean(of: Array(temps))
    }

    private func prune() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: .now) ?? .distantPast
        let predicate = #Predicate<ClassificationRecord> { $0.timestamp < cutoff }
        try? context.delete(model: ClassificationRecord.self, where: predicate)
    }
}
```

- [ ] **Step 2: Hook into `HealthEngine.refresh()`**

In `HealthEngine.swift`, add a stored property `var recorder: ClassificationRecorder?` and update `refresh()`:

```swift
    func refresh() async {
        do {
            let snapshot = try await provider.fetchSnapshot()
            let baseline = await recorder?.wristTempBaseline()
            let result = classifier.classify(snapshot, wristTempBaseline: baseline)
            currentSnapshot = snapshot
            currentClassification = result
            logger.info(
                "Classified: \(result.state.rawValue, privacy: .public) @ \(String(format: "%.2f", result.confidence), privacy: .public)"
            )
            await recorder?.record(result, snapshot: snapshot)
            if let callback = onClassification {
                await callback(result)
            }
        } catch {
            logger.error("refresh() failed: \(error.localizedDescription, privacy: .public)")
        }
    }
```
(`recorder` is `@MainActor`; `await` its calls. If `HealthEngine` is already `@MainActor`, the `await`s are still valid.)

- [ ] **Step 3: Inject the recorder in `PulseApp`**

In `PulseApp.swift`, where `HealthEngine`/other engines are constructed with `container.mainContext`, set:

```swift
        healthEngine.recorder = ClassificationRecorder(context: context)
```
(Use the same `context`/`HealthEngine` instance the app already builds; match the surrounding construction style.)

- [ ] **Step 4: Regenerate + build**

Run:
```bash
xcodegen generate
xcodebuild -project Pulse.xcodeproj -scheme Pulse -destination 'generic/platform=iOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Pulse/Core/Health/ClassificationRecorder.swift Pulse/Core/Health/HealthEngine.swift Pulse/App/PulseApp.swift Pulse.xcodeproj
git commit -m "feat: record every classification + wrist-temp baseline"
```

---

### Task 7: Insights tab (replaces Journey)

**Files:**
- Create: `Pulse/Features/Insights/InsightsView.swift`
- Modify: `Pulse/Features/MainTabView.swift`

**Interfaces:**
- Consumes: `ClassificationRecord` (Task 5), `InsightsGrouping` + `ClassificationEntry` + `Emotion` (Task 3 / PulseShared).
- Produces: `InsightsView`; `MainTabView.Tab.insights` (renamed from `.history`).

- [ ] **Step 1: Create `InsightsView`**

```swift
import SwiftUI
import SwiftData
import PulseShared

struct InsightsView: View {
    @Query(sort: \ClassificationRecord.timestamp, order: .reverse)
    private var records: [ClassificationRecord]

    private var groups: [DayGroup] {
        InsightsGrouping.byDay(records.map {
            ClassificationEntry(date: $0.timestamp, emotionRaw: $0.emotionRaw,
                                confidence: $0.confidence, wasNeutralFallback: $0.wasNeutralFallback,
                                signalsPresent: $0.signalsPresent)
        })
    }

    var body: some View {
        NavigationStack {
            Group {
                if groups.isEmpty {
                    ContentUnavailableView(
                        "No insights yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text("As Pulse reads your day, your emotions will appear here.")
                    )
                } else {
                    List(groups, id: \.day) { group in
                        HStack {
                            Text(group.day, format: .dateTime.weekday(.wide).month().day())
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                            Spacer()
                            if let emotionRaw = group.emotionRaw, let emotion = Emotion(rawValue: emotionRaw) {
                                Label(emotion.displayName, systemImage: emotion.systemImage)
                                    .font(.system(size: 13))
                                    .foregroundStyle(group.isNeutral ? .secondary : .primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Insights")
        }
        .trackScreen("Insights")
    }
}
```

- [ ] **Step 2: Replace the Journey tab**

In `MainTabView.swift`:
- Rename the enum case: `enum Tab: String { case home, insights, settings }`.
- Replace the middle tab:

```swift
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.xyaxis.line") }
                .tag(Tab.insights)
```

- Update `initialTab()` mapping so both work:

```swift
            case "insights", "journey": return .insights
            case "settings": return .settings
```

(Leave `HistoryView.swift` in the tree, now unreferenced.)

- [ ] **Step 3: Regenerate + build + smoke-check the tab**

Run:
```bash
xcodegen generate
xcodebuild -project Pulse.xcodeproj -scheme Pulse -destination 'generic/platform=iOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
grep -n "case home, insights, settings" Pulse/Features/MainTabView.swift
grep -rn "HistoryView()" Pulse/Features/MainTabView.swift || echo "Journey tab removed ✔"
```
Expected: `** BUILD SUCCEEDED **`; the enum line prints; the Journey grep prints "removed ✔".

- [ ] **Step 4: Commit**

```bash
git add Pulse/Features/Insights/InsightsView.swift Pulse/Features/MainTabView.swift Pulse.xcodeproj
git commit -m "feat: Insights tab replaces Journey"
```

---

### Task 8: Low-data self-report prompt on Home

**Files:**
- Modify: `Pulse/Features/Home/HomeView.swift`

**Interfaces:**
- Consumes: `ClassificationRecord` (Task 5), `ClassificationSignals.shouldPromptSelfReport` (Task 1), `AnalyticsEvent.insightsSelfReportTapped` (Task 3), the existing feeling picker (`FeelingPickerView`) and `Analytics.shared`.
- Produces: a Home prompt shown only when the latest classification is `insufficientData`, opening the feeling picker.

- [ ] **Step 1: Query the latest record + compute the flag**

In `HomeView`, add:

```swift
    @Query(sort: \ClassificationRecord.timestamp, order: .reverse)
    private var recentClassifications: [ClassificationRecord]

    @State private var showFeelingPicker = false

    private var shouldPromptSelfReport: Bool {
        ClassificationSignals.shouldPromptSelfReport(
            latestInsufficientData: recentClassifications.first?.insufficientData
        )
    }
```

- [ ] **Step 2: Add the prompt card**

Place near the top of Home's content (match surrounding card styling):

```swift
            if shouldPromptSelfReport {
                Button {
                    Analytics.shared.track(.insightsSelfReportTapped)
                    showFeelingPicker = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How are you feeling?")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Text("We can’t read enough right now — tap to tell us.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.psNavy, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
```

Attach the picker sheet on the Home root view (reuse the existing `FeelingPickerView` presentation the app already uses; if Home already presents it elsewhere, reuse that binding instead of adding a second):

```swift
        .sheet(isPresented: $showFeelingPicker) {
            FeelingPickerView()
        }
```

- [ ] **Step 3: Regenerate + build**

Run:
```bash
xcodegen generate
xcodebuild -project Pulse.xcodeproj -scheme Pulse -destination 'generic/platform=iOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Pulse/Features/Home/HomeView.swift Pulse.xcodeproj
git commit -m "feat: prompt self-report on Home when data is insufficient"
```

---

## Self-Review

**Spec coverage:**
- New signals + collection (§1) → Task 1 (fields) + Task 4 (collectors). ✓
- Temperature → sick, graceful, gate unchanged (§2) → Task 2. ✓
- Daylight/HR-recovery observe-first (§3) → Task 4 collects, Task 5 stores, Task 2 test asserts no classification change. ✓
- `ClassificationRecord` store, write-every-classification, retention (§4) → Tasks 5 + 6. ✓
- Insights view replaces Journey, user-facing emotion, empty state (§5) → Tasks 3 (grouping) + 7 (UI/tab). ✓
- Low-data self-report prompt (§6) → Task 1 helper + Task 8 UI. ✓
- Permissions (§7) → Task 4 readTypes. ✓
- Analytics + guardrail → Task 3 event (neutral, tested), Task 7 `.trackScreen`, Task 8 track call; no health data in any payload. ✓
- Testing (§7 spec) → Tasks 1–3 carry unit tests; app-target tasks build-verified (no app test target). ✓
- `insufficientData` / `wasNeutralFallback` definitions → Task 1 helper / Task 6 (`< 0.65`). ✓
- Temperature thresholds → Task 2 verbatim from Global Constraints. ✓

**Placeholder scan:** none. App-target steps use build/grep verification because the project has no app unit-test target (stated in Global Constraints); all logic with real tests lives in `PulseShared`.

**Type consistency:** `HealthSnapshot.sleepingWristTemperature/timeInDaylightMinutes/heartRateRecoveryBPM`, `ClassificationSignals.insufficientData/signalsPresent/shouldPromptSelfReport`, `TemperatureBaseline.mean`, `StateClassifier.classify(_:at:calendar:wristTempBaseline:)`, `sickConfidence(_:_:feverScore:)`, `ClassificationEntry`, `DayGroup`, `InsightsGrouping.byDay/signalLabel`, `AnalyticsEvent.insightsSelfReportTapped`, `ClassificationRecord` fields, `ClassificationRecorder.record/wristTempBaseline`, and `MainTabView.Tab.insights` are used identically across tasks. `Emotion.displayName`/`.systemImage` and `.trackScreen` match existing APIs.
