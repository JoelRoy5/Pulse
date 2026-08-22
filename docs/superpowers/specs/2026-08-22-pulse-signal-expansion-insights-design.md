# Signal Expansion + Insights — Design

**Date:** 2026-08-22
**Status:** Draft (pending user review)
**Branch target:** new `build/signal-insights` (fork from `main`)

## Problem

State classification only fires a non-neutral state when Watch-sourced signals
(HRV, resting HR, SpO₂, respiration, sleep) are present and the top state clears
0.65 confidence. Consequences observed:

1. **iPhone-only users get almost nothing.** Every non-neutral state is gated on
   Watch data (even Time in Daylight comes from the Watch). Without a Watch the
   classifier falls back to a neutral time-of-day state nearly 100% of the time —
   and does so silently.
2. **The `sick` detector is thin.** It leans on SpO₂ + respiration (motion/contact
   noisy) with no temperature signal, the most specific illness cue.
3. **We can't measure accuracy.** There is no record of classifications (especially
   the neutral/low-confidence ones), so false-alarm and fallback rates are unknown.

## Goals

- Add temperature as an optional signal that **improves `sick` detection**, degrading
  gracefully to today's behavior when absent.
- Collect two more signals — **Time in Daylight** and **Heart Rate Recovery** —
  **observe-first**: recorded for display + tuning, but not yet affecting selection.
- When a classification is a **neutral fallback caused by insufficient data**, invite
  the user to **self-report** how they feel (existing feeling picker) instead of
  silently delivering a neutral verse.
- Persist every classification to an on-device **`ClassificationRecord`** store.
- Surface a user-facing **Insights** view of their emotion over time.

## Scope

**In scope**
- New optional HealthKit reads: `appleSleepingWristTemperature`, `bodyTemperature`
  (already authorized), `timeInDaylight`, `heartRateRecoveryOneMinute`.
- Temperature → `sick` confidence (graceful).
- `ClassificationRecord` SwiftData model + write-on-every-classification.
- Insights view (user-facing, on-device) — **replaces the "Journey" tab** as the middle tab.
- Low-data self-report prompt on Home (reuses the existing feeling picker).
- Analytics for the new screen/action (neutral properties only).

**Out of scope (deferred)**
- **Event-triggered deliveries / inferred workouts / notification cadence** — next spec.
  (Kick-off note: investigate why post-workout verses rarely fire — "Victory Lap"
  requires an actual `HKWorkout` sample, i.e. a started workout; passive movement
  won't trigger it. Also check background-delivery + scheduler cooldowns.)
- **State of Mind** (`HKStateOfMind`, self-logged mood) — its own later spec; it
  reshapes the emotion model.
- **Menstrual cycle** — deferred (permission-sheet friction, sensitive-data App Store
  scrutiny, low fit); revisit as a clearly-explained opt-in later.
- **Tuning "Stressed"** — left as-is this spec; revisit once the log yields data.
- Wiring Daylight / HR-recovery into any confidence function (observe-first only).

## Architecture

The pipeline is unchanged in shape: `MetricCollector` builds a `HealthSnapshot` →
`StateClassifier.classify` → `ClassificationResult` → `ScriptureEngine` delivers.
This spec adds signals to the snapshot, one optional term to one confidence function,
a persistence side-effect at classification time, and a read-only UI over that store.

### 1. New signals + collection (all optional, nil-safe)

Add to `MetricCollector.readTypes` and add matching collector methods:

| Signal | HK type (iOS availability) | Snapshot field |
|---|---|---|
| Sleeping wrist temperature | `.appleSleepingWristTemperature` (iOS 16+) | `sleepingWristTemperature: Double?` (new, °C) |
| Body temperature | `.bodyTemperature` (already authorized) | `bodyTemperature: Double?` (exists) |
| Time in Daylight | `.timeInDaylight` (iOS 17+) | `timeInDaylightMinutes: Double?` (new) |
| Heart rate recovery | `.heartRateRecoveryOneMinute` (iOS 16+) | `heartRateRecoveryBPM: Double?` (new) |

- No new Info.plist usage string — `NSHealthShareUsageDescription` covers all reads.
  The permission sheet gains "Wrist Temperature", "Time in Daylight", and "Heart Rate
  Recovery" toggles.
- Each collector returns `nil` on missing data or query error (existing pattern); a
  missing signal is never an error and never blocks classification.

### 2. Temperature → `sick` detection (graceful)

Extend `StateClassifier.sickConfidence` with an **optional fever term** that only
applies when temperature data is present; when absent, `sickConfidence` is byte-for-byte
today's behavior.

- **Body temperature (thermometer entries):** treated as core-ish; a reading above a
  fever threshold (**≥ 37.5 °C**) yields a `feverScore` scaled toward 1.0 by ~39 °C.
- **Sleeping wrist temperature:** absolute wrist temp is not comparable across people,
  so use **deviation from the user's own rolling baseline** — mean of the last **N = 7**
  nightly readings (stored on-device; see §4). A deviation of **≥ +0.5 °C** starts
  contributing, saturating around **+1.5 °C**. If fewer than **3** baseline nights
  exist, wrist temperature is treated as **absent** (graceful).
- Combine into `feverScore ∈ [0,1]` (max of the two available sources). Fold into sick:
  `sick = base(resp, oxy, hrv) * (1 - w) + feverScore * w`, then the existing `*1.15`,
  with a modest `w` (≈0.25) so temperature meaningfully raises confidence when febrile
  but never solely fabricates a `sick` verdict. Normal (present, non-febrile)
  temperature contributes 0 (no penalty needed; it simply doesn't inflate sick).
- The hard gate stays: `sick` still requires resting HR **and** respiratory rate
  present. Temperature refines, it does not open a new path. (A future refinement
  could let strong fever alone qualify; out of scope here.)

### 3. Observe-first signals (Daylight, HR recovery)

Collected into the snapshot and written to each `ClassificationRecord` (§4), but they
do **not** enter any confidence function. Purpose: display in Insights + gather tuning
data before deciding whether/how they should influence state.

### 4. `ClassificationRecord` store

New SwiftData model, written **once per classification** — delivered *or not* — inside
the pipeline (a hook in `StateClassifier`'s caller so neutral/low-confidence cases are
captured, not just delivered verses):

```
@Model ClassificationRecord {
  timestamp: Date
  emotionRaw: String          // user-facing emotion (Emotion.rawValue)
  stateRaw: String            // internal BiometricState.rawValue
  confidence: Double
  wasNeutralFallback: Bool    // true when the 0.65 bar wasn't cleared
  insufficientData: Bool      // true when key signals were absent (drives §6 prompt)
  signalsPresent: [String]    // e.g. ["hrv","sleep","spo2","respiration","temperature","daylight","hrRecovery"]
  // optional raw values for Insights detail + tuning:
  sleepingWristTempDeviation: Double?
  timeInDaylightMinutes: Double?
  heartRateRecoveryBPM: Double?
}
```

- **`insufficientData`** = the set of *classification-driving* signals present is below a
  threshold (concretely: none of HRV / sleep / resting-HR present → we cannot
  meaningfully classify emotional/physical state). This is distinct from a merely
  middling-but-informed neutral.
- **Retention:** bounded — keep the most recent **~90 days** (or a hard cap of N
  records); prune older on write. Rolling wrist-temp baseline (§2) is derived from this
  store's recent nightly temperature values.
- Nightly wrist-temperature baseline stat can be computed on demand from records; no
  separate store needed.

### 5. Insights view (user-facing, on-device) — replaces the "Journey" tab

The middle tab today is **"Journey"** (`MainTabView` `Tab.history` → `HistoryView`, a
chronological list of past `VerseDelivery`s). It largely duplicates what Home already
shows and adds little, so **Insights replaces it as the middle tab** (rather than a Home
card). `HistoryView` is retired from the tab bar; the tab set becomes
**Today · Insights · Settings**.

- `MainTabView.Tab.history` is renamed to `.insights`; the middle `tabItem` becomes
  `Label("Insights", systemImage: "chart.xyaxis.line")` (or similar) → `InsightsView`.
  The `-PulseInitialTab` launch arg maps both `"insights"` and (legacy) `"journey"` to
  the middle tab so existing screenshot/test flows keep working.
- `HistoryView.swift` is left in the codebase but unreferenced (revert safety, matching
  how `GlooAIClient` was retired); deletion is optional cleanup later.

`InsightsView` shows the user's **emotion** over time (the friendly `Emotion`, never the
raw 12-state):

```
Insights
──────────────────────────────
This week
 Mon Tue Wed Thu Fri Sat Sun
  ◔   ◑   ●   ◑   ◕   ○   ◔      ← one emotion dot per day
[Tap a day →]
 Thu · Drained
 What your body showed: low HRV, short sleep
 Signals used: HRV ✓  Sleep ✓  Temp ✓  Daylight ✓  HR-recovery —
```

- Reads `ClassificationRecord`; groups by day (most representative / most recent
  non-neutral emotion per day, with neutral shown distinctly).
- Detail for a selected entry lists the human-readable "what your body showed" and the
  signals-present set (so the user understands *why*, and sees when data was thin).
- 100% on-device. No editing, no network. Empty state when no records yet.

### 6. Low-data → self-report prompt

When the most recent classification has `insufficientData == true`:

- **Home** shows a gentle prompt card: *"We can't read enough to tell how you're doing
  — how are you feeling?"* → opens the **existing feeling picker**
  (`FeelingPickerView` → `deliverFirstVerse(mockState:)`), which runs the normal live
  pipeline for the chosen emotion.
- This is the primary surface (robust, no notification-timing complexity). Making the
  *automatic notification* in the insufficient-data case use "how are you feeling?" copy
  that deep-links to the picker is a possible enhancement, noted but not required for v1.
- The self-reported delivery is recorded as a normal delivery; the fact that it followed
  an insufficient-data prompt need not be specially flagged beyond existing analytics.

### 7. Permissions / authorization

Add the four read types to `MetricCollector.readTypes`. Re-requesting authorization
with an expanded set surfaces the new toggles on next request; existing grants are
preserved. No new write types. No entitlement change.

## Analytics (per `CLAUDE.md`)

- New screen → `.trackScreen("Insights")`.
- New user action(s): opening Insights, and tapping the low-data self-report prompt →
  add `AnalyticsEvent` case(s) with **neutral properties only** (e.g. event name; no
  emotion/state values beyond the already-allowed user-*selected* emotion for the
  picker, which is existing behavior).
- **Guardrail preserved:** `ClassificationRecord`, the Insights view, and the
  temperature/deviation values are **on-device only**. No health metric, biometric-state
  classification, temperature, or verse content is ever sent to analytics. The user
  viewing their own state history on-device does not touch the "never leaves the device"
  promise.

## Error handling / edge cases

- Any collector failure or missing sample → `nil` → signal absent; classification and
  temperature term behave as if the signal doesn't exist.
- Fewer than 3 baseline nights → wrist temperature ignored.
- Empty `ClassificationRecord` store → Insights shows a friendly empty state; Home
  prompt only appears when there's a recent insufficient-data record.
- Retention prune must not race the baseline computation (both read the same store on
  the main context).

## Testing

**Classifier (`StateClassifierTests`)**
1. Fever body temp (≥37.5 °C) raises `sick` confidence vs. the same snapshot without temp.
2. Wrist-temp deviation ≥ +0.5 °C (with ≥3 baseline nights) raises `sick`; < baseline
   count → no effect.
3. Temperature absent → `sickConfidence` equals the pre-change value (regression guard).
4. Normal present temperature does not inflate `sick`.
5. Daylight / HR-recovery present do **not** change any confidence output.

**`ClassificationRecord`**
6. A record is written for a delivered classification **and** for a neutral fallback.
7. `insufficientData` true when HRV/sleep/resting-HR all absent; false when present.
8. `signalsPresent` reflects exactly the signals in the snapshot.
9. Retention prune keeps ≤ cap / ≤90 days.

**Low-data prompt**
10. Home surfaces the prompt only when the latest record is `insufficientData`; tapping
    routes to the feeling picker.

**Insights**
11. Groups records by day and renders the user-facing emotion (not raw state); empty
    state when no records. The middle tab resolves to `InsightsView` (not `HistoryView`),
    and `-PulseInitialTab insights|journey` both select it.

**Analytics**
12. `.trackScreen("Insights")` fires; opening/prompt events carry no health/state data.

## Rollout

1. Land on `build/signal-insights`; bump `CURRENT_PROJECT_VERSION` for the TestFlight
   build that includes it.
2. Ship observe-first signals + Insights; use the accumulating `ClassificationRecord`
   data to later decide Daylight/HR-recovery wiring and "Stressed" tuning.
3. Next spec: event-triggered deliveries / inferred workouts (starting with the
   sparse-notification investigation).

## Decisions taken (flag to change)

- **Temperature:** absolute fever threshold for logged body temp; rolling 7-night
  baseline deviation for wrist temp (≥3 nights required). Alternative was a single
  absolute wrist-temp threshold — rejected as not comparable across people.
- **Insights entry point:** the **middle tab**, replacing the "Journey"/`HistoryView`
  tab (Today · Insights · Settings). Chosen over a Home card because Journey overlapped
  with Home and added little. `HistoryView` retired from the tab bar (kept in-tree,
  unreferenced).
