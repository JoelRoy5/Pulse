# Pulse Usage Analytics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture every meaningful user interaction as an anonymous event and send it to PostHog (viewable in dashboards), with a compile-time guarantee that health data is never transmitted, an opt-out, and a durable instrumentation convention.

**Architecture:** A closed `AnalyticsEvent` enum (PulseShared) defines every event and its allowed neutral properties — so `track()` structurally cannot send health data. A pure `AnalyticsQueue` (PulseShared) handles batching/persistence/eviction (unit-tested with a stubbed transport). An iOS `Analytics` service adds the anonymous install ID, opt-out gate, and a `URLSession` POST to PostHog's batch endpoint. Instrumentation lives at shared chokepoints plus a `.trackScreen()` modifier; the watch forwards events through the phone.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, WatchConnectivity, Foundation URLSession, XCTest, XcodeGen. No third-party SDKs.

## Global Constraints

Copied from `docs/superpowers/specs/2026-08-20-pulse-analytics-design.md`. Every task implicitly includes these:

- iOS 17 / watchOS 10. **No third-party dependencies** (Apple frameworks + XcodeGen only — PostHog is reached by plain `URLSession`, no SDK). No force-unwraps in production paths.
- **Analytics NEVER transmits:** any health metric (HR/HRV/sleep/SpO2/steps), the automatic **biometric state classification**, verse text/reference, user name, or any identifier beyond the random install ID. The user-*selected* `Emotion` (feeling picker / correction) MAY be sent; the automatic state MAY NOT.
- The **closed `AnalyticsEvent` enum is the guardrail** — `track()` accepts only that enum. No API surface may accept arbitrary health values.
- Analytics is **best-effort**: no analytics failure may crash, block the UI, or affect the verse pipeline. All network failures are swallowed (queued + retried).
- **On by default**, `UserPreferences.analyticsEnabled` (default `true`); opt-out is immediate (no-op + clear queue).
- Real keys/config via the existing `Config` xcconfig → Info.plist pattern (`$(VAR)`), never hardcoded. PostHog project key is a write-only capture key (safe to ship).
- Commit per task, `feat:`/`test:`/`chore:` messages ending `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. Run `xcodegen generate` after adding files.
- Verification: `swift test --package-path PulseShared`; iOS build `xcodebuild -project Pulse.xcodeproj -scheme Pulse -configuration Debug -destination 'id=5478E7A0-A43A-4573-AEAC-9293549D1E0D' CODE_SIGNING_ALLOWED=NO build`; watch build `-scheme PulseWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)'`.

## Existing interfaces this plan builds on (verified in the tree)

- Test transport: `StubURLProtocol.requestHandler = { request in (HTTPURLResponse, Data) }` + a `stubbedSession()` helper in the PulseShared test target (see `GlooAIClientTests`/`YouVersionClientTests`).
- Config injection: `project.yml` iOS `info.properties` maps Info.plist keys to `$(VAR)` from `Config/*.xcconfig` (e.g. `GlooClientID: $(GLOO_CLIENT_ID)`). `AppConfig` reads them via `Bundle.main.object(forInfoDictionaryKey:)`.
- `UserPreferences` `@Model` (`Pulse/Core/Persistence/PulseSchema.swift`): bool toggles (`includeVerseOfDay`, `useHeartRate`, …), `init()`, `static current(in:)`.
- `SettingsView` (`Pulse/Features/Settings/SettingsView.swift`): `SettingsContentView` renders `privacySection` (add the toggle there).
- Chokepoints: `HomeViewModel.react(_:to:)` + `HistoryViewModel.react(_:to:)` (love/save/share); `ScriptureEngine.persistDelivery` (`onDelivery` hook; `deliveryMethod`); `NotificationService.handleAction(_:deliveryID:context:)`; `VerseDetailSheet` feedback; `FeelingPickerView`; `PrayerTimeView`; watch `WatchSessionManager` + `MainView` tabs.
- `WatchMessage.MessageType` enum (`PulseShared/…/Models/WatchMessage.swift`): add an `analyticsEvent` case; `WatchPayload.dictionary(type:)`/`from(_:)` helpers; `WatchSessionManager` (watch) + `PhoneSessionManager` (phone) route messages.
- `Emotion` (PulseShared): `rawValue`, `displayName`.

## File Structure (end state)

```
PulseShared/Sources/PulseShared/Analytics/
  AnalyticsEvent.swift           # closed enum: name + allowed neutral properties + payload dict
  AnalyticsQueue.swift           # pure batching/persistence/eviction (transport-agnostic)
PulseShared/Tests/PulseSharedTests/
  AnalyticsEventTests.swift
  AnalyticsQueueTests.swift
Pulse/Core/Analytics/
  Analytics.swift                # iOS service: install id, opt-out gate, URLSession→PostHog, flush timing
  AnalyticsConfig.swift          # reads PostHog key/host from Info.plist
  TrackScreen.swift              # .trackScreen("Name") view modifier
  AnalyticsInspectorView.swift   # #if DEBUG event inspector
Pulse/Core/Persistence/PulseSchema.swift   # + UserPreferences.analyticsEnabled
Pulse/Features/Settings/…                  # "Share anonymous usage" toggle
PulseWatch/Core/WatchAnalytics.swift        # watch-side forwarder
docs/privacy-analytics.md                   # privacy-policy section + nutrition labels
CLAUDE.md                                   # the instrumentation build rule
project.yml                                 # PostHog Info.plist keys; Config xcconfig vars
```

---

# PHASE A — Core analytics pipeline

### Task 1: `AnalyticsEvent` catalog (closed enum + payload)

**Files:**
- Create: `PulseShared/Sources/PulseShared/Analytics/AnalyticsEvent.swift`
- Test: `PulseShared/Tests/PulseSharedTests/AnalyticsEventTests.swift`

**Interfaces:**
- Produces (all `public`):
  - `struct AnalyticsEvent: Sendable` — `let name: String`, `let properties: [String: AnalyticsValue]`. Constructed only via static factories (below), never a raw init taking arbitrary health values.
  - `enum AnalyticsValue: Sendable, Equatable` — `case string(String)`, `case int(Int)`, `case double(Double)`, `case bool(Bool)`. `var json: Any`.
  - Static factories, one per event (closed set), e.g.:
    - `static func verseDelivered(method: String) -> AnalyticsEvent` (`method` ∈ auto/manual/votd)
    - `static let verseLoved`, `verseSaved`, `verseShared`, `verseReadMore`, `verseDetailOpened: AnalyticsEvent`
    - `static let feelingPickerOpened`; `static func feelingPicked(emotion: String)`; `static func feedbackFit(answer: String)`, `feedbackHelpful(answer: String)`, `feedbackCorrection(emotion: String)`
    - `static let prayerStarted`; `static func prayerCompleted(durationS: Int)`; `static let prayerAmenEarly`
    - `static func onboardingStepViewed(step: String)`, `permissionResult(kind: String, granted: Bool)`, `static let onboardingCompleted`
    - `static let appOpened`; `static func sessionEnd(durationS: Int)`
    - `static func settingChanged(setting: String)`, `static let analyticsOptOut`
    - `static let votdOpened`, `streakViewed`, `apiFallbackUsed`
    - `static func notificationOpened()`, `notificationAction(action: String)`
    - `static func screenViewed(screen: String, durationS: Int?)`
    - `static func watchOpened()`, `watchTabViewed(tab: String)`, `watchPrayerStarted()`, `watchFeelingRequested()`
  - `func payload(distinctID: String, appVersion: String, platform: String, timestamp: Double) -> [String: Any]` — builds the PostHog capture dict: `["event": name, "distinct_id": distinctID, "properties": <merged props + $app_version + platform + $lib "pulse">, "timestamp": ISO8601]`.

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import PulseShared

final class AnalyticsEventTests: XCTestCase {
    func testFactoryNamesAndProps() {
        XCTAssertEqual(AnalyticsEvent.verseLoved.name, "verse_loved")
        XCTAssertEqual(AnalyticsEvent.verseDelivered(method: "auto").properties["method"], .string("auto"))
        XCTAssertEqual(AnalyticsEvent.feelingPicked(emotion: "grateful").properties["emotion"], .string("grateful"))
        XCTAssertEqual(AnalyticsEvent.prayerCompleted(durationS: 120).properties["duration_s"], .int(120))
    }
    func testPayloadShape() {
        let p = AnalyticsEvent.verseSaved.payload(distinctID: "abc", appVersion: "1.0", platform: "ios", timestamp: 100)
        XCTAssertEqual(p["event"] as? String, "verse_saved")
        XCTAssertEqual(p["distinct_id"] as? String, "abc")
        let props = p["properties"] as? [String: Any]
        XCTAssertEqual(props?["platform"] as? String, "ios")
        XCTAssertEqual(props?["$app_version"] as? String, "1.0")
    }
    // GUARDRAIL: no event/property may carry a health key.
    func testNoDisallowedKeysAcrossAllProperties() {
        let banned = ["heart", "hrv", "hr", "sleep", "spo2", "oxygen", "steps", "state", "biometric", "verse_text", "reference"]
        let all: [AnalyticsEvent] = [
            .verseDelivered(method: "auto"), .verseLoved, .verseSaved, .verseShared, .verseReadMore, .verseDetailOpened,
            .feelingPickerOpened, .feelingPicked(emotion: "grateful"), .feedbackFit(answer: "yes"),
            .feedbackHelpful(answer: "no"), .feedbackCorrection(emotion: "stressed"),
            .prayerStarted, .prayerCompleted(durationS: 60), .prayerAmenEarly,
            .onboardingStepViewed(step: "welcome"), .permissionResult(kind: "health", granted: true), .onboardingCompleted,
            .appOpened, .sessionEnd(durationS: 30), .settingChanged(setting: "translation"), .analyticsOptOut,
            .votdOpened, .streakViewed, .apiFallbackUsed, .notificationOpened(), .notificationAction(action: "love"),
            .screenViewed(screen: "Home", durationS: 5),
            .watchOpened(), .watchTabViewed(tab: "verse"), .watchPrayerStarted(), .watchFeelingRequested()
        ]
        for e in all {
            for key in e.properties.keys {
                for b in banned where b != "state" { // 'state' substring guard below
                    XCTAssertFalse(key.lowercased().contains(b), "event \(e.name) has banned key \(key)")
                }
                XCTAssertNotEqual(key.lowercased(), "state")
            }
        }
    }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --package-path PulseShared` → compile errors.
- [ ] **Step 3: Implement `AnalyticsEvent.swift`** per Interfaces. `AnalyticsValue.json` returns the wrapped scalar. `payload(...)` merges `properties.mapValues(\.json)` with `platform`, `$app_version`, `$lib = "pulse"`; formats `timestamp` as ISO8601. No raw initializer accepting health values exists.
- [ ] **Step 4: Run tests** — PASS; full suite green.
- [ ] **Step 5: Commit** — `git commit -m "feat: closed AnalyticsEvent catalog (health-safe by construction)"`

---

### Task 2: `AnalyticsQueue` (pure batching/persistence/eviction)

**Files:**
- Create: `PulseShared/Sources/PulseShared/Analytics/AnalyticsQueue.swift`
- Test: `PulseShared/Tests/PulseSharedTests/AnalyticsQueueTests.swift`

**Interfaces:**
- Produces:
  - `struct QueuedEvent: Codable, Sendable, Equatable` — the ready-to-send payload dict captured as `Codable` (store the event `name` + a `[String: AnalyticsValue]`-derived `Codable` form; simplest: store `QueuedEvent { let json: Data }` holding pre-serialized JSON of the payload dict). Keep it `Codable` for disk persistence.
  - `final class AnalyticsQueue: @unchecked Sendable` (or an `actor`) — pure logic, transport-agnostic:
    - `init(capacity: Int = 500, batchSize: Int = 20)`
    - `func enqueue(_ payload: Data)` — appends; if count > capacity, drops oldest.
    - `func makeBatch() -> [Data]` — returns up to `batchSize` oldest without removing.
    - `func removeBatch(count: Int)` — removes the first `count` after a successful send.
    - `func requeueFront(_ batch: [Data])` — (no-op if using peek/remove; keep for API clarity) — on failure nothing is removed, so retry is automatic.
    - `var count: Int`
    - `func persist(to url: URL)` / `static func load(from url: URL, capacity: Int, batchSize: Int) -> AnalyticsQueue` — JSON-encode the `[Data]` (base64) array to disk; load restores it. Failures are swallowed (return empty queue).
    - `func clear()`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import PulseShared

final class AnalyticsQueueTests: XCTestCase {
    private func d(_ s: String) -> Data { Data(s.utf8) }
    func testBatchPeekDoesNotRemove() {
        let q = AnalyticsQueue(capacity: 100, batchSize: 2)
        q.enqueue(d("a")); q.enqueue(d("b")); q.enqueue(d("c"))
        XCTAssertEqual(q.makeBatch(), [d("a"), d("b")])
        XCTAssertEqual(q.count, 3) // peek only
        q.removeBatch(count: 2)
        XCTAssertEqual(q.count, 1)
        XCTAssertEqual(q.makeBatch(), [d("c")])
    }
    func testCapacityDropsOldest() {
        let q = AnalyticsQueue(capacity: 2, batchSize: 10)
        q.enqueue(d("a")); q.enqueue(d("b")); q.enqueue(d("c"))
        XCTAssertEqual(q.count, 2)
        XCTAssertEqual(q.makeBatch(), [d("b"), d("c")]) // "a" dropped
    }
    func testPersistAndLoadRoundTrips() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("aq-\(UUID()).json")
        let q = AnalyticsQueue(capacity: 100, batchSize: 5)
        q.enqueue(d("x")); q.enqueue(d("y"))
        q.persist(to: url)
        let loaded = AnalyticsQueue.load(from: url, capacity: 100, batchSize: 5)
        XCTAssertEqual(loaded.makeBatch(), [d("x"), d("y")])
        try? FileManager.default.removeItem(at: url)
    }
    func testClearEmpties() {
        let q = AnalyticsQueue(); q.enqueue(d("a")); q.clear()
        XCTAssertEqual(q.count, 0)
    }
}
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement `AnalyticsQueue.swift`** per Interfaces. Back it with an array of `Data`; guard mutations with an internal `NSLock` (or make it an `actor` and adjust tests to `await`). Persistence encodes `[Data]` as `[String]` (base64) JSON; load swallows any error and returns an empty queue.
- [ ] **Step 4: Run tests** — PASS; full suite green.
- [ ] **Step 5: Commit** — `git commit -m "feat: AnalyticsQueue (batching, disk persistence, capacity eviction)"`

---

### Task 3: `Analytics` service + PostHog transport + config

**Files:**
- Create: `Pulse/Core/Analytics/Analytics.swift`, `Pulse/Core/Analytics/AnalyticsConfig.swift`
- Modify: `project.yml` (add `PostHogKey: $(POSTHOG_KEY)` and `PostHogHost: $(POSTHOG_HOST)` to the iOS `info.properties`), `Config/Debug.xcconfig` + `Config/Release.xcconfig` (add `POSTHOG_KEY`/`POSTHOG_HOST`; templates get placeholders), `Config/*.template`.

**Interfaces:**
- Consumes: `AnalyticsEvent`, `AnalyticsQueue`.
- Produces:
  - `enum AnalyticsConfig` — `static var postHogKey: String` / `postHogHost: String` from `Bundle.main.object(forInfoDictionaryKey:)`; `static var isConfigured: Bool` (non-empty, no `your_`).
  - `@MainActor final class Analytics` — `static let shared`. `func track(_ event: AnalyticsEvent)`; `func flush()`; `var isEnabled: Bool` (backed by the opt-out — set by Task 4). Holds the `AnalyticsQueue` (loaded from Application Support), the install `distinctID` (random UUID persisted in `UserDefaults` key `pulse.analytics.installID`), and app version. `track` builds `event.payload(...)`, JSON-encodes it, `enqueue`s, persists, and flushes if batch full. Flush POSTs `{"batch":[…payloads…], "api_key": key}` to `\(host)/batch/` via `URLSession`; on 2xx `removeBatch`; on failure leave queued. When `!isEnabled`: `track` is a no-op. No force-unwraps; all network in a `Task`; failures logged at debug only.

- [ ] **Step 1: Implement `AnalyticsConfig`** reading `PostHogKey`/`PostHogHost`; add the two keys to `project.yml` iOS `info.properties` and the xcconfig files (real values in gitignored `Config/*.xcconfig`; `your_posthog_key_here` in the `.template`s). `xcodegen generate`.
- [ ] **Step 2: Implement `Analytics`** per Interfaces (install ID, queue load/persist, flush via URLSession to `/batch/`, opt-out no-op, background/threshold flush; a periodic 30s flush timer started on init).
- [ ] **Step 3: Wire lifecycle** — in `PulseApp` `.task`, call `Analytics.shared.track(.appOpened)`; on scene-phase `.background` call `Analytics.shared.flush()`.
- [ ] **Step 4: Build** iOS scheme → SUCCEEDED (transport is exercised by Task-2 queue tests + a manual smoke; no live PostHog call in CI).
- [ ] **Step 5: Commit** — `git commit -m "feat: Analytics service (install id, opt-out gate, PostHog batch transport)"`

---

### Task 4: Opt-out setting + Settings toggle

**Files:**
- Modify: `Pulse/Core/Persistence/PulseSchema.swift` (`UserPreferences.analyticsEnabled: Bool = true`), `Pulse/Features/Settings/SettingsView.swift` + `SettingsViewModel.swift` (toggle in `privacySection`), `Pulse/Core/Analytics/Analytics.swift` (read the pref; `setEnabled(_:)`).

**Interfaces:**
- Produces: `Analytics.shared.setEnabled(_ on: Bool)` — when turning OFF: emit `.analyticsOptOut` (flush it), then set disabled, then `queue.clear()`. When ON: enable.

- [ ] **Step 1: Add `analyticsEnabled: Bool = true`** to `UserPreferences` (additive SwiftData; default true).
- [ ] **Step 2: Add the toggle** to `privacySection`: `Toggle("Share anonymous usage", isOn: …)` bound through `SettingsViewModel`, with a caption "Helps improve Pulse. Never includes your health data or verses." On change → `Analytics.shared.setEnabled(newValue)` and persist the pref; emit `.settingChanged(setting: "analytics")`.
- [ ] **Step 3: Analytics reads the pref at launch** — `Analytics.shared` initializes `isEnabled` from `UserPreferences.current(in:).analyticsEnabled` (via a small accessor; keep the service SwiftData-free by having `PulseApp` push the value in `.task`).
- [ ] **Step 4: Build** iOS → SUCCEEDED. Manually toggle off in the sim and confirm (debug log) that `track` becomes a no-op and the queue clears.
- [ ] **Step 5: Commit** — `git commit -m "feat: analytics opt-out setting (default on) with immediate clear"`

---

# PHASE B — Instrumentation coverage

### Task 5: `.trackScreen()` modifier + apply to screens

**Files:**
- Create: `Pulse/Core/Analytics/TrackScreen.swift`
- Modify: the root of each screen (Home, History, Settings, VerseDetailSheet, each Onboarding step, ShareCard) to add `.trackScreen("Name")`.

**Interfaces:**
- Produces: `extension View { func trackScreen(_ name: String) -> some View }` — on `.onAppear` records the appear time + `Analytics.shared.track(.screenViewed(screen: name, durationS: nil))`; on `.onDisappear` emits `.screenViewed(screen: name, durationS: <elapsed>)`. (Two events per view is fine; dashboards use the first for counts, the second for dwell.)

- [ ] **Step 1: Implement the modifier.**
- [ ] **Step 2: Apply `.trackScreen("<Name>")`** to each screen root listed above (one line each).
- [ ] **Step 3: Build** iOS → SUCCEEDED; in the sim, navigate a few screens and confirm `screen_viewed` events in the debug inspector (Task 9) or console.
- [ ] **Step 4: Commit** — `git commit -m "feat: .trackScreen() modifier + screen-view instrumentation"`

---

### Task 6: Chokepoint instrumentation (interactions)

**Files:**
- Modify: `HomeViewModel.react`, `HistoryViewModel.react` (verse actions), `ScriptureEngine.persistDelivery` (`verse_delivered` with method; `api_fallback_used` when offline), `NotificationService.handleAction` (`notification_action`) + notification-open path (`notification_opened`), `VerseDetailSheet` (`verse_detail_opened`, `feedback_fit`/`feedback_helpful`/`feedback_correction`), `FeelingPickerView` (`feeling_picker_opened`, `feeling_picked`), `PrayerTimeView` (`prayer_started`/`prayer_completed`/`prayer_amen_early`), VOTD card (`votd_opened`), StreakWidget (`streak_viewed` on appear).

**Interfaces:** consumes `Analytics.shared.track(...)`; produces no new types.

- [ ] **Step 1: Instrument verse actions** — in `react(_:to:)`, map `.loved`→`.verseLoved`, `.saved`→`.verseSaved`, `.shared`→`.verseShared`; add `.verseReadMore` on the Read-More link tap. (Toggle-off actions may reuse the same event; dashboards handle it.)
- [ ] **Step 2: Instrument delivery** — in `persistDelivery`, `track(.verseDelivered(method: delivery.deliveryMethod == "votd" ? "votd" : (suppressNotification ? "manual" : "auto")))`. On the offline/fallback path, `track(.apiFallbackUsed)`. **Do NOT include the state/emotion** here.
- [ ] **Step 3: Instrument feedback/feeling/prayer/notifications/VOTD/streak** — one `track()` at each interaction point per the event names above (feeling picker sends the chosen `emotion` string; correction sends the corrected `emotion`).
- [ ] **Step 4: Build** iOS → SUCCEEDED; exercise each in the sim and confirm events fire.
- [ ] **Step 5: Commit** — `git commit -m "feat: instrument verse/feedback/prayer/notification chokepoints"`

---

### Task 7: Onboarding funnel + permissions + session

**Files:**
- Modify: onboarding step views / `OnboardingViewModel` (`onboarding_step_viewed`, `onboarding_completed`), the HealthKit + notification permission result sites (`permission_result`), `PulseApp` scene-phase (`session_end` with duration on background).

- [ ] **Step 1: Instrument onboarding** — `onboarding_step_viewed(step:)` per step appear; `onboarding_completed` on finish.
- [ ] **Step 2: Instrument permissions** — after the HealthKit auth request resolves and after notification auth, `track(.permissionResult(kind: "health"/"notifications", granted:))`.
- [ ] **Step 3: Session duration** — track app foreground time; on `.background`, emit `.sessionEnd(durationS:)` and `flush()`.
- [ ] **Step 4: Build** iOS → SUCCEEDED; run onboarding in the sim and confirm the funnel events.
- [ ] **Step 5: Commit** — `git commit -m "feat: onboarding funnel, permission, and session instrumentation"`

---

# PHASE C — Watch

### Task 8: Watch analytics forwarding

**Files:**
- Create: `PulseWatch/Core/WatchAnalytics.swift`
- Modify: `PulseShared/…/WatchMessage.swift` (`case analyticsEvent = "analytics_event"`), `PulseWatch/Core/WatchSessionManager.swift` (send), `Pulse/Core/Connectivity/PhoneSessionManager.swift` (receive → enqueue into `Analytics`, gated on opt-out), watch call sites (`MainView` tabs, `PrayerView`, `PrayerTimeView`, app launch).

**Interfaces:**
- Produces: `enum WatchAnalytics { static func track(_ event: AnalyticsEvent) }` — serializes `event.payload(distinctID:"watch", …)`… actually the phone owns the distinctID, so the watch sends the event NAME + properties and the phone rebuilds the payload with the shared install ID. Message dict: `{ "type": "analytics_event", "name": <String>, "props": <[String: Any] of AnalyticsValue.json> }`. Watch forwards via `sendMessage` (reachable) else `transferUserInfo`.
- Phone: on `analytics_event`, reconstruct `AnalyticsEvent`-equivalent props and `Analytics.shared.track(...)` (or enqueue the payload built with the phone's distinctID) — discard if analytics disabled.

- [ ] **Step 1: Add the message type + `WatchAnalytics.track`** (watch enqueues + forwards; persists if unreachable, sends on reconnect — reuse the existing WC send pattern).
- [ ] **Step 2: Phone receive handler** — merges the forwarded event into `Analytics` with the phone's install ID; gated on `isEnabled`.
- [ ] **Step 3: Instrument watch** — `watch_opened` (app launch), `watch_tab_viewed(tab:)` (MainView `onChange(selectedTab)`), `watch_prayer_started`, `watch_feeling_requested`.
- [ ] **Step 4: Build both schemes** → SUCCEEDED.
- [ ] **Step 5: Commit** — `git commit -m "feat: watch analytics forwarding through the phone"`

---

# PHASE D — Sustainability, docs, verification

### Task 9: Debug event inspector

**Files:**
- Create: `Pulse/Core/Analytics/AnalyticsInspectorView.swift` (`#if DEBUG`)
- Modify: `Analytics` (a `#if DEBUG` in-memory ring buffer of recent events + a publisher), a hidden entry (e.g. Settings row shown only in DEBUG, or a launch arg `-PulseAnalyticsInspector`).

- [ ] **Step 1: Add a DEBUG ring buffer** to `Analytics` recording the last ~100 events (name + props + time).
- [ ] **Step 2: Build the inspector view** listing them live; wire a DEBUG-only entry point.
- [ ] **Step 3: Build** iOS → SUCCEEDED; confirm events appear as you tap around.
- [ ] **Step 4: Commit** — `git commit -m "feat: debug analytics event inspector"`

---

### Task 10: Build rule (CLAUDE.md) + privacy docs + disclosure

**Files:**
- Modify: `CLAUDE.md` (create if absent) — add the instrumentation rule.
- Create: `docs/privacy-analytics.md` (privacy-policy section + nutrition-label selections from the spec).
- Modify: onboarding final screen — add the one-line disclosure.

- [ ] **Step 1: Add the build rule to `CLAUDE.md`:** "Analytics: every new user-facing action MUST add an `AnalyticsEvent` case + a `track()` call; every new screen MUST add `.trackScreen()`. Analytics must never carry health metrics, the biometric state, or verse content." 
- [ ] **Step 2: Write `docs/privacy-analytics.md`** — paste the spec's privacy-policy "Analytics" section + the exact App Store nutrition-label selections + compliance rationale.
- [ ] **Step 3: Add the onboarding disclosure line** ("Pulse collects anonymous usage to improve. Your health data never leaves your device — manage anytime in Settings.").
- [ ] **Step 4: Build** iOS → SUCCEEDED.
- [ ] **Step 5: Commit** — `git commit -m "docs: analytics build rule (CLAUDE.md) + privacy section + onboarding disclosure"`

---

### Task 11: Verification pass

**Files:** Create `docs/verification-analytics.md`.

- [ ] **Step 1: Full tests + builds** — `swift test --package-path PulseShared` (incl. AnalyticsEvent/Queue tests + the no-health-keys assertion) green; both schemes build.
- [ ] **Step 2: Live smoke (gated, optional)** — with a real PostHog key, toggle on, tap around, confirm events land in the PostHog dashboard; toggle off and confirm collection stops. Record in the doc.
- [ ] **Step 3: Guardrail audit** — grep the instrumentation call sites to confirm no `heartRate`/`hrv`/`state`/`biometricState`/verse text is passed into any `track()`; confirm the closed enum has no health-accepting factory. Record pass/fail.
- [ ] **Step 4: Regression sweep** — verse pipeline, love/save/share, prayer, VOTD, streak, watch tabs still work with analytics on and off.
- [ ] **Step 5: Commit** — `git commit -m "chore: analytics verification pass"`

---

## Self-review notes

- **Spec coverage:** taxonomy → Task 1; queue/batching/offline/eviction → Task 2; service/transport/id/config → Task 3; opt-out default-on → Task 4; `.trackScreen()` → Task 5; chokepoints → Task 6; funnel/permissions/session → Task 7; watch-through-phone → Task 8; debug inspector → Task 9; CLAUDE.md rule + privacy docs + disclosure → Task 10; verification incl. no-health-keys → Tasks 1 & 11. All spec sections covered.
- **Guardrail:** closed `AnalyticsEvent` enum (Task 1) + the no-disallowed-keys unit test + Task 11 audit; delivery instrumentation (Task 6) explicitly excludes state/emotion.
- **Placeholder scan:** pure-logic tasks carry full test code; UI/wiring tasks give concrete event names + sites. No TBD/TODO.
- **Type consistency:** `AnalyticsEvent` factories, `AnalyticsValue`, `payload(distinctID:appVersion:platform:timestamp:)`, `AnalyticsQueue.enqueue/makeBatch/removeBatch/persist/load/clear`, `Analytics.shared.track/flush/setEnabled/isEnabled`, `AnalyticsConfig.postHogKey/postHogHost`, `WatchMessage.MessageType.analyticsEvent`, `UserPreferences.analyticsEnabled` are consistent across tasks.
- **Deferred (spec-sanctioned):** PostHog self-hosting, server-side enrichment, experiments, identified analytics.
```
