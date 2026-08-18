# Pulse Emotion Model + Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show users a richer set of plain-language **emotions** (energy × mood) classified on-device, and add a private verse-detail feedback loop that personalizes to the user.

**Architecture:** A new `Emotion` layer (9 grid cells + `Unwell`) sits over the existing 12 `BiometricState` cases, which stay internal and keep driving verse themes / watch payload / prayer. The `StateClassifier` derives energy+mood → `Emotion` from the biometric sub-scores it already computes; the UI shows the plain feeling. Phase B adds an `EmotionFeedback` store that shifts a personal mood-bias and per-emotion verse avoid-list. All health data stays on-device.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, WatchConnectivity, XCTest, XcodeGen.

## Global Constraints

Copied from `docs/superpowers/specs/2026-08-18-pulse-emotion-model-design.md` and still-binding prior constraints. Every task implicitly includes these:

- Deployment targets iOS 17.0 / watchOS 10.0. Language mode Swift 5. No third-party dependencies (Apple frameworks + XcodeGen only).
- **Zero raw health numbers to any external API** — classification is on-device; only the emotion/state label + recent verse refs are sent to Gloo.
- **No force-unwraps in production paths.** Async via Swift Concurrency; view models `@Observable`.
- **Only the plain `Emotion.displayName` is shown to users.** Poetic `BiometricState.displayName` stays internal (verse-theme mapping) and is never rendered.
- Missing data renders as `—`, never an error. Always-dark app. Reduce-motion gates repeating animations. 44pt min tap targets.
- Additive SwiftData changes only; when data must be derived for existing rows, add an idempotent backfill in `DataMigrations` (never lose user data).
- Real keys stay in gitignored `Config/*.xcconfig`; never commit them. Commit per task with `feat:`/`fix:`/`test:`/`chore:` messages ending `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. Run `xcodegen generate` after adding files.
- Verification commands:
  - Package tests: `swift test --package-path PulseShared`
  - iOS build: `xcodebuild -project Pulse.xcodeproj -scheme Pulse -configuration Debug -destination 'id=5478E7A0-A43A-4573-AEAC-9293549D1E0D' CODE_SIGNING_ALLOWED=NO build`
  - Watch build: `xcodebuild -project Pulse.xcodeproj -scheme PulseWatch -configuration Debug -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' CODE_SIGNING_ALLOWED=NO build`

## Existing interfaces this plan builds on (verified in the tree)

- `BiometricSubScores` (`PulseShared/…/Models/BiometricSubScores.swift`): `hrStress`, `hrvRecovery`, `sleepQuality`, `oxygenLevel`, `activityLevel`, `respiratoryStress` (all `Double` 0–1), `timeOfDay: TimeOfDay`.
- `BiometricState` (`enum`, 12 cases): `displayName`, `abbreviation`, `bodyInterpretation`, `verseTheme`, `systemImageName`, `primaryColorHex`.
- `ClassificationResult`: `state`, `confidence`, `snapshot`, `classifiedAt`, `subScores`. `init(state:confidence:snapshot:classifiedAt:subScores:)`.
- `StateClassifier` (`struct`): `classify(_ snapshot:at:calendar:) -> ClassificationResult`; private `computeSubScores(_:at:calendar:) -> BiometricSubScores`.
- `VerseDelivery` `@Model` (`Pulse/Core/Persistence/PulseSchema.swift`): fields incl. `biometricStateRaw`, `deliveredAt`, `deliveryMethod`, `lovedAt`, `savedAt`; computed `biometricState`.
- `DataMigrations.runOnLaunch(_:)` (`Pulse/Core/Persistence/DataMigrations.swift`): home for idempotent backfills; called from `PulseApp` `.task`.
- `WatchMessage.VerseDeliveryPayload`: custom `init(from:)` already derives `stateSymbol` from `stateRaw` when absent (back-compat pattern to mirror).
- `FeelingPickerView` (`Pulse/Features/Home/FeelingPickerView.swift`): `init(onSelect: (BiometricState) -> Void)`; maps 6 feelings → `BiometricState`.
- `ScriptureEngine`: `deliverFirstVerse(mockState:suppressNotification:)`; `fetchGlooSelection` passes `cache.recentReferences(limit:)` to Gloo as avoid-refs.
- `VerseDetailSheet` (`Pulse/Features/Home/VerseDetailSheet.swift`): shows verse + `DetailActionButton` row; `onReact` callback.
- `StateBannerCard`, `RecentVersesRow`, `HistoryRowView`, `HistoryDetailView`: render `state.displayName` / `state` labels.

## File Structure (end state)

```
PulseShared/Sources/PulseShared/
  Models/Emotion.swift                    # NEW: Emotion, EnergyLevel, MoodTone, grid + mapping
  Logic/EmotionDeriver.swift              # NEW: pure energy+mood → Emotion derivation
  Models/ClassificationResult.swift       # + emotion field
  Logic/StateClassifier.swift             # populate emotion in classify()
PulseShared/Tests/PulseSharedTests/
  EmotionTests.swift                      # NEW
  EmotionDeriverTests.swift               # NEW
  PersonalizationTests.swift              # NEW (Phase B)
Pulse/
  Core/Persistence/PulseSchema.swift      # VerseDelivery.emotionRaw; EmotionFeedback model
  Core/Persistence/DataMigrations.swift   # backfill emotionRaw
  Core/Personalization/PersonalizationStore.swift  # NEW (Phase B)
  Features/Home/VerseDetailSheet.swift    # feedback controls (Phase B)
  Features/Home/StateBannerCard.swift     # show emotion name
  Features/Home/RecentVersesRow.swift     # show emotion name
  Features/History/HistoryRowView.swift   # show emotion name
  Features/History/HistoryDetailView.swift# show emotion name
  Features/Settings/…                      # "Your reflections" stat (Phase B)
PulseShared/…/Models/WatchMessage.swift   # payload emotionName (+ back-compat)
Pulse/Core/Connectivity/PhoneSessionManager.swift  # send emotionName
PulseWatch/Features/VerseView.swift, HistoryView.swift  # show emotion name
```

---

# PHASE A — Emotion model, naming, display, watch

### Task 1: `Emotion` model (grid + mapping)

**Files:**
- Create: `PulseShared/Sources/PulseShared/Models/Emotion.swift`
- Test: `PulseShared/Tests/PulseSharedTests/EmotionTests.swift`

**Interfaces:**
- Produces (all `public`):
  - `enum EnergyLevel: String, Codable, Sendable { case low, medium, high }`
  - `enum MoodTone: String, Codable, Sendable { case negative, neutral, positive }`
  - `enum Emotion: String, Codable, CaseIterable, Identifiable, Sendable` — cases `drained, restful, content, weighedDown="weighed_down", steady, grateful, stressed, driven, energized, unwell`.
    - `var id: String { rawValue }`
    - `var displayName: String` (plain feeling: "Drained", "Restful", "Content", "Weighed Down", "Steady", "Grateful", "Stressed", "Driven", "Energized", "Unwell")
    - `var energy: EnergyLevel` / `var mood: MoodTone` (Unwell → `.medium`/`.neutral`)
    - `var biometricState: BiometricState` (verse-theme mapping per spec table)
    - `static func grid(energy: EnergyLevel, mood: MoodTone) -> Emotion` (returns the grid cell; never `.unwell`)
  - `BiometricState.defaultEmotion: Emotion` — reverse mapping used for backfill when no emotion was stored.

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import PulseShared

final class EmotionTests: XCTestCase {
    func testGridMapping() {
        XCTAssertEqual(Emotion.grid(energy: .low, mood: .negative), .drained)
        XCTAssertEqual(Emotion.grid(energy: .low, mood: .neutral), .restful)
        XCTAssertEqual(Emotion.grid(energy: .low, mood: .positive), .content)
        XCTAssertEqual(Emotion.grid(energy: .medium, mood: .negative), .weighedDown)
        XCTAssertEqual(Emotion.grid(energy: .medium, mood: .neutral), .steady)
        XCTAssertEqual(Emotion.grid(energy: .medium, mood: .positive), .grateful)
        XCTAssertEqual(Emotion.grid(energy: .high, mood: .negative), .stressed)
        XCTAssertEqual(Emotion.grid(energy: .high, mood: .neutral), .driven)
        XCTAssertEqual(Emotion.grid(energy: .high, mood: .positive), .energized)
    }
    func testDisplayNamesArePlain() {
        XCTAssertEqual(Emotion.weighedDown.displayName, "Weighed Down")
        XCTAssertEqual(Emotion.stressed.displayName, "Stressed")
        for e in Emotion.allCases { XCTAssertFalse(e.displayName.isEmpty) }
    }
    func testEveryEmotionMapsToAState() {
        for e in Emotion.allCases { XCTAssertFalse(e.biometricState.verseTheme.isEmpty) }
        XCTAssertEqual(Emotion.stressed.biometricState, .stressedAnxious)
        XCTAssertEqual(Emotion.drained.biometricState, .exhaustedDepleted)
        XCTAssertEqual(Emotion.unwell.biometricState, .sickUnwell)
    }
    func testStateDefaultEmotionRoundTrips() {
        XCTAssertEqual(BiometricState.stressedAnxious.defaultEmotion, .stressed)
        XCTAssertEqual(BiometricState.sickUnwell.defaultEmotion, .unwell)
        for s in BiometricState.allCases { _ = s.defaultEmotion } // total
    }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --package-path PulseShared` → compile errors (no `Emotion`).
- [ ] **Step 3: Implement `Emotion.swift`** with the three types. `grid(energy:mood:)` switches on the 3×3. `displayName`, `energy`, `mood`, `biometricState` per the spec table. Add `extension BiometricState { public var defaultEmotion: Emotion { … } }` mapping every state (grid states → their cell; `morningAwakening`→`.content`, `eveningWindingDown`→`.restful`, `spiritualAlert`→`.steady`, `peakPerformance`→`.energized`, `sickUnwell`→`.unwell`).
- [ ] **Step 4: Run tests** — all pass; full suite green.
- [ ] **Step 5: Commit** — `git commit -m "feat: Emotion energy×mood model mapped over BiometricState"`

---

### Task 2: `EmotionDeriver` (energy + mood from sub-scores)

**Files:**
- Create: `PulseShared/Sources/PulseShared/Logic/EmotionDeriver.swift`
- Test: `PulseShared/Tests/PulseSharedTests/EmotionDeriverTests.swift`

**Interfaces:**
- Consumes: `BiometricSubScores`, `BiometricState`, `Emotion`.
- Produces:
  - `struct EmotionDeriver: Sendable` with `public init()`
    - `public func energy(from s: BiometricSubScores) -> EnergyLevel` — `arousal = max(s.activityLevel, s.hrStress * 0.8)`; `> 0.6 → .high`, `< 0.3 → .low`, else `.medium`.
    - `public func mood(from s: BiometricSubScores, bias: Double = 0) -> MoodTone` — `score = (s.hrvRecovery + s.sleepQuality) / 2 - s.hrStress * 0.5 + bias`; `> 0.55 → .positive`, `< 0.30 → .negative`, else `.neutral`.
    - `public func emotion(for state: BiometricState, subScores: BiometricSubScores, moodBias: Double = 0) -> Emotion` — if `state == .sickUnwell` return `.unwell`; else `.grid(energy: energy(from:), mood: mood(from:bias:))`.

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import PulseShared

final class EmotionDeriverTests: XCTestCase {
    private let d = EmotionDeriver()
    private func scores(hrStress: Double = 0.3, hrvRecovery: Double = 0.6,
                        sleepQuality: Double = 0.6, activity: Double = 0.3) -> BiometricSubScores {
        BiometricSubScores(hrStress: hrStress, hrvRecovery: hrvRecovery, sleepQuality: sleepQuality,
                           oxygenLevel: 0.9, activityLevel: activity, respiratoryStress: 0.2, timeOfDay: .midday)
    }
    func testEnergyBands() {
        XCTAssertEqual(d.energy(from: scores(activity: 0.8)), .high)
        XCTAssertEqual(d.energy(from: scores(hrStress: 0.9, activity: 0.1)), .high) // hrStress*0.8=0.72
        XCTAssertEqual(d.energy(from: scores(hrStress: 0.2, activity: 0.1)), .low)
        XCTAssertEqual(d.energy(from: scores(hrStress: 0.3, activity: 0.45)), .medium)
    }
    func testMoodConservativeDefaultNeutral() {
        XCTAssertEqual(d.mood(from: scores()), .neutral) // (0.6+0.6)/2 - 0.15 = 0.45 → neutral
    }
    func testMoodPositiveOnGoodSignals() {
        XCTAssertEqual(d.mood(from: scores(hrStress: 0.1, hrvRecovery: 0.85, sleepQuality: 0.85)), .positive)
    }
    func testMoodNegativeOnStressSignals() {
        XCTAssertEqual(d.mood(from: scores(hrStress: 0.9, hrvRecovery: 0.25, sleepQuality: 0.25)), .negative)
    }
    func testMoodBiasShiftsToward() {
        let s = scores() // neutral at bias 0
        XCTAssertEqual(d.mood(from: s, bias: 0.2), .positive)   // 0.45+0.2=0.65
        XCTAssertEqual(d.mood(from: s, bias: -0.2), .negative)  // 0.45-0.2=0.25
    }
    func testUnwellOverride() {
        XCTAssertEqual(d.emotion(for: .sickUnwell, subScores: scores(activity: 0.9)), .unwell)
    }
    func testEmotionUsesGridWhenNotSick() {
        XCTAssertEqual(d.emotion(for: .stressedAnxious,
                                 subScores: scores(hrStress: 0.9, hrvRecovery: 0.2, sleepQuality: 0.2, activity: 0.2)),
                       .stressed)
    }
}
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement `EmotionDeriver.swift`** per Interfaces. Clamp `mood` inputs are already 0–1; no clamping of `score` needed for band checks.
- [ ] **Step 4: Run tests** — pass; full suite green.
- [ ] **Step 5: Commit** — `git commit -m "feat: EmotionDeriver (energy + conservative mood from sub-scores)"`

---

### Task 3: Populate `emotion` on `ClassificationResult`

**Files:**
- Modify: `PulseShared/Sources/PulseShared/Models/ClassificationResult.swift`, `PulseShared/Sources/PulseShared/Logic/StateClassifier.swift`
- Test: extend `PulseShared/Tests/PulseSharedTests/EmotionDeriverTests.swift` (or a small `StateClassifier` emotion test).

**Interfaces:**
- Produces: `ClassificationResult.emotion: Emotion` (stored). `init` gains `emotion: Emotion` with a default computed from state for call-site safety: `emotion: Emotion = .steady` is NOT acceptable — instead require it. The classifier computes it via `EmotionDeriver`.

- [ ] **Step 1: Add `public let emotion: Emotion`** to `ClassificationResult` and add `emotion: Emotion` as a required `init` parameter (place after `state`).
- [ ] **Step 2: Update `StateClassifier.classify`** — after choosing `best`/fallback state and `scores`, compute `let emotion = EmotionDeriver().emotion(for: state, subScores: scores)` and pass it into every `ClassificationResult(...)` construction (there are 3: high-confidence, marginal fallback, and low-confidence fallback).
- [ ] **Step 3: Write a failing test** in `EmotionDeriverTests.swift`:

```swift
func testClassifierPopulatesEmotion() {
    var snap = HealthSnapshot()
    snap.heartRate = 120; snap.activeEnergyBurned = 500; snap.stepCount = 8000
    let r = StateClassifier().classify(snap, at: Date(), calendar: .current)
    XCTAssertEqual(r.emotion, EmotionDeriver().emotion(for: r.state, subScores: r.subScores))
}
```

- [ ] **Step 4: Run tests** — pass (fix any other `ClassificationResult(...)` call sites the compiler flags, e.g. in existing tests, by passing `emotion:`). Full suite green.
- [ ] **Step 5: Commit** — `git commit -m "feat: derive Emotion in StateClassifier result"`

---

### Task 4: Persist `emotionRaw` on `VerseDelivery` + backfill

**Files:**
- Modify: `Pulse/Core/Persistence/PulseSchema.swift`, `Pulse/Core/Persistence/DataMigrations.swift`, and the delivery-construction sites (`ScriptureEngine.makeDelivery`/`offlineDelivery` and `VerseOfDayScheduler`).

**Interfaces:**
- Produces: `VerseDelivery.emotionRaw: String?`; computed `VerseDelivery.emotion: Emotion` = `emotionRaw.flatMap(Emotion.init(rawValue:)) ?? biometricState?.defaultEmotion ?? .steady`.

- [ ] **Step 1: Add stored `var emotionRaw: String?`** to `VerseDelivery` (near `biometricStateRaw`) and the computed `emotion` accessor above.
- [ ] **Step 2: Set `emotionRaw` when creating deliveries.** In `ScriptureEngine`, thread the `ClassificationResult.emotion` into `makeDelivery`/`offlineDelivery`/`fallbackChain` so `delivery.emotionRaw = result.emotion.rawValue`. For VOTD (`VerseOfDayScheduler`), set `emotionRaw = BiometricState.morningAwakening.defaultEmotion.rawValue`.
- [ ] **Step 3: Add a backfill** in `DataMigrations` (mirror `backfillLovedAt`): for deliveries where `emotionRaw == nil`, set `emotionRaw = biometricState?.defaultEmotion.rawValue`. Idempotent; call it from `runOnLaunch`.
- [ ] **Step 4: Build** iOS scheme → SUCCEEDED.
- [ ] **Step 5: Commit** — `git commit -m "feat: persist emotionRaw on VerseDelivery with backfill"`

---

### Task 5: Show the plain emotion name (iOS)

**Files:**
- Modify: `Pulse/Features/Home/StateBannerCard.swift`, `Pulse/Features/Home/RecentVersesRow.swift`, `Pulse/Features/History/HistoryRowView.swift`, `Pulse/Features/History/HistoryDetailView.swift`, and `Pulse/DesignSystem/Components/StateChipView.swift` (if it renders a state name).

**Interfaces:** consumes `VerseDelivery.emotion` / `Emotion.displayName`. No new production types.

- [ ] **Step 1: Replace shown state names with the emotion name.** Where a view currently shows `state.displayName` / `delivery.biometricState?.displayName`, show `delivery.emotion.displayName` (or the `Emotion` passed in). `StateBannerCard` takes a `state` today — add an `emotion: Emotion` param (default `state.defaultEmotion`) and render `emotion.displayName.uppercased()`. Keep the `systemImageName` + gradient from the internal `state` (unchanged). Do NOT render any poetic name.
- [ ] **Step 2: Update call sites** to pass the delivery's emotion (Home passes `currentDelivery?.emotion`; history rows use `delivery.emotion`).
- [ ] **Step 3: Build + screenshot.** Launch iPhone-26 sim (`-PulseSkipOnboarding YES -PulseMockState stressed_anxious -PulseAutoDeliver YES`); screenshot `/tmp/emo-home.png`; Read it — banner shows "STRESSED" (plain), no poetic name anywhere.
- [ ] **Step 4: Commit** — `git commit -m "feat: show plain emotion names across iOS"`

---

### Task 6: Carry emotion to the watch + expand picker

**Files:**
- Modify: `PulseShared/…/Models/WatchMessage.swift` (payload `emotionName`), `Pulse/Core/Connectivity/PhoneSessionManager.swift` (send it), `PulseWatch/Features/VerseView.swift` + `HistoryView.swift` (show it), `Pulse/Features/Home/FeelingPickerView.swift` (offer the 9 emotions).

**Interfaces:**
- Produces: `VerseDeliveryPayload.emotionName: String` (additive). Custom `init(from:)` sets `emotionName = decodeIfPresent ?? (BiometricState(rawValue: stateRaw)?.defaultEmotion.displayName ?? stateDisplayName)` — mirroring the existing `stateSymbol` back-compat.

- [ ] **Step 1: Add `emotionName`** to `VerseDeliveryPayload` (stored + `CodingKeys` + memberwise `init` + the custom `init(from:)` back-compat fallback above). Update the two `payloadDict(from:)`/`latestVersePayloadDict` builders in `PhoneSessionManager` and any other payload construction (`HealthSnapshotTests`, `ComplicationViews` sample) to pass `emotionName: delivery.emotion.displayName`.
- [ ] **Step 2: Show it on the watch.** In `VerseView` statePill and `HistoryView` rows, render `verse.emotionName` instead of the derived state display name.
- [ ] **Step 3: Expand the picker.** Change `FeelingPickerView` to present the 9 grid emotions (not the old 6), mapping each via `Emotion` → its `biometricState` for `onSelect`. Keep `Unwell` out of the picker (auto-detected only).
- [ ] **Step 4: Build both schemes; run package tests** (fix the payload-init test for the new field). Watch sim screenshot of the Verse tab showing the plain emotion.
- [ ] **Step 5: Commit** — `git commit -m "feat: send emotion name to watch; picker offers the 9 emotions"`

---

# PHASE B — Feedback + on-device personalization

### Task 7: `EmotionFeedback` model + `PersonalizationStore` (logic)

**Files:**
- Modify: `Pulse/Core/Persistence/PulseSchema.swift` (add `EmotionFeedback` `@Model`; register in the schema).
- Create: `Pulse/Core/Personalization/PersonalizationStore.swift`
- Create: `PulseShared/Sources/PulseShared/Logic/Personalization.swift` (pure math), Test: `PulseShared/Tests/PulseSharedTests/PersonalizationTests.swift`

**Interfaces:**
- Produces:
  - `@Model final class EmotionFeedback` — `id: UUID`, `createdAt: Date`, `shownEmotionRaw: String`, `wasAccurate: Bool`, `correctedEmotionRaw: String?`, `verseReference: String`, `verseID: String`, `wasHelpful: Bool`.
  - Pure `struct Personalization` in PulseShared: `static func moodBias(fromCorrections corrections: [(shown: MoodTone, corrected: MoodTone)]) -> Double` — average of per-correction signed steps (`+0.1` toward positive, `-0.1` toward negative), clamped to `[-0.3, 0.3]`.
  - `@MainActor final class PersonalizationStore` — `init(context: ModelContext)`; `func record(_ feedback: EmotionFeedback)`; `func currentMoodBias() -> Double`; `func downweightedReferences(for emotion: Emotion) -> [String]` (verse refs marked not-helpful for that emotion).

- [ ] **Step 1: Write failing tests** for the pure math:

```swift
import XCTest
@testable import PulseShared

final class PersonalizationTests: XCTestCase {
    func testNoCorrectionsIsZeroBias() {
        XCTAssertEqual(Personalization.moodBias(fromCorrections: []), 0, accuracy: 0.001)
    }
    func testCorrectionsTowardPositiveRaiseBias() {
        let c = [(shown: MoodTone.neutral, corrected: MoodTone.positive),
                 (shown: MoodTone.negative, corrected: MoodTone.positive)]
        XCTAssertGreaterThan(Personalization.moodBias(fromCorrections: c), 0)
    }
    func testBiasClamped() {
        let many = Array(repeating: (shown: MoodTone.negative, corrected: MoodTone.positive), count: 50)
        XCTAssertEqual(Personalization.moodBias(fromCorrections: many), 0.3, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement** `Personalization.moodBias` (PulseShared), then the `EmotionFeedback` `@Model` (add to the `Schema([...])` list in `ModelContainer.makePulseContainer` and the in-memory fallback list in `PulseApp`), then `PersonalizationStore` (fetch feedback; map correction rows to `(MoodTone, MoodTone)` via `Emotion(rawValue:)?.mood`; `downweightedReferences(for:)` filters `wasHelpful == false && shownEmotionRaw == emotion.rawValue`).
- [ ] **Step 4: Run tests + build** — pass; iOS builds (SwiftData migration is additive).
- [ ] **Step 5: Commit** — `git commit -m "feat: EmotionFeedback model + PersonalizationStore"`

---

### Task 8: Apply personalization (mood bias + avoid-list)

**Files:**
- Modify: `Pulse/Core/Scripture/ScriptureEngine.swift` (feed mood bias into emotion derivation; extend Gloo avoid-refs), `Pulse/App/PulseApp.swift` (construct `PersonalizationStore`, expose to engine).

**Interfaces:**
- Consumes: `PersonalizationStore.currentMoodBias()`, `downweightedReferences(for:)`, `EmotionDeriver`.

- [ ] **Step 1: Give `ScriptureEngine` the store.** Add an optional `personalization: PersonalizationStore?` (set in `PulseApp`). When building a delivery, recompute the display emotion with the bias: `let emotion = EmotionDeriver().emotion(for: result.state, subScores: result.subScores, moodBias: personalization?.currentMoodBias() ?? 0)` and persist that `emotionRaw` (the internal `state`/theme is unchanged).
- [ ] **Step 2: Extend the Gloo avoid-refs.** In `fetchGlooSelection`, union `cache.recentReferences(limit: 10)` with `personalization?.downweightedReferences(for: result.emotion) ?? []` before passing to the selector. Add a local backstop: if the returned verse ref is in the down-weighted set, request once more excluding it (best-effort; keep it simple — one retry).
- [ ] **Step 3: Build** iOS → SUCCEEDED.
- [ ] **Step 4: Commit** — `git commit -m "feat: apply mood bias + per-emotion verse avoid-list"`

---

### Task 9: Feedback controls in the verse detail sheet

**Files:**
- Modify: `Pulse/Features/Home/VerseDetailSheet.swift`; consume `PersonalizationStore` + `FeelingPickerView`.

**Interfaces:** consumes `EmotionFeedback`, `PersonalizationStore.record`, `deliverFirstVerse(mockState:suppressNotification:)`.

- [ ] **Step 1: Add a feedback row** below the action buttons: "Did this fit?" → `Yes` / `Not quite`, and "Was this helpful?" → `Yes` / `No`. Use `@State` for the local selections; disable a choice once tapped (visual confirm).
- [ ] **Step 2: Wire behaviors.**
  - "Not quite" → present `FeelingPickerView`; on select, record `EmotionFeedback(wasAccurate: false, correctedEmotionRaw: <picked>.rawValue, …)`, dismiss the sheet, and `Task { await scriptureEngine.deliverFirstVerse(mockState: <picked>.biometricState, suppressNotification: true) }`.
  - "Yes" (fit) → record `wasAccurate: true`.
  - Helpful "Yes"/"No" → record `wasHelpful`; "No" adds the ref to the emotion's down-weight set (via the stored feedback — no auto-offer).
  - All records via `PersonalizationStore.record`; failures are silent.
- [ ] **Step 3: Build + verify** in the sim: open a verse, tap "Not quite" → picker → a new verse delivers; tap Helpful "No" → recorded (no second verse). Screenshot `/tmp/emo-feedback.png`; Read it.
- [ ] **Step 4: Commit** — `git commit -m "feat: verse-detail feedback (fit? / helpful?) with correction re-delivery"`

---

### Task 10: "Your reflections" stat (Settings)

**Files:**
- Modify: the Settings view + `SettingsViewModel` (`Pulse/Features/Settings/`).

- [ ] **Step 1: Add a read-only stat row.** Compute from `EmotionFeedback`: "You've confirmed the feeling N of M times" and "Helpful verses: X of Y". Fetch on appear; render a small `PSCard` section. Local only; no controls.
- [ ] **Step 2: Build + screenshot** Settings `/tmp/emo-reflections.png`; Read it.
- [ ] **Step 3: Commit** — `git commit -m "feat: private 'Your reflections' feedback stats in Settings"`

---

### Task 11: Verification pass

**Files:**
- Create: `docs/verification-emotion-model.md`

- [ ] **Step 1: Full tests + builds.** `swift test --package-path PulseShared` (all green incl. Emotion/Deriver/Personalization); both schemes build.
- [ ] **Step 2: Device/sim checklist** with screenshots: plain emotion names on Home/detail/history/watch (no poetic names visible); automatic delivery infers a sensible mood; picker offers 9 emotions and delivers live; "Not quite" correction re-delivers with no notification; Helpful "No" records and doesn't repeat that verse for that emotion; "Your reflections" counts update. Record pass/fail + evidence.
- [ ] **Step 3: Regression sweep.** Love/Save (independent), Share, VOTD card + 8am notification, streak widget, prayer session + heartbeat circle, watch tabs + hint. Fix anything broken (small, separate commits).
- [ ] **Step 4: Commit** — `git commit -m "chore: emotion model verification pass"`

---

## Self-review notes

- **Spec coverage:** emotion grid → Tasks 1–2; on-device energy+mood + conservative mood → Task 2; internal state mapping preserved → Tasks 1,4; plain-name display → Tasks 5,6; watch emotion + picker → Task 6; feedback capture (detail sheet, correct, per-emotion helpful, no auto-offer) → Task 9; on-device personalization (mood bias + per-emotion avoid-list) → Tasks 7,8; "Your reflections" → Task 10; back-compat/migration → Tasks 4,6; phased A/B → task grouping; verification → Task 11.
- **Placeholder scan:** pure-logic tasks carry full test code; UI tasks give concrete file/behavior steps. No TBD/TODO.
- **Type consistency:** `Emotion` / `EnergyLevel` / `MoodTone`, `Emotion.grid(energy:mood:)`, `BiometricState.defaultEmotion`, `EmotionDeriver.energy/mood/emotion`, `ClassificationResult.emotion`, `VerseDelivery.emotionRaw`/`.emotion`, `VerseDeliveryPayload.emotionName`, `Personalization.moodBias(fromCorrections:)`, `PersonalizationStore.currentMoodBias()/downweightedReferences(for:)` are consistent across tasks.
- **Deferred (spec-sanctioned):** cloud/global learning, on-device ML classifier, >10 emotions, any change to raw-data privacy.
```
