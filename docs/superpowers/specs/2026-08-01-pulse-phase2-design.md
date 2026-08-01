# Pulse Phase 2 Design — 2026-08-01

## What this document is

The design for Pulse's Phase 2 round, agreed with Joel on 2026-08-01. Phase 1 (all 20 tasks, full pipeline, live APIs, device-verified) is complete and on `main`. This document governs the Phase 2 build decisions; where silent, the Phase 1 design doc (`docs/superpowers/specs/2026-07-31-pulse-build-design.md`) and the Instructions docs still apply.

## Goal

Ship four Phase-2 features plus a Home header bug fix, and verify functionality of every new button and process:
1. Fix the HomeView top-left header clipping bug.
2. App icon + visual assets.
3. **A Time of Prayer** (watch) — a guided prayer session with an adaptive heartbeat haptic. Explicitly NOT meditation/breathwork.
4. Verse of the Day (YouVersion VOTD endpoint + daily delivery).
5. Streak tracking.
Plus a documented verification pass over every new interactive element and process.

## Confirmed decisions

| Decision | Choice |
|---|---|
| Scope this round | All four features above + header fix + verification pass. Remaining backlog (Live Activities, sparklines, 3 extra share-card variants, onboarding particle animation, Localizable.strings) stays deferred to a later round. |
| Prayer framing | "A Time of Prayer" — prayer + scripture, zero breathing/meditation language. |
| Prayer haptic | **Adaptive wind-down**: read live HealthKit HR at session start, ease the heartbeat-pulse interval down toward a calm resting rate over the session. |
| Prayer HealthKit write | **Yes** — write an `HKCategoryType.mindfulSession` on completion (the only HK write entitlement held); all user-facing copy remains prayer-centric. |
| Icon generation | Deterministic, committed Swift `ImageRenderer` script — no external design tool. |
| Process | TDD for PulseShared logic; subagent-per-task with two-stage review; no force-unwraps; reduce-motion gating; dark-only. |

## Feature designs

### 0. Home header bug fix

**Problem:** `HomeView.swift:94-98` puts a two-line VStack ("Pulse" 22pt + date 13pt) into `ToolbarItem(placement: .navigationBarLeading)` under `.navigationBarTitleDisplayMode(.inline)`. The inline nav bar height clips/cramps the two-line stack — the header is unreadable.

**Fix:** Remove the toolbar item; render the same "Pulse" + date as the first row inside the ScrollView content (matches `Instructions/05_IPHONE_APP.md:164-167`). No toolbar, no clipping. The row scrolls with content, which is the spec's intent.

### 1. App icon + visual assets

- `Scripts/generate-assets.swift` — a macOS `ImageRenderer`/Core Graphics script that renders:
  - `AppIcon` 1024px master: `#0A0E1A` background, gold `#C9A96E` ECG heartbeat line arcing left→right, its tallest peak forming a subtle cross; rounded-square handled by system.
  - Full iOS `AppIcon.appiconset` (all required sizes) + watchOS icon.
  - `logo_icon.png` (share-card wordmark/logo), `particles_heart.png`, `particles_cross.png` (onboarding).
- Output committed under `Pulse/Resources/Assets.xcassets/AppIcon.appiconset`, `PulseWatch/Resources/Assets.xcassets/`, and shared image assets. Script is re-runnable and committed.
- Onboarding `WelcomeView` may use the particle PNGs for a subtle drift effect **only if reduce-motion is off**; particles remain optional polish, not required for acceptance.

### 2. A Time of Prayer (watch)

**Entry:** `PulseWatch/Features/PrayerView.swift` — replace the disabled "Begin Breath Prayer / Coming soon" button with **"Begin a Time of Prayer"**, launching `PrayerTimeView` (full-screen sheet/navigation).

**Session UX:**
- Full-bleed calm gradient (the current verse's state gradient, or `spiritualAlert` if none). A gently pulsing heartbeat ring synced to the haptic.
- Rotating short prayer prompts + a scripture line, drawn from a small bundled prompt set keyed by the current verse's theme (fallback: a general set). Prompts advance every ~15s.
- Duration ~2 minutes; a "Amen / Close" control ends early. Closing screen shows a final verse and a "Peace be with you" line.
- **No breathing or meditation language** anywhere in copy.

**Adaptive heartbeat haptic:**
- `PulseShared/Sources/PulseShared/Logic/PrayerCadence.swift` — pure, testable:
  - `struct PrayerCadence { init(startBPM: Double, targetBPM: Double, durationSeconds: Double); func bpm(atElapsed: Double) -> Double; func beatInterval(atElapsed:) -> TimeInterval }`.
  - `startBPM` = live HR at session start (clamped to a sane 50–120); `targetBPM` = a calm rate (default 60, or personal resting HR when available, clamped ≥ 50); eases start→target with a smooth curve (ease-out) across the duration; never speeds up (target = min(target, start)).
- Watch playback: `PrayerHapticPlayer` (watch target) schedules a **lub-dub** pair per beat (`WKInterfaceDevice.current().play(.click)` twice with a short gap) at `beatInterval(atElapsed:)`, recomputing each beat. Reads HR via the existing `WatchHealthEngine` (HR read type already authorized).
- On completion: write `HKCategoryType.mindfulSession` for the session span (best-effort; failure is silent). Records a `.prayed` reaction against the current verse if one exists.

### 3. Verse of the Day

- `YouVersionClient` gains `func fetchVerseOfTheDay(bibleID:abbreviation:) async throws -> BibleVerse`: GET `/v1/verse_of_the_days/{day}` → `{ day, passage_id }`, then fetch the passage text for the given bible (reuse the passage path). `day` = day-of-year (1–366). Contract per `api-contracts.md`; parse defensively; on failure throw `ScriptureAPIError`.
- `VerseOfDayScheduler` (iOS): if `UserPreferences.includeVerseOfDay`, schedule a daily `UNCalendarNotificationTrigger` at 08:00 local; on fire (and on app foreground if today's VOTD not yet fetched), fetch VOTD and persist a `VerseDelivery` marked VOTD (`deliveryMethod = "votd"`, `verseTheme = "verse_of_the_day"`), bypassing the biometric `DeliveryRulesEngine`. Falls back through the same offline chain (bundled emergency verse) if the API is unavailable.
- Home shows a "Verse of the Day" card (distinct from the state verse) when one exists for today. Respects the setting toggle.
- No raw health data involved (VOTD is date-based) — privacy trivially preserved.

### 4. Streak tracking

- `PulseShared/Sources/PulseShared/Logic/StreakCalculator.swift` — pure, testable:
  - `struct StreakCalculator { func currentStreak(deliveryDates: [Date], today: Date, calendar: Calendar) -> Int; func daysEngagedThisMonth(...) -> (engaged: Int, total: Int) }`.
  - A day "counts" if ≥1 `VerseDelivery` was delivered or engaged that calendar day. Current streak = consecutive days ending today (or yesterday, so an early-morning gap before today's first verse doesn't reset it).
- Home `StreakWidget` (iOS) per `Instructions/05_IPHONE_APP.md:229-233`: "🔥 N-Day Streak", one-line encouragement, "X of Y days this month" progress bar. Computed on read from the `VerseDelivery` `@Query`; no new persistence.

### 5. Verification pass

- **Unit tests** (PulseShared): `PrayerCadenceTests` (start=target no-op, wind-down monotonic non-increasing, clamps, interval math), `StreakCalculatorTests` (0/1/N consecutive, gap resets, yesterday-grace, month counts), `YouVersionClient` VOTD parsing (stubbed transport, success + failure).
- **Interaction verification:** a checklist in `docs/verification-phase2.md` listing every NEW button/process — Home header (renders fully, not clipped), Verse-of-the-Day card + its actions, Streak widget, "Begin a Time of Prayer" button, prayer session controls (start, prompt advance, Amen/close), prayer haptic actually fires, VOTD notification, app icon on home screen — each exercised in the simulator (or on device where required) with a screenshot and pass/fail note. Plus a **regression sweep** re-exercising Phase-1 buttons (Love/Save/Share/Read More, history filters, settings toggles, watch tabs) to confirm nothing broke.

## Architecture / new units

- PulseShared: `PrayerCadence` (logic), `StreakCalculator` (logic), VOTD models + `YouVersionClient.fetchVerseOfTheDay`.
- iOS: header fix in `HomeView`; `VerseOfDayScheduler`, VOTD Home card, `StreakWidget`.
- watch: `PrayerTimeView`, `PrayerHapticPlayer`, prompt content; `PrayerView` entry change.
- assets: `Scripts/generate-assets.swift` + generated catalogs/images.

## Error handling

- Prayer session: missing HR → start at default 70, still winds down to target; haptic failures silent; session always completes cleanly.
- VOTD: any API failure → offline fallback verse; never blocks or errors the UI; a missed 8am fire is retried on next foreground.
- Streak: empty history → 0-day streak, widget shows an encouraging first-verse prompt.

## Out of scope (deferred)

Live Activities, 7-day sparklines, the three remaining share-card variants (Luminous/Dawn/Minimal), onboarding particle *animation* system (static particle assets are produced but an elaborate animated field is deferred), Localizable.strings extraction.

## Acceptance

Done when: header renders fully on all target sizes; a real app icon appears on the home screen and in screenshots; "A Time of Prayer" runs on the watch with an adaptive heartbeat haptic and no meditation framing; Verse of the Day fetches via the YouVersion VOTD endpoint and appears on Home + as an 8am notification (setting-gated); the streak widget shows correct counts; all new logic is unit-tested; and `docs/verification-phase2.md` records every new and regressed button/process as passing.
