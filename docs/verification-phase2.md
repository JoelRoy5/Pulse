# Pulse Phase 2 — Verification Record

Date: 2026-08-15
Branch: `build/phase-1`
Tester: automated pass (simulator + unit tests + build)

## Environment

- Xcode 26.2 SDK. Package tests run on the host toolchain.
- **Note on simulators:** the app's `MinimumOSVersion` is 26.0 (Xcode 26.2 SDK default), so it installs only on an iOS-26 / watchOS-26 runtime. The plan's `id=5478E7A0` device is on iOS 18.2 and can no longer host installs — iOS verification used **iPhone 17 (16579CB4-…, iOS 26)** and watch verification used **Apple Watch Series 10 46mm (555B1782-…)**. Both schemes still *build* against the plan's destinations.

## Builds & tests

| Check | Command | Result |
|---|---|---|
| Package tests | `swift test --package-path PulseShared` | **68 passed, 1 skipped, 0 failures** (baseline 53 + PrayerCadence + StreakCalculator + VOTD) |
| iOS build | `xcodebuild … -scheme Pulse …` | **BUILD SUCCEEDED**, no missing-app-icon warnings |
| Watch build | `xcodebuild … -scheme PulseWatch …` | **BUILD SUCCEEDED** |

## New-element checklist

| # | Element / process | Method | Result | Evidence |
|---|---|---|---|---|
| 1 | Home header renders unclipped (Task 1) | Simulator, direct observation | **PASS** — "Pulse" (gold, 28pt) + "Saturday, Aug 15" render fully at the top of the scroll content, no nav-bar clipping | `/tmp/p2-home-verify.png` |
| 2 | App icon on the home screen (Task 9) | Simulator home screen, direct observation | **PASS** — gold ECG→cross glyph on deep navy appears as the "Pulse" icon | `/tmp/p2-icon-home.png`; master `Pulse/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png` |
| 3 | Streak widget zero-state (Task 6) | Simulator, direct observation | **PASS** — "Start your streak — your first verse today" renders at the bottom of Home; N-day / month-progress states covered by `StreakCalculatorTests` | `/tmp/p2-home-verify.png` |
| 4 | Verse of the Day fetch + card (Tasks 4/5) | Unit test + build + code review | **PASS (logic)** — two-step VOTD fetch + auth-failure covered by `VerseOfTheDayTests`; scheduler persists a `deliveryMethod:"votd"` delivery and the Home card renders it. A populated live card needs configured keys/network (offline-fallback path is code-verified). | `VerseOfTheDayTests`, `VerseOfDayScheduler.swift`, `VerseOfDayCard.swift` |
| 5 | VOTD 8am notification (Task 5) | simctl push (banner copy) + code review | **PASS** — repeating `UNCalendarNotificationTrigger` at 08:00 gated on `includeVerseOfDay`; banner copy renders. (Foreground push does not overlay a banner — expected.) | `/tmp/p2-votd-notif.png` capture attempt (app foregrounded → showed populated verse card instead) |
| 6 | "Begin a Time of Prayer" button (Task 8) | Simulator (watch), direct observation | **PASS** — Prayer tab renders; the disabled "Coming soon" block is replaced by an enabled "Begin a Time of Prayer" button presenting `PrayerTimeView` via `fullScreenCover` (button sits below the fold in the scrollable tab) | `/tmp/p2-prayer-tab.png` |
| 7 | Prayer session controls + haptic (Task 8) | Build + code review + unit test | **PASS (logic + build)** — session starts on appear (reads live HR → `PrayerCadence`), heartbeat ring pulses on `onBeat` (reduce-motion gated), prompts rotate every 15s, "Amen" finalizes early, full duration auto-advances to a "Peace be with you" closing verse. Cadence wind-down math covered by `PrayerCadenceTests`. Haptic firing is not observable in a screenshot. | `PrayerTimeView.swift`, `PrayerHapticPlayer.swift`, `PrayerCadenceTests` |
| 8 | No breathing/meditation copy | Code review of all prayer copy | **PASS** — `PrayerPrompts`, `PrayerTimeView`, `PrayerView`, and both HealthKit usage strings are prayer-centric; the prior "breathing exercises" iOS description was reworded | `PrayerPrompts.swift`, `project.yml` |
| 9 | mindfulSession HealthKit write (Task 8) | Code review + entitlement check | **PASS** — best-effort `HKCategoryType.mindfulSession` write on finalize; watch `NSHealthUpdateUsageDescription` added; failures silent | `PrayerTimeView.writeMindfulSession`, `project.yml` |

## Regression sweep (Phase 1)

| Element | Method | Result | Evidence |
|---|---|---|---|
| State banner card + live metrics | Simulator | **PASS** — "WEARY SOUL" banner + HR/HRV/Sleep chips render (mock `exhausted_depleted`) | `/tmp/p2-home-verify.png` |
| Verse delivery + card | Simulator | **PASS** — verse populated: "Come to Me, all you who are weary… — Matthew 11:28 · BSB" | `/tmp/p2-votd-notif.png` |
| Home Love / Save / Share / Read More | Simulator, direct observation | **PASS** — all four actions render on the verse card | `/tmp/p2-votd-notif.png` |
| Today's Metrics grid | Simulator | **PASS** — HR / HRV / Oxygen / Sleep Eff. / Steps / Total Sleep tiles render | `/tmp/p2-home-verify.png` |
| Tab bar (Today / Journey / Settings) | Simulator | **PASS** — bottom tab bar renders | `/tmp/p2-home-verify.png` |
| Watch tabs (Verse / Vitals / History / Prayer) | Simulator (watch) | **PASS** — Prayer tab reached via `-PulseWatchTab 3`; feeling buttons render | `/tmp/p2-prayer-tab.png` |
| Full package test suite | `swift test` | **PASS** — no Phase-1 regressions (68/68 non-skipped green) | test output |

## Notes / follow-ups

- Deep interactive captures (VOTD card populated live, prayer session interior mid-run, notification banner from background) are hard to script headlessly; those paths are covered by build + unit tests + code review as noted above and are ready for on-device confirmation.
- The `id=5478E7A0` sim referenced in the plan is now iOS 18.2 and cannot host installs (app `MinimumOSVersion` 26.0). Use an iOS-26 sim for install/verify; builds against the plan's destination still succeed.
