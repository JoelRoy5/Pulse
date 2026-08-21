# On-Device Verse Library — Design

**Date:** 2026-08-21
**Status:** Approved (design), pending spec review
**Branch target:** new `build/verse-library` (fork from `main`)

## Problem

Verse *selection* currently runs through **Gloo AI** (`GlooAIClient: VerseSelecting`),
an LLM that picks a reference from the whole Bible for a given `BiometricState`.
Three problems:

1. **Security / cost.** Gloo uses OAuth2 client-credentials, so a **client ID and
   secret ship in the app binary** (`Info.plist` → extractable). It is the single
   highest-value embedded secret in the app, and every selection is a paid LLM call.
2. **Reliability.** An LLM can hallucinate a reference or a citation, and selection
   fails when the network or the Gloo service is down.
3. **No curation control.** We cannot see or vet which verses map to which emotional
   state — the model decides opaquely each time.

## Goal

Replace the Gloo selector with an **on-device curated verse library**: a bundled,
human-reviewable file mapping each user-facing **emotion** to a vetted pool of verse
references. A new `LibraryVerseSelector: VerseSelecting` picks from the current
emotion's pool with anti-repeat variety. **Remove the Gloo ID/secret from the app.**

## Scope (phased)

This spec covers **Phase 1 only**:

- **Replace only the selector** (Gloo → on-device library).
- **Keep YouVersion** as-is for verse *text* fetching and for Verse of the Day (VOTD).
  YouVersion's app key stays; it is low-stakes (a rotatable, free key).
- **VOTD is unchanged** — still the global, same-for-all-users YouVersion endpoint.

**Out of scope (deferred, noted for context):**

- **Phase 2 (future):** bundle public-domain verse *text* (e.g. BSB/WEB/KJV/ASV) and
  drop YouVersion entirely for a fully offline pipeline.
- **Remote-config library updates.** v1 bundles the library in-app. A future
  remote-fetched JSON (a static file, no secret — very different risk from the Gloo
  proxy) is a Phase-2 nicety.
- **Fully unifying the mood-biased banner emotion with the selection emotion** — the
  existing "emotion↔state consistency" follow-up (`docs/follow-ups.md`). This design
  keys selection off the emotion already used for personalization/downweighting; it
  does not claim to close that follow-up.

## Architecture

The codebase already has the clean seam: `ScriptureEngine` selects through the
`VerseSelecting` protocol and fetches through `VerseFetching`
(`PulseShared/.../Scripture/ScriptureProtocols.swift`). Phase 1 is a
protocol-implementation swap plus config cleanup — `ScriptureEngine`'s pipeline
shape is unchanged.

### 1. Library format

A bundled JSON resource, `VerseLibrary.json`, in `PulseShared` (loaded via
`Bundle.module`, like the existing `emergency_verses.json`). Keyed by
**`Emotion.rawValue`** — the 10 user-facing emotions:

```json
{
  "version": 1,
  "emotions": {
    "drained": {
      "theme": "rest_renewal",
      "themeDisplayName": "Rest & Renewal",
      "verses": ["Matthew 11:28-30", "Psalm 23:2-3", "Isaiah 40:29-31", "..."]
    },
    "stressed": {
      "theme": "peace_calm",
      "themeDisplayName": "Peace & Calm",
      "verses": ["John 14:27", "Philippians 4:6-7", "Psalm 46:10", "..."]
    }
    // ... all 10 emotions
  }
}
```

- **`verses`** holds only *references* (not text) — YouVersion fetches the text in
  Phase 1. References use the human-readable form the existing `USFM.usfm(for:)`
  converter already parses (e.g. `"Matthew 11:28-30"`, `"1 John 4:19"`,
  `"Psalm 34:18"`).
- **`theme`** = `Emotion.biometricState.verseTheme` (the string already stored on
  `VerseDelivery` and used downstream). **`themeDisplayName`** is a curated,
  human-readable label. Both live in the file so curation is self-contained.
- The 10 emotions and their themes:

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

Note: there are 12 `BiometricState`s but only 10 `Emotion`s. Keying by emotion means
the two "extra" states (`peakPerformance`, `spiritualAlert`) — which never appear as
a derived `Emotion` — do not get their own pools; their emotion (`energized` /
`steady`) pool is used. This is intentional: the emotion is the product's
user-facing model.

### 2. The reviewable curation artifact (hybrid)

Content is drafted by Claude, reviewed and edited by the user:

- Claude drafts **~25–40 well-known, pastorally-fitting references per emotion**
  (~300 total), each a plain, valid reference.
- `VerseLibrary.json` **is** the review artifact — it is human-readable and grouped by
  emotion. Claude additionally generates a companion **`docs/verse-library.md`** table
  (emotion → theme → the list of references, one per line) so the user can skim and
  approve/trim/add in one place. The markdown is documentation only; the JSON is the
  source of truth the app loads.
- The user's edits go into `VerseLibrary.json` (and, if desired, the doc is
  regenerated to match).

### 3. `LibraryVerseSelector`

New type in `PulseShared/Sources/PulseShared/Scripture/LibraryVerseSelector.swift`,
conforming to `VerseSelecting`:

```swift
public struct LibraryVerseSelector: VerseSelecting {
    public init(library: VerseLibrary = .bundled)   // .bundled loads VerseLibrary.json
    public func selectVerse(for context: VerseSelectionContext) async throws -> VerseSelection
}
```

**Selection logic** (stateless, deterministic-under-injected-RNG):

1. `emotion = context.emotion` (see §5 — a new field on the context).
2. `pool = library[emotion].verses`. If the emotion is missing or its pool is empty,
   `throw ScriptureAPIError.notConfigured` — the engine's existing fallback chain
   then handles it (this should never happen; a test asserts all 10 pools are
   non-empty).
3. `candidates = pool` minus `context.avoidRepeats` (the engine already passes recent
   references + personalization-downweighted references here).
4. If `candidates` is empty (everything recently shown), reset `candidates = pool`.
5. Pick **`candidates.randomElement(using: &rng)`**. A random pick from *pool minus
   recently-shown* is what produces variety — every verse in the pool is a vetted fit,
   so any pick is good, and excluding recents guarantees a different verse until the
   pool cycles. `rng` is an injectable `RandomNumberGenerator` (defaults to
   `SystemRandomNumberGenerator`) so tests are deterministic.
6. Return `VerseSelection(reference: pick, theme: entry.theme,
   themeDisplayName: entry.themeDisplayName, rationale: nil,
   alternates: <up to 3 other candidates>, isFallback: false)`.

This deliberately replaces the earlier "least-recently-shown" phrasing: the selector
is stateless (it has no per-verse history), and *random-from-candidates-excluding-recents*
achieves the same variety goal more simply. The engine owns recency via `avoidRepeats`.

### 4. `VerseLibrary` model + loader

`PulseShared/Sources/PulseShared/Scripture/VerseLibrary.swift`:

```swift
public struct VerseLibrary: Codable, Sendable {
    public struct Entry: Codable, Sendable {
        public let theme: String
        public let themeDisplayName: String
        public let verses: [String]
    }
    public let version: Int
    public let emotions: [String: Entry]         // keyed by Emotion.rawValue

    public subscript(_ emotion: Emotion) -> Entry? { emotions[emotion.rawValue] }

    /// Loaded once from the bundled VerseLibrary.json; traps only if the bundled
    /// resource is missing or malformed (a build error we catch in tests, not a
    /// runtime condition).
    public static let bundled: VerseLibrary = { /* decode Bundle.module resource */ }()
}
```

### 5. Threading the emotion into selection

`VerseSelectionContext` today carries `state: BiometricState` but not the emotion.
Add a field:

```swift
public var emotion: Emotion   // the user-facing emotion this delivery represents
```

- Add it to the initializer with a default derived from state
  (`state.defaultEmotion`) so existing call sites and tests keep compiling.
- In `ScriptureEngine.fetchGlooSelection(for:)` populate `emotion: result.emotion`
  (the same value already used to compute `avoidRepeats`/downweighting), keeping
  selection consistent with personalization.
- `GlooAIClient` simply ignores the new field (it is being removed anyway, but this
  keeps the protocol single and the change minimal). Optionally rename
  `fetchGlooSelection` → `fetchSelection` for clarity (cosmetic).

### 6. Wiring + config cleanup (remove Gloo)

- **`Pulse/App/PulseApp.swift`** — in the configured branch, replace
  `selector = GlooAIClient(...)` with `selector = LibraryVerseSelector()`. The
  offline branch keeps `OfflineFallbackSelector()` (offline still routes through the
  engine's `FallbackVerseProvider`, which carries bundled *text* — unchanged in
  Phase 1).
- **`Pulse/App/AppConfig.swift`** — remove `glooClientID` / `glooClientSecret`;
  `isConfigured` now requires **only** `youVersionAppKey` (non-empty, no `your_`
  placeholder).
- **`project.yml`** — remove `GlooClientID` / `GlooClientSecret` from the iOS target's
  `Info.plist` properties. Regenerate the project (`xcodegen`).
- **`Config/Debug.xcconfig` / `Config/Release.xcconfig`** (gitignored) — the
  `GLOO_CLIENT_ID` / `GLOO_CLIENT_SECRET` lines become dead; remove them. (No secret
  leaves git; this just stops shipping them in the binary.)
- **`GlooAIClient.swift`** — **keep the file but stop referencing it from the app.**
  It still conforms to `VerseSelecting` and its tests still pass; leaving it avoids a
  churny deletion and preserves the option to revert. (A follow-up may delete it once
  the library is proven in TestFlight.)

### 7. Offline / failure behavior

Reliability *improves*: selection is now on-device and never needs the network.

- **Online (YouVersion configured):** `LibraryVerseSelector` picks a reference →
  `YouVersionClient` fetches text. If the *fetch* fails, the engine's existing
  fallback chain (`fetchVerse` → `FallbackVerseProvider`) covers it, exactly as today.
- **Offline / unconfigured:** unchanged — `ScriptureEngine.runPipeline`'s `isOffline`
  path uses `FallbackVerseProvider` (bundled text). The library isn't consulted
  offline in Phase 1 because it has no text; Phase 2 changes that.

## Analytics

No new user-facing action or screen is introduced (selection is internal), so no new
`AnalyticsEvent` case is required per `CLAUDE.md`. Existing `verseDelivered`
tracking is unchanged. **Guardrail preserved:** the library maps emotion → *reference*,
and nothing in this change adds verse text, health metrics, or biometric-state
classification to any analytics payload.

## Testing

Unit tests for `LibraryVerseSelector` (inject a small stub `VerseLibrary` and a
seeded RNG):

1. **Picks from the right pool** — a `stressed` context returns a reference that is in
   the `stressed` pool, with `theme == "peace_calm"` and the matching display name.
2. **Honors `avoidRepeats`** — references in `avoidRepeats` are never returned while
   other candidates remain.
3. **Cycles without starving** — when `avoidRepeats` covers the entire pool, it resets
   and still returns a valid reference (never empty/throws for a non-empty pool).
4. **Variety** — with a seeded RNG and a multi-verse pool, repeated calls (excluding
   the previous pick via `avoidRepeats`) yield different references.
5. **Missing/empty pool** — an emotion absent from the library throws
   `ScriptureAPIError.notConfigured`.
6. **Theme mapping** — `theme`/`themeDisplayName` come from the library entry, and
   `isFallback == false`, `rationale == nil`.

Bundled-library integrity test (on `VerseLibrary.bundled`):

7. **All 10 emotions present, every pool non-empty**, and **every reference parses**
   via `USFM.usfm(for:)` (guards against a typo'd reference that YouVersion can't
   fetch). `version == 1`.

Context/wiring:

8. `VerseSelectionContext` gains `emotion` with a state-derived default; existing
   initializer call sites still compile (compile-time check + a small test asserting
   the default equals `state.defaultEmotion`).

## Rollout

1. Land behind the existing config gate — when YouVersion is configured, the library
   selector is live immediately.
2. Draft library + `docs/verse-library.md`, user reviews/edits the JSON.
3. Ship in the next TestFlight build (bump `CURRENT_PROJECT_VERSION`).
4. After it's proven, optional follow-ups: delete `GlooAIClient`, then Phase 2
   (bundle text, drop YouVersion).
