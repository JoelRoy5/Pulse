# Pulse Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Home header fix, a real app icon + assets, "A Time of Prayer" (watch, adaptive heartbeat haptic), Verse of the Day (YouVersion VOTD), and streak tracking — each with verified functionality.

**Architecture:** New pure logic (`PrayerCadence`, `StreakCalculator`, VOTD fetch) lands in the `PulseShared` Swift package where `swift test` covers it. iOS gains a VOTD scheduler + Home cards; watch gains a full-screen prayer session with a heartbeat-haptic player driven by the shared cadence model. An `ImageRenderer` script generates committed icon/image assets. A final verification pass exercises every new and existing interactive element.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, HealthKit, WatchKit, WidgetKit, UserNotifications, XcodeGen, XCTest.

## Global Constraints

Copied from the Phase 2 design (`docs/superpowers/specs/2026-08-01-pulse-phase2-design.md`) and the still-binding Phase 1 constraints. Every task implicitly includes these:

- Deployment targets iOS 17.0 / watchOS 10.0. Xcode 26.2. Language mode Swift 5.
- Bundle IDs / App Group unchanged: `com.joelroy.pulse`, `com.joelroy.pulse.watchkitapp`, `com.joelroy.pulse.watchkitapp.widgets`, `group.com.joelroy.pulse`. Team `APQT8U28NL`, automatic signing.
- **No third-party dependencies** (Apple frameworks + XcodeGen only).
- **No force-unwraps in production paths.** All async via Swift Concurrency. View models `@Observable`.
- **Zero raw health numbers to any external API** — unchanged. VOTD is date-based (no health data); prayer HR stays on-device.
- Missing data renders as `—`, never an error. Always-dark app.
- **Prayer feature copy contains NO breathing/meditation language** — "prayer", "stillness before God", "rest in Him" only.
- Design tokens (colors/typography/spacing/animation) come from `PulseShared/Sources/PulseShared/Design`; user-facing verse/state copy stays verbatim from the Instructions docs.
- Reduce-motion (`accessibilityReduceMotion` / watch equivalent) gates all repeating animations. 44pt min tap targets.
- Regenerate the project with `xcodegen generate` after adding files (sources are directory-globbed). Commit per task, `feat:`/`fix:`/`test:`/`chore:` messages ending with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Verification commands:
  - Package tests: `swift test --package-path PulseShared` (Phase 1 baseline: 53 pass, 1 skipped)
  - iOS build: `xcodebuild -project Pulse.xcodeproj -scheme Pulse -destination 'id=5478E7A0-A43A-4573-AEAC-9293549D1E0D' build`
  - Watch build: `xcodebuild -project Pulse.xcodeproj -scheme PulseWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build`

## Existing interfaces this plan builds on (verified in the tree)

- `YouVersionClient` (`struct`, `VerseFetching`): `init(appKey:session:)`, `fetchVerse(reference:bibleID:abbreviation:) -> BibleVerse`, `listBibles() -> [BibleVersion]`, private `performRequest`, `checkResponse`, `decode`, `buildChapterURL`, `attributionString`. Base URL `https://api.youversion.com`, header `X-YVP-App-Key`. `ScriptureAPIError` cases: `notConfigured, authFailed, requestFailed(status:), decodingFailed, timedOut`.
- `VerseDelivery` `@Model` init has `deliveryMethod: String = "notification"`, `verseTheme`, `themeDisplayName`, `biometricStateRaw`, `stateConfidence`, `stateBodyText`, metrics-at-delivery, `deliveredAt`, `userReaction` bridge, `isOfflineFallback`.
- `HomeView` renders a `VStack` inside `ScrollView`; header currently in `.toolbar { ToolbarItem(.navigationBarLeading) { topBarLeading } }` (`HomeView.swift:94-98`, `topBarLeading` at `:182-191`).
- Watch `PrayerView` (`PulseWatch/Features/PrayerView.swift`): has the disabled "Begin Breath Prayer"/"Coming soon" block at lines 65-76; `WatchState` via `@Environment`; `WatchSessionManager.shared.sendReaction(.prayed, deliveryID:)`; `FallbackVerseProvider().emergencyVerse(for:)`.
- `WatchHealthEngine` (`PulseWatch/Core/WatchHealthEngine.swift`): HKHealthStore wrapper fetching HR/HRV/SpO2/steps, HR read type authorized.
- `AppConfig` (iOS): `glooClientID/glooClientSecret/youVersionAppKey/isConfigured/forceOffline`.
- `UserPreferences` `@Model`: `includeVerseOfDay: Bool`, `preferredBibleID: Int`, `preferredBibleAbbreviation: String`, plus `current(in:)` fetch-or-create helper.
- `NotificationService` (iOS singleton): `requestAuthorization()`, `scheduleVerseNotification(_:style:)`, category `verse_notification` with actions.

## File Structure (end state of Phase 2)

```
Scripts/generate-assets.swift                 # icon + image generator (macOS ImageRenderer)
PulseShared/Sources/PulseShared/
  Logic/PrayerCadence.swift                   # adaptive heartbeat cadence (pure)
  Logic/StreakCalculator.swift                # streak + month engagement (pure)
  Scripture/YouVersionClient.swift            # + fetchVerseOfTheDay
  Models/ (VOTD response structs inside YouVersionClient.swift)
PulseShared/Tests/PulseSharedTests/
  PrayerCadenceTests.swift
  StreakCalculatorTests.swift
  VerseOfTheDayTests.swift                     # stubbed transport
Pulse/
  Features/Home/HomeView.swift                # header moved into content
  Features/Home/StreakWidget.swift            # new
  Features/Home/VerseOfDayCard.swift          # new
  Core/Scripture/VerseOfDayScheduler.swift    # new
  Resources/Assets.xcassets/AppIcon.appiconset/ (generated)
  Resources/Assets.xcassets/logo_icon.imageset/ (generated)
PulseWatch/
  Features/PrayerView.swift                    # entry button change
  Features/PrayerTimeView.swift                # new session screen
  Core/PrayerHapticPlayer.swift               # new
  Core/PrayerPrompts.swift                     # new (bundled prompt content)
  Resources/Assets.xcassets/AppIcon.appiconset/ (generated)
docs/verification-phase2.md                    # verification record
```

---

### Task 1: Home header fix

**Files:**
- Modify: `Pulse/Features/Home/HomeView.swift` (remove `.toolbar` block at ~94-98; delete/relocate `topBarLeading` ~182-191; add header as first item in the content `VStack`).

**Interfaces:**
- Consumes: `PSFont`, `Color.psAccent`, `Color.psGrayMuted` (existing).
- Produces: nothing new; visual/layout change only.

- [ ] **Step 1: Move the header into scroll content.** In `HomeView.body`, delete the `.toolbar { ToolbarItem(placement: .navigationBarLeading) { topBarLeading } }` modifier. As the FIRST child of the content `VStack(alignment: .leading, spacing: PSSpacing.md)` (before the State Banner Card), insert:

```swift
VStack(alignment: .leading, spacing: 2) {
    Text("Pulse")
        .font(PSFont.label(size: 28, weight: .bold))
        .foregroundStyle(Color.psAccent)
    Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
        .font(PSFont.label(size: 14))
        .foregroundStyle(Color.psGrayMuted)
}
.frame(maxWidth: .infinity, alignment: .leading)
.padding(.top, PSSpacing.sm)
```

Keep `.navigationBarTitleDisplayMode(.inline)` but the nav bar is now empty (no clipped item). Remove the now-unused `private var topBarLeading`.

- [ ] **Step 2: Build.** `xcodebuild ... -scheme Pulse -destination 'id=5478E7A0-A43A-4573-AEAC-9293549D1E0D' build` → BUILD SUCCEEDED.
- [ ] **Step 3: Verify in simulator.** Boot iPhone 16 (5478E7A0-...), install, launch with `-PulseSkipOnboarding YES -PulseMockState exhausted_depleted -PulseAutoDeliver YES`; screenshot `/tmp/p2-header.png`; Read it — confirm "Pulse" + full date render unclipped at the top of the scroll view. 
- [ ] **Step 4: Commit.** `git add -A && git commit -m "fix: move Home header into scroll content to stop nav-bar clipping"`

---

### Task 2: PrayerCadence (pure logic)

**Files:**
- Create: `PulseShared/Sources/PulseShared/Logic/PrayerCadence.swift`
- Test: `PulseShared/Tests/PulseSharedTests/PrayerCadenceTests.swift`

**Interfaces:**
- Produces (all `public`):
  - `struct PrayerCadence: Sendable`
    - `public init(startBPM: Double, targetBPM: Double, durationSeconds: Double)` — internally clamps: `start = min(max(startBPM, 50), 120)`; `target = max(min(targetBPM, start), 50)` (target never above start, never below 50); `duration = max(durationSeconds, 1)`.
    - `public func bpm(atElapsed elapsed: Double) -> Double` — eases `start → target` with ease-out cubic over `[0, duration]`, clamped to `[target, start]`. `progress = min(max(elapsed/duration, 0), 1)`; `eased = 1 - pow(1 - progress, 3)`; `return start + (target - start) * eased`.
    - `public func beatInterval(atElapsed elapsed: Double) -> TimeInterval` — `60.0 / bpm(atElapsed:)`.
    - `public var clampedStartBPM: Double` / `public var clampedTargetBPM: Double` — expose the clamped values (for tests + display).

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import PulseShared

final class PrayerCadenceTests: XCTestCase {
    func testStartEqualsTargetIsConstant() {
        let c = PrayerCadence(startBPM: 60, targetBPM: 60, durationSeconds: 120)
        XCTAssertEqual(c.bpm(atElapsed: 0), 60, accuracy: 0.001)
        XCTAssertEqual(c.bpm(atElapsed: 60), 60, accuracy: 0.001)
        XCTAssertEqual(c.bpm(atElapsed: 120), 60, accuracy: 0.001)
    }
    func testWindsDownMonotonically() {
        let c = PrayerCadence(startBPM: 90, targetBPM: 60, durationSeconds: 120)
        XCTAssertEqual(c.bpm(atElapsed: 0), 90, accuracy: 0.001)
        let mid = c.bpm(atElapsed: 60)
        XCTAssertLessThan(mid, 90)
        XCTAssertGreaterThan(mid, 60)
        XCTAssertEqual(c.bpm(atElapsed: 120), 60, accuracy: 0.5)
        // non-increasing across the session
        var prev = 999.0
        for t in stride(from: 0.0, through: 120.0, by: 5.0) {
            let v = c.bpm(atElapsed: t)
            XCTAssertLessThanOrEqual(v, prev + 0.001)
            prev = v
        }
    }
    func testNeverSpeedsUpWhenTargetAboveStart() {
        let c = PrayerCadence(startBPM: 55, targetBPM: 80, durationSeconds: 60)
        // target clamped to start; constant
        XCTAssertEqual(c.bpm(atElapsed: 0), 55, accuracy: 0.001)
        XCTAssertEqual(c.bpm(atElapsed: 60), 55, accuracy: 0.001)
    }
    func testClamps() {
        let c = PrayerCadence(startBPM: 200, targetBPM: 10, durationSeconds: 0)
        XCTAssertEqual(c.clampedStartBPM, 120, accuracy: 0.001)   // start capped
        XCTAssertEqual(c.clampedTargetBPM, 50, accuracy: 0.001)   // target floored
    }
    func testBeatInterval() {
        let c = PrayerCadence(startBPM: 60, targetBPM: 60, durationSeconds: 120)
        XCTAssertEqual(c.beatInterval(atElapsed: 0), 1.0, accuracy: 0.001)  // 60bpm = 1s
    }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --package-path PulseShared` → compile errors.
- [ ] **Step 3: Implement `PrayerCadence.swift`** per the Interfaces block.
- [ ] **Step 4: Run tests** — all PASS; full suite still green.
- [ ] **Step 5: Commit** — `git commit -m "feat: PrayerCadence adaptive heartbeat wind-down model"`

---

### Task 3: StreakCalculator (pure logic)

**Files:**
- Create: `PulseShared/Sources/PulseShared/Logic/StreakCalculator.swift`
- Test: `PulseShared/Tests/PulseSharedTests/StreakCalculatorTests.swift`

**Interfaces:**
- Produces (all `public`):
  - `struct StreakCalculator: Sendable`
    - `public init()`
    - `public func currentStreak(engagementDates: [Date], today: Date, calendar: Calendar = .current) -> Int` — count consecutive calendar days with ≥1 engagement, ending today OR yesterday (grace: if there is engagement yesterday but not yet today, the streak still stands and includes through yesterday). Algorithm: reduce dates to a `Set` of `startOfDay`. If neither today nor yesterday is present → 0. Start the walk at today if present else yesterday; step back one day while the day is in the set; return the count.
    - `public func daysEngagedThisMonth(engagementDates: [Date], today: Date, calendar: Calendar = .current) -> (engaged: Int, total: Int)` — `engaged` = distinct engagement days whose month+year == today's; `total` = today's day-of-month (days elapsed this month, inclusive).

- [ ] **Step 1: Write failing tests**

```swift
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
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement `StreakCalculator.swift`** per Interfaces.
- [ ] **Step 4: Run tests** — PASS; full suite green.
- [ ] **Step 5: Commit** — `git commit -m "feat: StreakCalculator (consecutive-day engagement + month counts)"`

---

### Task 4: YouVersion Verse of the Day fetch

**Files:**
- Modify: `PulseShared/Sources/PulseShared/Scripture/YouVersionClient.swift`
- Test: `PulseShared/Tests/PulseSharedTests/VerseOfTheDayTests.swift`

**Interfaces:**
- Consumes: existing `YouVersionClient` internals (`performRequest`, `checkResponse`, `decode`, `buildChapterURL`, USFM handling), `BibleVerse`, `ScriptureAPIError`.
- Produces:
  - `public func fetchVerseOfTheDay(bibleID: Int, abbreviation: String, day: Int? = nil) async throws -> BibleVerse` — `day` defaults to the current day-of-year (1–366) via `Calendar.current.ordinality(of: .day, in: .year, for: .now)`. Step 1: GET `/v1/verse_of_the_days/{day}` (header `X-YVP-App-Key`) → decode `{ day: Int, passage_id: String }` (private `VOTDResponse`). Step 2: fetch the passage text for `passage_id` in `bibleID` via the existing passage path (`/v1/bibles/{bibleID}/passages/{passage_id}?format=text`), reusing the passage-response decode → `BibleVerse` (id = passage_id, translationAbbreviation = abbreviation, copyright via existing `attributionString`). Any non-2xx / decode failure → `ScriptureAPIError` (map 401/403 → `.authFailed`, else `.requestFailed`/`.decodingFailed`), so callers fall through the offline chain.
  - Private `struct VOTDResponse: Decodable { let day: Int; let passageId: String }` with `CodingKeys` mapping `passageId` ← `"passage_id"`.

- [ ] **Step 1: Write failing tests** (reuse the existing `StubURLProtocol` + `stubbedSession()` helpers in the test target):

```swift
import XCTest
@testable import PulseShared

final class VerseOfTheDayTests: XCTestCase {
    func testFetchVOTDTwoStep() async throws {
        StubURLProtocol.requestHandler = { req in
            let url = req.url!.absoluteString
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.contains("/verse_of_the_days/") {
                return (resp, Data(#"{"day":15,"passage_id":"JHN.3.16"}"#.utf8))
            } else {  // passage fetch
                return (resp, Data(#"{"id":"JHN.3.16","content":"For God so loved the world...","reference":"John 3:16"}"#.utf8))
            }
        }
        let client = YouVersionClient(appKey: "k", session: stubbedSession())
        let verse = try await client.fetchVerseOfTheDay(bibleID: 3034, abbreviation: "BSB", day: 15)
        XCTAssertEqual(verse.reference, "John 3:16")
        XCTAssertEqual(verse.translationAbbreviation, "BSB")
        XCTAssertFalse(verse.text.isEmpty)
    }
    func testVOTDAuthFailure() async {
        StubURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        let client = YouVersionClient(appKey: "k", session: stubbedSession())
        do { _ = try await client.fetchVerseOfTheDay(bibleID: 3034, abbreviation: "BSB", day: 15)
             XCTFail("expected throw")
        } catch let e as ScriptureAPIError { XCTAssertEqual(e, .authFailed) }
        catch { XCTFail("wrong error \(error)") }
    }
}
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement `fetchVerseOfTheDay` + `VOTDResponse`.** Refactor the existing passage-fetch body into a private `fetchPassage(passageID:bibleID:abbreviation:)` if needed so both `fetchVerse` and `fetchVerseOfTheDay` reuse it (DRY).
- [ ] **Step 4: Run tests** — PASS; full suite green.
- [ ] **Step 5: Live smoke (optional, gated).** Extend the env-gated `LiveSmokeTests` with a VOTD call; run once `PULSE_LIVE_SMOKE=1 swift test --package-path PulseShared --filter LiveSmokeTests`; note the returned reference in the report. If the live VOTD contract differs from `{day, passage_id}`, adjust `VOTDResponse`/paths and keep the public signature stable.
- [ ] **Step 6: Commit** — `git commit -m "feat: YouVersion verse-of-the-day fetch (two-step VOTD)"`

---

### Task 5: Verse of the Day scheduler + Home card

**Files:**
- Create: `Pulse/Core/Scripture/VerseOfDayScheduler.swift`, `Pulse/Features/Home/VerseOfDayCard.swift`
- Modify: `Pulse/Features/Home/HomeView.swift` (insert the card), `Pulse/App/PulseApp.swift` or `AppDelegate.swift` (register the daily notification + fetch hook), `Pulse/Notifications/NotificationService.swift` (a VOTD notification category if distinct copy is wanted — else reuse `verse_notification`).

**Interfaces:**
- Consumes: `YouVersionClient.fetchVerseOfTheDay`, `AppConfig`, `UserPreferences.includeVerseOfDay/preferredBibleID/preferredBibleAbbreviation`, `FallbackVerseProvider`, SwiftData `VerseDelivery` + `VerseCache`, `NotificationService`.
- Produces:
  - `@MainActor final class VerseOfDayScheduler` — `init(cache: VerseCache, client: YouVersionClient?, notifications: NotificationService)`; `func scheduleDailyNotification()` (a repeating `UNCalendarNotificationTrigger` at 08:00, identifier `com.joelroy.pulse.votd`, only when `includeVerseOfDay`; removes it when the setting is off); `func ensureTodaysVOTD() async` — if `includeVerseOfDay` and no `VerseDelivery` with `deliveryMethod == "votd"` exists for today, fetch VOTD (offline-chain fallback to `FallbackVerseProvider.emergencyVerse(for: .morningAwakening)`), persist a `VerseDelivery(deliveryMethod: "votd", verseTheme: "verse_of_the_day", themeDisplayName: "Verse of the Day", biometricStateRaw: BiometricState.morningAwakening.rawValue, ...)`, and (if fired from notification path) post a notification. `func todaysVOTD() -> VerseDelivery?` for the Home card.
  - `struct VerseOfDayCard: View` — `init(delivery: VerseDelivery, onTap: () -> Void)`; a `PSCard` styled distinctly (e.g. `.state(.morningAwakening)` gradient with a "☀️ Verse of the Day" label), verse excerpt + reference; tap → detail sheet. Distinct from the state verse card.
- Wiring: call `ensureTodaysVOTD()` from `HomeView.task` (after `healthEngine.refresh()`), and `scheduleDailyNotification()` at app launch + whenever the setting toggles (SettingsView already persists `includeVerseOfDay`; add a call there). Home shows `VerseOfDayCard` above Recent Verses when `todaysVOTD()` is non-nil and the setting is on.

- [ ] **Step 1: Implement `VerseOfDayScheduler`** (offline chain: `AppConfig.isConfigured && !forceOffline && client != nil` → live VOTD; else fallback verse).
- [ ] **Step 2: Implement `VerseOfDayCard`** with a `#Preview`.
- [ ] **Step 3: Wire Home + settings + launch** as above; regenerate project.
- [ ] **Step 4: Build** iOS scheme → SUCCEEDED.
- [ ] **Step 5: Verify in simulator.** Launch with `-PulseSkipOnboarding YES` (VOTD setting defaults on); Home shows a Verse of the Day card (live verse if keys/network, else fallback). Force the notification for inspection: `xcrun simctl push 5478E7A0-... com.joelroy.pulse` with a VOTD-styled `.apns` to confirm banner copy renders. Screenshot `/tmp/p2-votd-home.png` and `/tmp/p2-votd-notif.png`; Read both.
- [ ] **Step 6: Commit** — `git commit -m "feat: Verse of the Day scheduler, Home card, 8am notification"`

---

### Task 6: Streak widget on Home

**Files:**
- Create: `Pulse/Features/Home/StreakWidget.swift`
- Modify: `Pulse/Features/Home/HomeView.swift` (insert widget), `Pulse/Features/Home/HomeViewModel.swift` (expose streak computation) — or compute inline in the view from the `@Query`.

**Interfaces:**
- Consumes: `StreakCalculator`, SwiftData `VerseDelivery` `@Query` (already present in Home for recent verses), design tokens.
- Produces:
  - `struct StreakWidget: View` — `init(engagementDates: [Date])`; computes `currentStreak` + `daysEngagedThisMonth` via `StreakCalculator`; renders per `Instructions/05_IPHONE_APP.md:229-233`: "🔥 N-Day Streak" (or a first-verse encouragement when 0), a one-line message, and an "X of Y days this month" progress bar (`ProgressView(value:)` tinted `psAccent`). `#Preview` with sample dates.
- `engagementDates` = each `VerseDelivery.deliveredAt` (plus `engagedAt` when non-nil) from the Home `@Query`. Place the widget near the bottom of the Home stack (after Recent Verses, before the trailing spacer), per the spec layout.

- [ ] **Step 1: Implement `StreakWidget`** (0-streak state shows "Start your streak — your first verse today" + empty bar).
- [ ] **Step 2: Wire into Home** using the existing deliveries query.
- [ ] **Step 3: Build** iOS scheme → SUCCEEDED.
- [ ] **Step 4: Verify.** Seed ≥2 deliveries across "days" isn't possible in one run, so verify the 0/1 states live and the multi-day math via the Task 3 unit tests; screenshot the widget rendering with today's delivery `/tmp/p2-streak.png`; Read it.
- [ ] **Step 5: Commit** — `git commit -m "feat: Home streak widget"`

---

### Task 7: Prayer prompt content + haptic player (watch)

**Files:**
- Create: `PulseWatch/Core/PrayerPrompts.swift`, `PulseWatch/Core/PrayerHapticPlayer.swift`

**Interfaces:**
- Consumes: `PrayerCadence` (Task 2), `WatchHealthEngine` (live HR), `BiometricState`, `FallbackVerseProvider`, `WKInterfaceDevice`.
- Produces:
  - `enum PrayerPrompts` — `static func prompts(for theme: String?) -> [String]`: a small bundled set of short prayer/scripture prompt lines (no breathing/meditation words), keyed loosely by theme with a general fallback set. E.g. general: ["Be still, and know that He is God.", "Lord, I bring You this moment.", "Rest here with Him a while.", "He is near to you now.", "Speak, Lord — I am listening.", "Peace I leave with you."]. 6–8 lines; each ≤ ~40 chars.
  - `@MainActor final class PrayerHapticPlayer` — `init(cadence: PrayerCadence)`; `func start(onBeat: (() -> Void)? = nil)` schedules a repeating self-rescheduling beat: each beat plays a **lub-dub** (`WKInterfaceDevice.current().play(.click)`, then after ~0.14s another `.click`), then schedules the next beat after `cadence.beatInterval(atElapsed:)` using the elapsed time since `start`; `func stop()` cancels. Uses a `Task`/`Timer` that recomputes interval each beat (no fixed timer). Guards against firing after `stop()`.

- [ ] **Step 1: Implement `PrayerPrompts`** (pure data + selector).
- [ ] **Step 2: Implement `PrayerHapticPlayer`** (self-rescheduling beat loop; stop-safe).
- [ ] **Step 3: Build** watch scheme → SUCCEEDED (no unit test — WKInterfaceDevice needs the device/sim runtime; cadence math is already tested in Task 2).
- [ ] **Step 4: Commit** — `git commit -m "feat: watch prayer prompts and adaptive heartbeat haptic player"`

---

### Task 8: A Time of Prayer session screen (watch)

**Files:**
- Create: `PulseWatch/Features/PrayerTimeView.swift`
- Modify: `PulseWatch/Features/PrayerView.swift` (replace the disabled "Begin Breath Prayer"/"Coming soon" block at lines 65-76 with an enabled "Begin a Time of Prayer" button presenting `PrayerTimeView`).

**Interfaces:**
- Consumes: `PrayerHapticPlayer`, `PrayerPrompts`, `PrayerCadence`, `WatchHealthEngine`, `WatchState` (current verse for theme + closing verse), `FallbackVerseProvider`, `WatchSessionManager.shared.sendReaction(.prayed, deliveryID:)`, HealthKit (`HKHealthStore` for the `mindfulSession` write — the write type is already in the authorized set).
- Produces:
  - `struct PrayerTimeView: View` — full-screen session:
    - On appear: read live HR from `WatchHealthEngine` (fallback 70 if nil); build `PrayerCadence(startBPM: hr, targetBPM: restingOr60, durationSeconds: 120)` where `restingOr60` = `min(60, hr)` (a calm target ≤ start); start `PrayerHapticPlayer`.
    - Visual: full-bleed calm gradient (`watchState.currentVerse` state gradient, else `.spiritualAlert`); a heartbeat ring that scales subtly on each beat (via the player's `onBeat`), gated on reduce-motion; the current prompt from `PrayerPrompts.prompts(for:)` advancing every ~15s; a small elapsed indicator.
    - Controls: "Amen" / close button ends the session (stops haptics, writes `mindfulSession` for the elapsed span best-effort, sends `.prayed` reaction, dismisses). At full duration it auto-advances to a closing screen showing a verse + "Peace be with you" and the same close button.
    - ALL copy prayer-centric; NO "breath"/"inhale"/"exhale"/"meditate".
  - `PrayerView` change: the button reads "Begin a Time of Prayer", enabled, `.tint(Color.psAccent)`, plays `.click`, presents `PrayerTimeView` via `.fullScreenCover` or `.sheet`.

- [ ] **Step 1: Implement `PrayerTimeView`** (session lifecycle: start on appear, stop on disappear/close; mindfulSession write helper with `try?`).
- [ ] **Step 2: Update `PrayerView`** entry button.
- [ ] **Step 3: Build** watch scheme → SUCCEEDED.
- [ ] **Step 4: Verify in watch simulator.** Boot Watch Series 10 46mm; install; launch to Prayer tab (`-PulseWatchTab 3` if supported, else navigate); confirm "Begin a Time of Prayer" is enabled; enter the session — screenshot the running session `/tmp/p2-prayer-session.png` and the closing screen `/tmp/p2-prayer-close.png`; Read both. Confirm no breathing/meditation copy appears. (Haptic firing can't be seen in a screenshot — confirm the beat ring animates across two screenshots and note the haptic code path in the report.)
- [ ] **Step 5: Commit** — `git commit -m "feat: A Time of Prayer watch session with adaptive heartbeat haptic"`

---

### Task 9: App icon + visual assets

**Files:**
- Create: `Scripts/generate-assets.swift`
- Create (generated, committed): `Pulse/Resources/Assets.xcassets/AppIcon.appiconset/*` (+ `Contents.json`), `PulseWatch/Resources/Assets.xcassets/AppIcon.appiconset/*`, `Pulse/Resources/Assets.xcassets/logo_icon.imageset/*`, `Pulse/Resources/Assets.xcassets/particles_heart.imageset/*`, `particles_cross.imageset/*`.
- Modify: `project.yml` only if an asset-catalog path needs registering (existing catalogs are already in the targets).

**Interfaces:**
- Produces: `Scripts/generate-assets.swift` — a standalone `swift` script using `ImageRenderer` (or Core Graphics `CGContext`) that renders and writes PNGs:
  - 1024×1024 master icon: `#0A0E1A` fill; a gold `#C9A96E` ECG polyline arcing left→right across the vertical center with one tall peak; at the peak, a subtle gold cross (vertical bar + shorter crossbar) integrated into the spike. No text (Apple forbids alpha in the App Store icon — render fully opaque, no rounded corners).
  - iOS AppIcon sizes (single 1024 is sufficient for modern asset catalogs — emit `Contents.json` with the single `"universal" "ios-marketing"`/`"platform":"ios"` 1024 entry that Xcode 15+ accepts) and a watchOS 1024 entry.
  - `logo_icon.png` (512, transparent OK), `particles_heart.png` + `particles_cross.png` (small, ~120px, gold on transparent).

- [ ] **Step 1: Write `Scripts/generate-assets.swift`** and run it: `swift Scripts/generate-assets.swift`. Confirm PNGs + `Contents.json` files are written to the catalogs.
- [ ] **Step 2: Regenerate + build.** `xcodegen generate`; build the iOS scheme; confirm no "missing app icon" warnings and the catalog compiles.
- [ ] **Step 3: Verify the icon renders.** `Read` the generated 1024 master PNG to confirm the ECG→cross design; install to the iPhone 16 sim and screenshot the home screen / app switcher showing the icon `/tmp/p2-icon.png`; Read it.
- [ ] **Step 4: Commit** — `git commit -m "feat: generated app icon (ECG heartbeat to cross) and image assets"`

---

### Task 10: Verification pass + regression sweep

**Files:**
- Create: `docs/verification-phase2.md`
- Modify: whatever the sweep uncovers (minimal fixes only).

**Interfaces:** none new — proves the existing ones.

- [ ] **Step 1: New-element checklist.** In the paired iPhone+Watch simulators, exercise and screenshot each NEW interactive element/process, recording pass/fail + evidence in `docs/verification-phase2.md`:
  - Home header renders unclipped (Task 1).
  - App icon on home screen (Task 9).
  - Verse of the Day card appears + tap opens detail; 8am notification copy (Task 5).
  - Streak widget shows correct 0/1-day state (Task 6).
  - "Begin a Time of Prayer" button enabled; session starts, prompt advances, beat ring animates, Amen closes; closing screen shows a verse; no breathing/meditation copy (Task 8).
  - Settings `includeVerseOfDay` toggle adds/removes the daily notification (verify the scheduler call path + a with-on / with-off run).
- [ ] **Step 2: Regression sweep.** Re-exercise Phase-1 elements and record pass/fail: Home Love/Save/Share/Read More; VerseDetailSheet actions; History filters (All/Loved/Saved/state) + detail; ShareCard export (Classic/Night); Settings (translation change → reconfigure, max/day, quiet hours, metric toggles, clear history); watch Verse/Vitals/History tabs + reactions; complication still renders. Fix anything broken (small, committed separately).
- [ ] **Step 3: Full test + builds.** `swift test --package-path PulseShared` (Phase-1 53 + new PrayerCadence/Streak/VOTD tests, all green); both schemes build.
- [ ] **Step 4: Commit** — `git commit -m "chore: Phase 2 verification pass and regression sweep evidence"`

---

## Self-review notes

- **Spec coverage:** header fix → Task 1; app icon/assets → Task 9; A Time of Prayer (cadence/prompts/haptic/session/HK write/no-meditation copy) → Tasks 2,7,8; Verse of the Day (fetch/scheduler/card/notification/setting-gate) → Tasks 4,5; streaks (calc + widget) → Tasks 3,6; verification + regression → Task 10. All five design features + fix + verification are covered.
- **Placeholder scan:** no TBD/TODO; every code step has concrete code or exact instructions; test bodies are complete.
- **Type consistency:** `PrayerCadence(startBPM:targetBPM:durationSeconds:)`, `beatInterval(atElapsed:)`, `bpm(atElapsed:)` consistent across Tasks 2/7/8; `StreakCalculator.currentStreak(engagementDates:today:calendar:)` / `daysEngagedThisMonth(...)` consistent across Tasks 3/6; `YouVersionClient.fetchVerseOfTheDay(bibleID:abbreviation:day:)` consistent across Tasks 4/5; `VerseDelivery(deliveryMethod:"votd", verseTheme:"verse_of_the_day", ...)` consistent across Tasks 5/6/10.
- **Deferred (design-sanctioned):** Live Activities, sparklines, 3 extra share-card variants, animated onboarding particle field (static particle PNGs are produced in Task 9), Localizable.strings.
