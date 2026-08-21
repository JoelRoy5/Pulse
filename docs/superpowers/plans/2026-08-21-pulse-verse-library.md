# On-Device Verse Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Gloo AI verse selection with an on-device curated verse library, and remove the Gloo client ID/secret from the app.

**Architecture:** A bundled `VerseLibrary.json` in `PulseShared` maps each user-facing `Emotion` to a vetted pool of verse references. A new `LibraryVerseSelector: VerseSelecting` picks from the current emotion's pool minus recently-shown references (the engine already supplies `avoidRepeats`). YouVersion still fetches verse text and VOTD; only the selector changes. `ScriptureEngine`'s pipeline shape is unchanged.

**Tech Stack:** Swift 5.9, SwiftUI, Swift Package (`PulseShared`), XCTest, XcodeGen.

## Global Constraints

- **Phase 1 only:** replace the selector (Gloo → library). Keep YouVersion for verse text + VOTD. VOTD stays the global same-for-all endpoint (unchanged).
- **Library keys** are exactly the 10 `Emotion.rawValue` strings: `drained`, `restful`, `content`, `weighed_down`, `steady`, `grateful`, `stressed`, `driven`, `energized`, `unwell`.
- **Each emotion's `theme`** must equal `Emotion.biometricState.verseTheme` (the string persisted on `VerseDelivery`). See the theme table below — copy verbatim.
- **References** must be plain human-readable form parseable by the existing `USFM.usfm(for:)` (e.g. `"Matthew 11:28-30"`, `"1 John 4:19"`, `"Psalm 34:18"`). No book abbreviations, no chapter-only refs.
- **No force-unwraps / no `try!` in shipping code paths** (project convention). Loader may trap only on a missing/corrupt *bundled* resource (a build error), guarded by an integrity test.
- **Analytics:** no new `AnalyticsEvent` case or `.trackScreen` — selection is internal, no new user-facing action/screen. The library maps emotion → *reference* only; never add verse text, health metrics, or biometric-state classification to any payload.
- **Do not delete `GlooAIClient.swift`** — keep it (unreferenced) and its passing tests; deletion is a later follow-up.

**Emotion → theme → themeDisplayName table (authoritative):**

| emotion (`rawValue`) | theme | themeDisplayName |
|---|---|---|
| `drained` | `rest_renewal` | Rest & Renewal |
| `restful` | `evening_rest` | Evening Rest |
| `content` | `morning_newness` | Morning & Newness |
| `weighed_down` | `comfort_hope` | Comfort & Hope |
| `steady` | `abiding_presence` | Abiding Presence |
| `grateful` | `gratitude_praise` | Gratitude & Praise |
| `stressed` | `peace_calm` | Peace & Calm |
| `driven` | `purpose_calling` | Purpose & Calling |
| `energized` | `strength_perseverance` | Strength & Perseverance |
| `unwell` | `healing_trust` | Healing & Trust |

---

## File Structure

- `PulseShared/Sources/PulseShared/Scripture/ScriptureProtocols.swift` — **modify**: add `emotion` to `VerseSelectionContext`.
- `PulseShared/Sources/PulseShared/Scripture/VerseLibrary.swift` — **create**: `VerseLibrary` model + loader.
- `PulseShared/Sources/PulseShared/Resources/VerseLibrary.json` — **create**: the bundled library data.
- `PulseShared/Sources/PulseShared/Scripture/LibraryVerseSelector.swift` — **create**: the selector.
- `PulseShared/Tests/PulseSharedTests/VerseLibraryTests.swift` — **create**: loader + bundled-integrity tests.
- `PulseShared/Tests/PulseSharedTests/LibraryVerseSelectorTests.swift` — **create**: selector unit tests.
- `Pulse/App/PulseApp.swift` — **modify**: swap selector.
- `Pulse/App/AppConfig.swift` — **modify**: drop Gloo, `isConfigured` needs only YouVersion.
- `Pulse/Core/Scripture/ScriptureEngine.swift` — **modify**: pass `emotion: result.emotion` into the context.
- `project.yml` — **modify**: remove Gloo Info.plist keys; regenerate project.
- `Config/Debug.xcconfig`, `Config/Release.xcconfig` — **modify** (gitignored): remove dead `GLOO_*` lines.
- `docs/verse-library.md` — **create**: human-readable review table.

---

### Task 1: Add `emotion` to `VerseSelectionContext`

**Files:**
- Modify: `PulseShared/Sources/PulseShared/Scripture/ScriptureProtocols.swift` (the `VerseSelectionContext` struct)
- Test: `PulseShared/Tests/PulseSharedTests/VerseLibraryTests.swift` (create; holds this one test for now — Task 2 adds more to it)

**Interfaces:**
- Consumes: `Emotion` (existing), `BiometricState.defaultEmotion` (existing extension in `Emotion.swift`).
- Produces: `VerseSelectionContext.emotion: Emotion` (non-optional stored property; initializer gains `emotion: Emotion? = nil` defaulting to `state.defaultEmotion`).

- [ ] **Step 1: Write the failing test**

Create `PulseShared/Tests/PulseSharedTests/VerseLibraryTests.swift`:

```swift
import XCTest
@testable import PulseShared

final class VerseLibraryTests: XCTestCase {

    // MARK: - VerseSelectionContext.emotion

    func testContextEmotionDefaultsToStateDefaultEmotion() {
        let ctx = VerseSelectionContext(
            state: .stressedAnxious,
            timeOfDay: .morning,
            confidence: 0.9
        )
        XCTAssertEqual(ctx.emotion, BiometricState.stressedAnxious.defaultEmotion)
        XCTAssertEqual(ctx.emotion, .stressed)
    }

    func testContextEmotionExplicitOverride() {
        let ctx = VerseSelectionContext(
            state: .stressedAnxious,
            timeOfDay: .morning,
            confidence: 0.9,
            emotion: .grateful
        )
        XCTAssertEqual(ctx.emotion, .grateful)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd PulseShared && swift test --filter VerseLibraryTests`
Expected: FAIL — `VerseSelectionContext` has no `emotion` argument/member.

- [ ] **Step 3: Add the field and initializer parameter**

In `ScriptureProtocols.swift`, inside `struct VerseSelectionContext`:
- Add stored property after `public var state: BiometricState`:

```swift
    /// The user-facing emotion this delivery represents. The on-device library
    /// keys its verse pools on this. Defaults to `state.defaultEmotion`.
    public var emotion: Emotion
```

- In the initializer, add `emotion: Emotion? = nil` as the **last** parameter (all existing params already have defaults, so appending is source-compatible), and set it inside the body:

```swift
    public init(
        state: BiometricState,
        timeOfDay: TimeOfDay,
        confidence: Double,
        recentStates: [BiometricState] = [],
        translationAbbreviation: String = DefaultBible.abbreviation,
        preferredThemes: [String] = [],
        avoidRepeats: [String] = [],
        emotion: Emotion? = nil
    ) {
        self.state = state
        self.emotion = emotion ?? state.defaultEmotion
        self.timeOfDay = timeOfDay
        self.confidence = confidence
        self.recentStates = recentStates
        self.translationAbbreviation = translationAbbreviation
        self.preferredThemes = preferredThemes
        self.avoidRepeats = avoidRepeats
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd PulseShared && swift test --filter VerseLibraryTests`
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add PulseShared/Sources/PulseShared/Scripture/ScriptureProtocols.swift PulseShared/Tests/PulseSharedTests/VerseLibraryTests.swift
git commit -m "feat: add emotion field to VerseSelectionContext"
```

---

### Task 2: `VerseLibrary` model, loader, and starter JSON

**Files:**
- Create: `PulseShared/Sources/PulseShared/Scripture/VerseLibrary.swift`
- Create: `PulseShared/Sources/PulseShared/Resources/VerseLibrary.json`
- Test: `PulseShared/Tests/PulseSharedTests/VerseLibraryTests.swift` (append)

**Interfaces:**
- Consumes: `Emotion`, `USFM.usfm(for:)` (existing).
- Produces:
  - `struct VerseLibrary: Codable, Sendable` with `let version: Int`, `let emotions: [String: VerseLibrary.Entry]`, `subscript(_ emotion: Emotion) -> Entry?`.
  - `struct VerseLibrary.Entry: Codable, Sendable` with `let theme: String`, `let themeDisplayName: String`, `let verses: [String]`.
  - `static func load(from bundle: Bundle = .module) throws -> VerseLibrary`
  - `static let bundled: VerseLibrary`

- [ ] **Step 1: Write the failing tests (append to `VerseLibraryTests.swift`)**

```swift
    // MARK: - VerseLibrary bundled integrity

    func testBundledLibraryLoads() throws {
        let library = try VerseLibrary.load()
        XCTAssertEqual(library.version, 1)
    }

    func testBundledLibraryHasAllTenEmotions() throws {
        let library = try VerseLibrary.load()
        for emotion in Emotion.allCases {
            let entry = library[emotion]
            XCTAssertNotNil(entry, "missing pool for \(emotion.rawValue)")
            XCTAssertFalse(entry?.verses.isEmpty ?? true, "empty pool for \(emotion.rawValue)")
        }
    }

    func testBundledLibraryThemesMatchBiometricState() throws {
        let library = try VerseLibrary.load()
        for emotion in Emotion.allCases {
            let entry = try XCTUnwrap(library[emotion])
            XCTAssertEqual(entry.theme, emotion.biometricState.verseTheme,
                           "theme mismatch for \(emotion.rawValue)")
        }
    }

    func testBundledLibraryReferencesAllParse() throws {
        let library = try VerseLibrary.load()
        for emotion in Emotion.allCases {
            let entry = try XCTUnwrap(library[emotion])
            for ref in entry.verses {
                XCTAssertNotNil(USFM.usfm(for: ref),
                                "unparseable reference \"\(ref)\" in \(emotion.rawValue)")
            }
        }
    }

    func testBundledLibraryNoDuplicatesWithinPool() throws {
        let library = try VerseLibrary.load()
        for emotion in Emotion.allCases {
            let entry = try XCTUnwrap(library[emotion])
            XCTAssertEqual(Set(entry.verses).count, entry.verses.count,
                           "duplicate reference in \(emotion.rawValue)")
        }
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd PulseShared && swift test --filter VerseLibraryTests`
Expected: FAIL — `VerseLibrary` type does not exist.

- [ ] **Step 3: Create the model + loader**

Create `PulseShared/Sources/PulseShared/Scripture/VerseLibrary.swift`:

```swift
import Foundation

/// On-device curated verse library. Maps each user-facing `Emotion` to a vetted
/// pool of verse references (references only — text is fetched via YouVersion in
/// Phase 1). Loaded from the bundled `VerseLibrary.json`.
public struct VerseLibrary: Codable, Sendable {

    public struct Entry: Codable, Sendable {
        public let theme: String            // == Emotion.biometricState.verseTheme
        public let themeDisplayName: String // human-readable label
        public let verses: [String]         // e.g. ["Matthew 11:28-30", ...]

        public init(theme: String, themeDisplayName: String, verses: [String]) {
            self.theme = theme
            self.themeDisplayName = themeDisplayName
            self.verses = verses
        }
    }

    public let version: Int
    public let emotions: [String: Entry]    // keyed by Emotion.rawValue

    public init(version: Int, emotions: [String: Entry]) {
        self.version = version
        self.emotions = emotions
    }

    public subscript(_ emotion: Emotion) -> Entry? {
        emotions[emotion.rawValue]
    }

    // MARK: - Loading

    public enum LoadError: Error {
        case resourceMissing
    }

    /// Decodes the bundled `VerseLibrary.json`. Throws if the resource is missing
    /// or malformed — an integrity test guards against this shipping.
    public static func load(from bundle: Bundle = .module) throws -> VerseLibrary {
        guard let url = bundle.url(forResource: "VerseLibrary", withExtension: "json") else {
            throw LoadError.resourceMissing
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(VerseLibrary.self, from: data)
    }

    /// The bundled library, decoded once. Traps only on a missing/corrupt bundled
    /// resource (a build error caught by `VerseLibraryTests`), never at runtime.
    public static let bundled: VerseLibrary = {
        do {
            return try load()
        } catch {
            fatalError("VerseLibrary.json failed to load: \(error)")
        }
    }()
}
```

- [ ] **Step 4: Create the starter JSON**

Create `PulseShared/Sources/PulseShared/Resources/VerseLibrary.json`. Use these theme/display-name values verbatim from the table, with a **starter set of references** per emotion (Task 5 expands each pool to full size; this starter must already make every integrity test pass — all 10 keys present, non-empty, parseable, no duplicates):

```json
{
  "version": 1,
  "emotions": {
    "drained": {
      "theme": "rest_renewal",
      "themeDisplayName": "Rest & Renewal",
      "verses": ["Matthew 11:28-30", "Psalm 23:2-3", "Isaiah 40:29-31", "Psalm 62:1-2", "Jeremiah 31:25", "Psalm 116:7", "Mark 6:31", "Exodus 33:14"]
    },
    "restful": {
      "theme": "evening_rest",
      "themeDisplayName": "Evening Rest",
      "verses": ["Psalm 4:8", "Psalm 3:5", "Proverbs 3:24", "Psalm 121:3-4", "Psalm 63:6-7", "Psalm 91:1-2", "Psalm 131:2", "Lamentations 3:22-23"]
    },
    "content": {
      "theme": "morning_newness",
      "themeDisplayName": "Morning & Newness",
      "verses": ["Psalm 118:24", "Lamentations 3:22-23", "Psalm 143:8", "Psalm 90:14", "Psalm 5:3", "Psalm 30:5", "Zephaniah 3:17", "2 Corinthians 4:16"]
    },
    "weighed_down": {
      "theme": "comfort_hope",
      "themeDisplayName": "Comfort & Hope",
      "verses": ["Psalm 34:18", "Matthew 5:4", "Psalm 147:3", "2 Corinthians 1:3-4", "Psalm 42:11", "John 16:33", "Isaiah 41:10", "Psalm 40:1-2"]
    },
    "steady": {
      "theme": "abiding_presence",
      "themeDisplayName": "Abiding Presence",
      "verses": ["John 15:4-5", "Psalm 16:8", "Psalm 46:1-2", "Isaiah 26:3", "Psalm 27:4", "Deuteronomy 31:8", "Psalm 73:26", "Psalm 62:6"]
    },
    "grateful": {
      "theme": "gratitude_praise",
      "themeDisplayName": "Gratitude & Praise",
      "verses": ["Psalm 103:1-2", "1 Thessalonians 5:16-18", "Psalm 100:4-5", "Psalm 118:1", "Psalm 95:1-2", "James 1:17", "Psalm 9:1", "Ephesians 5:20"]
    },
    "stressed": {
      "theme": "peace_calm",
      "themeDisplayName": "Peace & Calm",
      "verses": ["John 14:27", "Philippians 4:6-7", "Psalm 46:10", "Isaiah 26:3", "Matthew 6:34", "1 Peter 5:7", "Psalm 94:19", "Psalm 55:22"]
    },
    "driven": {
      "theme": "purpose_calling",
      "themeDisplayName": "Purpose & Calling",
      "verses": ["Colossians 3:23-24", "Jeremiah 29:11", "Philippians 3:14", "Proverbs 16:3", "Ephesians 2:10", "1 Corinthians 15:58", "Joshua 1:9", "Galatians 6:9"]
    },
    "energized": {
      "theme": "strength_perseverance",
      "themeDisplayName": "Strength & Perseverance",
      "verses": ["Isaiah 40:31", "Philippians 4:13", "2 Timothy 4:7", "Hebrews 12:1-2", "Psalm 18:32-33", "Nehemiah 8:10", "Habakkuk 3:19", "Romans 5:3-4"]
    },
    "unwell": {
      "theme": "healing_trust",
      "themeDisplayName": "Healing & Trust",
      "verses": ["Psalm 103:2-3", "Jeremiah 17:14", "Psalm 41:3", "Isaiah 53:5", "Psalm 34:19", "2 Corinthians 12:9", "Psalm 147:3", "Psalm 30:2"]
    }
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd PulseShared && swift test --filter VerseLibraryTests`
Expected: PASS (all context + integrity tests).

- [ ] **Step 6: Commit**

```bash
git add PulseShared/Sources/PulseShared/Scripture/VerseLibrary.swift PulseShared/Sources/PulseShared/Resources/VerseLibrary.json PulseShared/Tests/PulseSharedTests/VerseLibraryTests.swift
git commit -m "feat: VerseLibrary model, loader, and starter data"
```

---

### Task 3: `LibraryVerseSelector`

**Files:**
- Create: `PulseShared/Sources/PulseShared/Scripture/LibraryVerseSelector.swift`
- Test: `PulseShared/Tests/PulseSharedTests/LibraryVerseSelectorTests.swift`

**Interfaces:**
- Consumes: `VerseLibrary`, `VerseSelectionContext` (now with `.emotion`), `VerseSelecting`, `VerseSelection`, `ScriptureAPIError`.
- Produces:
  - `struct LibraryVerseSelector: VerseSelecting` with `init(library: VerseLibrary = .bundled)`.
  - Internal testable method: `func select<R: RandomNumberGenerator>(for context: VerseSelectionContext, using rng: inout R) throws -> VerseSelection`.

- [ ] **Step 1: Write the failing tests**

Create `PulseShared/Tests/PulseSharedTests/LibraryVerseSelectorTests.swift`:

```swift
import XCTest
@testable import PulseShared

/// Deterministic RNG for tests (SplitMix64).
private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

final class LibraryVerseSelectorTests: XCTestCase {

    private func makeLibrary() -> VerseLibrary {
        VerseLibrary(version: 1, emotions: [
            "stressed": .init(theme: "peace_calm", themeDisplayName: "Peace & Calm",
                              verses: ["John 14:27", "Psalm 46:10", "Matthew 6:34", "1 Peter 5:7"]),
            "grateful": .init(theme: "gratitude_praise", themeDisplayName: "Gratitude & Praise",
                              verses: ["Psalm 100:4-5"])
            // note: no "unwell" entry — used to test the missing-pool path
        ])
    }

    private func context(_ emotion: Emotion, avoid: [String] = []) -> VerseSelectionContext {
        VerseSelectionContext(state: emotion.biometricState, timeOfDay: .morning,
                              confidence: 0.9, avoidRepeats: avoid, emotion: emotion)
    }

    func testPicksFromCorrectPoolWithTheme() throws {
        let selector = LibraryVerseSelector(library: makeLibrary())
        var rng = SeededRNG(seed: 1)
        let selection = try selector.select(for: context(.stressed), using: &rng)
        XCTAssertTrue(["John 14:27", "Psalm 46:10", "Matthew 6:34", "1 Peter 5:7"].contains(selection.reference))
        XCTAssertEqual(selection.theme, "peace_calm")
        XCTAssertEqual(selection.themeDisplayName, "Peace & Calm")
        XCTAssertFalse(selection.isFallback)
        XCTAssertNil(selection.rationale)
    }

    func testHonorsAvoidRepeats() throws {
        let selector = LibraryVerseSelector(library: makeLibrary())
        let avoid = ["John 14:27", "Psalm 46:10", "Matthew 6:34"]
        for seed in UInt64(0)..<50 {
            var rng = SeededRNG(seed: seed)
            let selection = try selector.select(for: context(.stressed, avoid: avoid), using: &rng)
            XCTAssertEqual(selection.reference, "1 Peter 5:7")
            XCTAssertFalse(avoid.contains(selection.reference))
        }
    }

    func testResetsWhenAllAvoided() throws {
        let selector = LibraryVerseSelector(library: makeLibrary())
        let all = ["John 14:27", "Psalm 46:10", "Matthew 6:34", "1 Peter 5:7"]
        var rng = SeededRNG(seed: 7)
        let selection = try selector.select(for: context(.stressed, avoid: all), using: &rng)
        XCTAssertTrue(all.contains(selection.reference))  // reset to full pool, still valid
    }

    func testVarietyAcrossCalls() throws {
        let selector = LibraryVerseSelector(library: makeLibrary())
        var seen = Set<String>()
        var avoid: [String] = []
        for seed in UInt64(0)..<4 {
            var rng = SeededRNG(seed: seed)
            let selection = try selector.select(for: context(.stressed, avoid: avoid), using: &rng)
            seen.insert(selection.reference)
            avoid.append(selection.reference)
        }
        XCTAssertEqual(seen.count, 4, "excluding prior picks should yield 4 distinct verses")
    }

    func testMissingPoolThrows() {
        let selector = LibraryVerseSelector(library: makeLibrary())
        var rng = SeededRNG(seed: 1)
        XCTAssertThrowsError(try selector.select(for: context(.unwell), using: &rng)) { error in
            XCTAssertEqual(error as? ScriptureAPIError, .notConfigured)
        }
    }

    func testAlternatesExcludePick() throws {
        let selector = LibraryVerseSelector(library: makeLibrary())
        var rng = SeededRNG(seed: 3)
        let selection = try selector.select(for: context(.stressed), using: &rng)
        XCTAssertFalse(selection.alternates.contains(selection.reference))
        XCTAssertLessThanOrEqual(selection.alternates.count, 3)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd PulseShared && swift test --filter LibraryVerseSelectorTests`
Expected: FAIL — `LibraryVerseSelector` does not exist.

- [ ] **Step 3: Implement the selector**

Create `PulseShared/Sources/PulseShared/Scripture/LibraryVerseSelector.swift`:

```swift
import Foundation

/// Selects a verse reference from the on-device `VerseLibrary`, keyed on the
/// context's `emotion`. Variety comes from excluding `context.avoidRepeats`
/// (recent + personalization-downweighted references, supplied by the engine)
/// and picking randomly from what remains — every verse in a pool is a vetted
/// fit, so any pick is good. Stateless.
public struct LibraryVerseSelector: VerseSelecting {

    private let library: VerseLibrary

    public init(library: VerseLibrary = .bundled) {
        self.library = library
    }

    public func selectVerse(for context: VerseSelectionContext) async throws -> VerseSelection {
        var rng = SystemRandomNumberGenerator()
        return try select(for: context, using: &rng)
    }

    /// Testable core with an injectable RNG.
    func select<R: RandomNumberGenerator>(
        for context: VerseSelectionContext,
        using rng: inout R
    ) throws -> VerseSelection {
        guard let entry = library[context.emotion], !entry.verses.isEmpty else {
            throw ScriptureAPIError.notConfigured
        }

        let avoid = Set(context.avoidRepeats)
        var candidates = entry.verses.filter { !avoid.contains($0) }
        if candidates.isEmpty { candidates = entry.verses }  // all recently shown — reset

        guard let pick = candidates.randomElement(using: &rng) else {
            throw ScriptureAPIError.notConfigured  // unreachable: candidates is non-empty
        }

        let alternates = Array(candidates.filter { $0 != pick }.prefix(3))
        return VerseSelection(
            reference: pick,
            theme: entry.theme,
            themeDisplayName: entry.themeDisplayName,
            rationale: nil,
            alternates: alternates,
            isFallback: false
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd PulseShared && swift test --filter LibraryVerseSelectorTests`
Expected: PASS (all six tests).

- [ ] **Step 5: Run the full package suite (no regressions)**

Run: `cd PulseShared && swift test`
Expected: PASS — existing tests (including `GlooAIClientTests`) still green.

- [ ] **Step 6: Commit**

```bash
git add PulseShared/Sources/PulseShared/Scripture/LibraryVerseSelector.swift PulseShared/Tests/PulseSharedTests/LibraryVerseSelectorTests.swift
git commit -m "feat: LibraryVerseSelector picks from on-device pools"
```

---

### Task 4: Wire into the app and remove Gloo config

**Files:**
- Modify: `Pulse/Core/Scripture/ScriptureEngine.swift` (the `fetchGlooSelection` context builder, ~lines 152-166)
- Modify: `Pulse/App/PulseApp.swift` (~line 44)
- Modify: `Pulse/App/AppConfig.swift`
- Modify: `project.yml` (remove `GlooClientID` / `GlooClientSecret` from the iOS target Info.plist)
- Modify: `Config/Debug.xcconfig`, `Config/Release.xcconfig` (gitignored — remove dead `GLOO_*` lines)

**Interfaces:**
- Consumes: `LibraryVerseSelector` (Task 3), `VerseSelectionContext.emotion` (Task 1).
- Produces: app now selects via the library; `AppConfig.isConfigured` depends only on `youVersionAppKey`.

- [ ] **Step 1: Thread the emotion into selection**

In `Pulse/Core/Scripture/ScriptureEngine.swift`, in `fetchGlooSelection(for:)`, add `emotion: result.emotion` to the `VerseSelectionContext(...)` initializer call (the same `result.emotion` already used two lines above for `downweightedReferences`):

```swift
        let context = VerseSelectionContext(
            state: result.state,
            timeOfDay: TimeOfDay(date: .now),
            confidence: result.confidence,
            recentStates: [],
            translationAbbreviation: preferredBibleAbbreviation,
            preferredThemes: prefs.preferredThemes,
            avoidRepeats: avoidRefs,
            emotion: result.emotion
        )
```

- [ ] **Step 2: Swap the selector in `PulseApp`**

In `Pulse/App/PulseApp.swift`, in the configured branch, replace the Gloo line:

```swift
            selector = GlooAIClient(clientID: AppConfig.glooClientID, clientSecret: AppConfig.glooClientSecret)
```

with:

```swift
            selector = LibraryVerseSelector()
```

(The `yvc` fetcher assignment and the `else` branch stay unchanged. `import PulseShared` is already present.)

- [ ] **Step 3: Trim `AppConfig`**

In `Pulse/App/AppConfig.swift`:
- Delete the `glooClientID` and `glooClientSecret` computed properties.
- Change `isConfigured` to require only the YouVersion key:

```swift
    /// `true` when the YouVersion key is present and not a `your_…_here`
    /// placeholder. Verse *selection* is on-device (always available); only
    /// text fetching needs this key.
    static var isConfigured: Bool {
        !youVersionAppKey.isEmpty && !youVersionAppKey.contains("your_")
    }
```

- [ ] **Step 4: Remove Gloo keys from `project.yml`**

In `project.yml`, under the `Pulse` target's `info.properties`, delete these two lines:

```yaml
        GlooClientID: $(GLOO_CLIENT_ID)
        GlooClientSecret: $(GLOO_CLIENT_SECRET)
```

Leave `YouVersionAppKey`, `PostHogKey`, `PostHogHost` intact.

- [ ] **Step 5: Remove dead xcconfig lines (gitignored)**

In both `Config/Debug.xcconfig` and `Config/Release.xcconfig`, delete any `GLOO_CLIENT_ID = …` and `GLOO_CLIENT_SECRET = …` lines. (These files are gitignored; edit them in place. If a file doesn't have the lines, skip.)

- [ ] **Step 6: Regenerate the project and build**

Run:
```bash
xcodegen generate
xcodebuild -project Pulse.xcodeproj -scheme Pulse -destination 'generic/platform=iOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`. Confirms the selector swap, `AppConfig` trim, and engine change all compile, and no code still references the removed Gloo properties.

- [ ] **Step 7: Confirm Gloo is no longer referenced by the app**

Run:
```bash
grep -rn "glooClientID\|glooClientSecret\|GlooClientID\|GlooClientSecret\|GlooAIClient(" Pulse project.yml
```
Expected: **no matches** (the only remaining `GlooAIClient` references are its own source file + tests under `PulseShared`, which we intentionally keep).

- [ ] **Step 8: Commit**

```bash
git add Pulse/Core/Scripture/ScriptureEngine.swift Pulse/App/PulseApp.swift Pulse/App/AppConfig.swift project.yml Pulse.xcodeproj
git commit -m "feat: use on-device library selector; remove Gloo keys from app"
```

---

### Task 5: Expand verse pools and write the review doc

**Files:**
- Modify: `PulseShared/Sources/PulseShared/Resources/VerseLibrary.json` (expand every pool)
- Create: `docs/verse-library.md` (human-readable review table)

**Interfaces:**
- Consumes: the theme table (Global Constraints), `USFM.usfm(for:)` (existing parser — every reference must pass it).
- Produces: full library data + review doc. Guarded by the Task 2 integrity tests (all pools non-empty, parseable, no duplicates).

**Curation rubric (apply to every emotion):**
- **Target ≥ 45 references per emotion** (err toward more, per the spec — more variety, longer before repeats).
- Every reference must be a real, well-known, pastorally-fitting verse for that emotion's theme.
- Format must parse via `USFM.usfm(for:)`: `"Book C:V"` or `"Book C:V-E"` (same-chapter range). Full book names only (see the book table in `ScriptureProtocols.swift`); no cross-chapter ranges (e.g. avoid `"Psalm 22:1-23:6"`).
- No duplicates within a pool. A reference may appear in more than one emotion's pool if it genuinely fits both.
- Prefer verses that stand on their own without surrounding context; avoid very long passages.
- Keep the starter references from Task 2 and add to them.

- [ ] **Step 1: Expand each pool in `VerseLibrary.json`**

For each of the 10 emotions, extend the `verses` array to **≥ 45** references following the rubric. Use the Task 2 starters as the beginning of each list. Suggested additional seeds to build from (expand beyond these to reach the target):

- **drained** (`rest_renewal`): Psalm 127:2, Matthew 11:28, Psalm 46:10, Isaiah 41:10, Psalm 55:22, 1 Peter 5:7, Psalm 3:5, Psalm 91:1, Psalm 34:17, Isaiah 40:28, Galatians 6:9, 2 Corinthians 4:16, Psalm 73:26, Deuteronomy 33:12, Psalm 68:19, Isaiah 26:3, Psalm 37:7, Psalm 94:19, John 14:27, Zephaniah 3:17, Psalm 145:14, Psalm axis picks…
- **restful** (`evening_rest`): Psalm 16:7, Psalm 42:8, Psalm 77:6, Psalm 119:62, Job 11:18-19, Psalm 23:1-2, Isaiah 32:18, Psalm 132:4-5 → prefer single verses, Psalm 116:7, Psalm 4:8, Matthew 11:28-30, Psalm 34:4, Psalm 62:1, Proverbs 3:24, Psalm 3:5.
- **content** (`morning_newness`): Psalm 92:1-2, Isaiah 33:2, Psalm 59:16, Psalm 88:13, Psalm 63:1, Mark 1:35, Psalm 108:2, Psalm 57:8, Psalm 65:8, Ecclesiastes 11:6, Psalm 46:5, Psalm 30:5.
- **weighed_down** (`comfort_hope`): Psalm 55:22, Psalm 62:8, Psalm 73:26, Isaiah 43:2, Matthew 11:28, Psalm 46:1, Psalm 31:24, Romans 8:18, Romans 8:28, Psalm 34:17, Psalm 143:7-8, 1 Peter 5:7, Psalm 130:5, John 14:1, Deuteronomy 31:8, Psalm 9:9.
- **steady** (`abiding_presence`): Psalm 23:4, Isaiah 41:10, Joshua 1:9, Psalm 121:7-8, Hebrews 13:5, Psalm 139:7-10, Matthew 28:20, Psalm 145:18, Isaiah 43:2, Zephaniah 3:17, Psalm 16:11, 2 Timothy 1:7, Psalm 112:7, Proverbs 3:5-6, Psalm 37:23-24.
- **grateful** (`gratitude_praise`): Psalm 107:1, Psalm 34:1, Psalm 150:6, Psalm 145:1-2, 1 Chronicles 16:34, Psalm 92:1, Colossians 3:15, Colossians 3:17, Psalm 138:1, Psalm 116:12, Habakkuk 3:18, Philippians 4:4, Psalm 30:12, Psalm 28:7, Psalm 118:24.
- **stressed** (`peace_calm`): Psalm 23:1-3, Psalm 34:4, Isaiah 41:10, Matthew 11:28-30, John 16:33, Psalm 62:1-2, 2 Thessalonians 3:16, Colossians 3:15, Psalm 4:8, Psalm 29:11, Psalm 118:5-6, Philippians 4:8, Psalm 121:1-2, Nahum 1:7, Psalm 3:3-4.
- **driven** (`purpose_calling`): Philippians 4:13, Colossians 3:17, 1 Corinthians 10:31, 2 Timothy 1:9, Proverbs 3:5-6, Psalm 90:17, Matthew 5:16, Romans 12:1-2, Ephesians 3:20, 1 Peter 4:10, Micah 6:8, Isaiah 6:8, Nehemiah 6:3, James 1:22, Proverbs 16:9.
- **energized** (`strength_perseverance`): Joshua 1:9, Isaiah 41:10, 1 Corinthians 16:13, Ephesians 6:10, Psalm 28:7, 2 Corinthians 4:16-17, James 1:12, Galatians 6:9, Romans 8:37, Philippians 3:14, Psalm 46:1, Deuteronomy 31:6, 1 Corinthians 9:24, Hebrews 10:36, Psalm 138:3.
- **unwell** (`healing_trust`): Exodus 15:26, Psalm 6:2, Psalm 38:15, Isaiah 41:10, Jeremiah 30:17, Matthew 8:17, Psalm 73:26, 3 John 1:2, Psalm 91:10, Psalm 121:1-2, Isaiah 40:31, Proverbs 4:20-22, Psalm 42:11, 1 Peter 2:24, Psalm 116:1-2.

(These are seeds — the drafter adds more real, fitting references to reach ≥45 per emotion, keeping each parseable and de-duplicated.)

- [ ] **Step 2: Run the integrity tests against the expanded file**

Run: `cd PulseShared && swift test --filter VerseLibraryTests`
Expected: PASS — every pool non-empty, all references parse, no duplicates, themes match. If a reference fails `testBundledLibraryReferencesAllParse`, fix its formatting (full book name, same-chapter range) or replace it.

- [ ] **Step 3: Add a count assertion for the minimum pool size**

Append to `VerseLibraryTests.swift`:

```swift
    func testBundledLibraryPoolsMeetMinimumSize() throws {
        let library = try VerseLibrary.load()
        for emotion in Emotion.allCases {
            let entry = try XCTUnwrap(library[emotion])
            XCTAssertGreaterThanOrEqual(entry.verses.count, 45,
                "pool for \(emotion.rawValue) has only \(entry.verses.count) verses")
        }
    }
```

Run: `cd PulseShared && swift test --filter VerseLibraryTests`
Expected: PASS.

- [ ] **Step 4: Generate the review doc**

Create `docs/verse-library.md`: a Markdown document with a top note ("Source of truth is `VerseLibrary.json`; edit there. This doc is generated for review.") followed by one section per emotion:

```markdown
## Drained — Rest & Renewal  (`drained` → `rest_renewal`)

- Matthew 11:28-30
- Psalm 23:2-3
- ... (every reference in the pool, one per line)
```

The references and order must match `VerseLibrary.json` exactly.

- [ ] **Step 5: Commit**

```bash
git add PulseShared/Sources/PulseShared/Resources/VerseLibrary.json PulseShared/Tests/PulseSharedTests/VerseLibraryTests.swift docs/verse-library.md
git commit -m "feat: expand verse pools to full size + review doc"
```

---

## Self-Review

**Spec coverage:**
- Library format / JSON keyed by emotion → Task 2 (structure) + Task 5 (content). ✓
- `theme` = `verseTheme`, curated `themeDisplayName` → Task 2 data + `testBundledLibraryThemesMatchBiometricState`. ✓
- Reviewable curation artifact (hybrid) → Task 5 `docs/verse-library.md`. ✓
- `LibraryVerseSelector` + variety/anti-repeat + seeded RNG → Task 3. ✓
- `emotion` on `VerseSelectionContext` (default `state.defaultEmotion`) → Task 1. ✓
- Engine passes `result.emotion` → Task 4 Step 1. ✓
- Selector swap in `PulseApp` → Task 4 Step 2. ✓
- Remove Gloo from `AppConfig`/`project.yml`/xcconfig; `isConfigured` = YouVersion only → Task 4 Steps 3-5. ✓
- Keep `GlooAIClient.swift` + tests → Global Constraints + Task 4 Step 7 grep excludes its source. ✓
- YouVersion text + VOTD unchanged; offline path unchanged → no task touches `YouVersionClient`, `VerseOfDayScheduler`, or the engine's `isOffline` branch. ✓
- Reference-parse integrity → Task 2 `testBundledLibraryReferencesAllParse`. ✓
- ≥45 per pool → Task 5 `testBundledLibraryPoolsMeetMinimumSize`. ✓
- Analytics guardrail (no new event, no verse text/health data) → Global Constraints; no analytics code touched. ✓

**Placeholder scan:** No TBD/TODO in steps. Task 5 verse lists are *data authored during the task* per an explicit rubric with seed sets and a passing/failing test gate — not a code placeholder.

**Type consistency:** `VerseLibrary`, `.Entry{theme,themeDisplayName,verses}`, `subscript(Emotion)->Entry?`, `load(from:)`, `bundled`, `select(for:using:)`, and `VerseSelectionContext.emotion` are used identically across Tasks 1-5. `ScriptureAPIError.notConfigured` and `VerseSelection(reference:theme:themeDisplayName:rationale:alternates:isFallback:)` match the existing definitions in `ScriptureProtocols.swift`.
