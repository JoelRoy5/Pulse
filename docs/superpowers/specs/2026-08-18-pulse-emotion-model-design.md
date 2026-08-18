# Pulse Emotion Model + Feedback — Design (2026-08-18)

## What this document is

The design for reworking Pulse's user-facing emotional states and adding an
on-device feedback/personalization loop, agreed with Joel on 2026-08-18. Pulse is
live on TestFlight (build 3) with the full biometric → verse pipeline working.
This builds on that; where silent, the existing build design and the Phase 2
design still apply.

## Goal

Replace the twelve poetic-only states with a richer, more relatable set of
**emotions** derived on-device, shown by their plain feeling name, and add a
private feedback loop that learns the user's tendencies. All health data stays on
the device (no raw numbers to any API — unchanged).

## Confirmed decisions

| Decision | Choice |
|---|---|
| Classification location | **On-device** (unchanged). No raw health numbers leave the device. |
| Emotion model | **Energy × mood grid** (3×3) + one contextual override. |
| Relationship to existing states | **Approach 1 — emotion layer over the existing 12 `BiometricState` cases.** The 12 stay internal and keep driving verse themes / share cards / prayer / watch payload. A new `Emotion` layer maps to them. |
| Mood for automatic deliveries | **Conservatively inferred** from biometric context; defaults Neutral. |
| Mood for manual requests | Set directly by the feeling picker / feedback correction; always overrides inference. |
| Name display | **Plain feeling only** (e.g. "Drained"). Poetic names kept internal for verse-theme mapping, never shown. |
| Feedback | **Capture + correct + on-device personalization (private).** No cloud/global learning. |
| "Not helpful" scope | **Per emotion**, never global — a verse unhelpful for *Stressed* can still surface for *Reflective/Restful*. |
| Auto-offer another verse on "not helpful" | **No** — quietly record + down-weight. |
| Feedback placement | **Verse detail sheet only** (no Home chip). |
| Delivery sequencing | **Phase A** (emotion model + naming + display + watch), then **Phase B** (feedback + personalization). Each independently shippable. |

## The emotion grid

Nine plain feelings on a 3×3 energy × mood grid, plus one contextual override.

| Energy \ Mood | Low mood | Neutral | Positive |
|---|---|---|---|
| **Low energy** | Drained | Restful | Content |
| **Medium energy** | Weighed Down | Steady | Grateful |
| **High energy** | Stressed | Driven | Energized |

Contextual override: **Unwell** — when clear illness markers are present it takes
priority over the grid (it is not an energy/mood cell).

Each emotion maps internally to one existing `BiometricState` (which supplies the
`verseTheme` used for selection). Users never see the poetic name.

| Emotion | Energy | Mood | Internal `BiometricState` | Verse theme |
|---|---|---|---|---|
| Drained | Low | Negative | `exhaustedDepleted` | rest_renewal |
| Restful | Low | Neutral | `eveningWindingDown` | evening_rest |
| Content | Low | Positive | `deepRestRecovered` | gratitude_praise |
| Weighed Down | Medium | Negative | `sadWithdrawn` | comfort_hope |
| Steady | Medium | Neutral | `peacefulSteady` | abiding_presence |
| Grateful | Medium | Positive | `deepRestRecovered` | gratitude_praise |
| Stressed | High | Negative | `stressedAnxious` | peace_calm |
| Driven | High | Neutral | `activeEngaged` | purpose_calling |
| Energized | High | Positive | `energizedPostWorkout` | strength_perseverance |
| Unwell | — | — | `sickUnwell` | healing_trust |

(`morningAwakening`, `spiritualAlert`, `peakPerformance` remain valid internal
states the classifier may still map to when strongly indicated; each also has an
`Emotion` display — e.g. morning → Content/Steady, peak → Energized. Exact
fold-in finalized in the plan. No poetic name is ever shown.)

## Classification (energy + mood → Emotion)

Extends the existing `StateClassifier`, reusing the biometric sub-scores it
already computes. It continues to return a `BiometricState` for verse selection;
it additionally derives an `Emotion` for display.

- **Energy row (reliable, from biometrics):** high HR / activity / recent workout
  → High; low activity + good rest → Low; otherwise Medium.
- **Mood column (conservative inference):** default **Neutral**; nudge
  **Positive** on clear good signals (strong sleep efficiency, healthy HRV,
  recovered resting HR); nudge **Negative** on clear stress signals (suppressed
  HRV, poor sleep, elevated resting HR); mixed → Neutral.
- **Precedence:** `Unwell` override → energy×mood grid → low-confidence
  time-of-day default (as today).
- **Mood sources:** automatic deliveries use inferred mood; the picker / feedback
  correction sets mood directly and always wins.
- **Personalization hook:** a stored per-user **mood bias** shifts the
  neutral→positive/negative thresholds based on past corrections (Phase B).

## Naming / display

- Everywhere a state label is shown (Home `StateBannerCard`, verse detail,
  history rows/detail, recent verses, watch), show `Emotion.displayName` — the
  plain feeling word only.
- Poetic `displayName` on `BiometricState` is retained but only for internal
  theme mapping; it is never rendered.
- The watch shows the plain emotion via a new payload field (below).

## Feedback capture (Phase B)

Lives in the **verse detail sheet** only (opened by tapping a verse) — never a
post-delivery modal, so it never nags.

- **"Did this fit?"** → Yes / Not quite. *Not quite* opens the emotion picker to
  **correct** the feeling, then re-delivers a verse for the corrected emotion
  (reuses `FeelingPickerView` + the no-notification `deliverFirstVerse` path). The
  correction is the strongest learning signal.
- **"Was this helpful?"** → Yes / No. *No* down-weights this verse **for this
  emotion only**; it does **not** auto-offer another verse.
- A private **"Your reflections"** stat in Settings (e.g. "You've confirmed the
  feeling 18 of 22 times"). Local only.

## On-device personalization (Phase B, private)

New local SwiftData model `EmotionFeedback`: per response records `timestamp`,
`shownEmotionRaw`, `wasAccurate`, `correctedEmotionRaw?`, `verseReference`,
`verseID`, `wasHelpful`. Nothing leaves the device. Drives two behaviors:

1. **Per-emotion verse down-weighting.** Verses marked "not helpful" for an
   emotion join that emotion's avoid-list, which extends the existing "recent refs
   to avoid" hint sent to Gloo, with a local filter as a backstop. Strictly scoped
   per emotion.
2. **Mood bias.** Accumulated mood corrections nudge the neutral→positive/negative
   thresholds for this user over time (the classification hook above).

## Architecture / new units

- **PulseShared:**
  - `Emotion` enum (9 + `Unwell`) with `energy: EnergyLevel`, `mood: MoodTone`,
    `displayName`, `biometricState` mapping. `EnergyLevel` (low/med/high),
    `MoodTone` (negative/neutral/positive) value types.
  - `StateClassifier` extended: derive energy+mood → `Emotion` from existing
    sub-scores, accepting an optional mood-bias; still returns `BiometricState`.
  - `ClassificationResult` gains the derived `emotion`.
- **iOS (Pulse):**
  - `VerseDelivery` gains `emotionRaw: String?` (additive; lightweight migration +
    backfill from `biometricState`, per `DataMigrations` pattern).
  - `EmotionFeedback` SwiftData model + a personalization service (mood-bias
    computation; per-emotion avoid-list provider). Extends verse-selection
    avoid-refs.
  - Feedback controls in `VerseDetailSheet`; correction reuses `FeelingPickerView`;
    "Your reflections" stat in Settings. All labels show `Emotion.displayName`.
- **Watch:**
  - `VerseDeliveryPayload` gains `emotionName: String` (additive; back-compat
    decode deriving from `stateRaw` when absent, mirroring `stateSymbol`). Watch
    shows the plain emotion. `FeelingPickerView` offers the 9 emotions.

## Error handling / edge cases

- Missing/low biometric data → Medium energy + Neutral mood (or time-of-day
  default when confidence is low), never an error.
- Old cached verses/payloads without `emotionRaw`/`emotionName` decode fine and
  derive the emotion from the internal state (back-compat, as with `stateSymbol`).
- Feedback writes are best-effort; a failed save never blocks the UI.
- Personalization is additive bias only — with no feedback yet, behavior equals
  today's.

## Testing

- Unit tests (PulseShared): energy derivation bands, conservative mood inference
  (neutral default, positive/negative nudges), Emotion→BiometricState mapping,
  mood-bias application, per-emotion down-weight filtering.
- Both schemes build; package suite stays green; device-verify the new emotion
  names on phone + watch and one full feedback-correction round-trip.

## Out of scope (deferred)

Cloud/global learning of feedback, a full ML on-device classifier, expanding
beyond ~10 emotions, and any change to the raw-data privacy stance.

## Acceptance

Done when: the app classifies into the emotion grid on-device; Home/detail/
history/watch show the plain feeling name (no poetic names visible); automatic
deliveries infer mood conservatively while the picker/feedback set it directly;
the detail sheet lets the user confirm/correct the feeling and mark a verse
helpful/not (per-emotion); "not helpful" down-weights only for that emotion and
never auto-offers another verse; personalization (mood bias + per-emotion
avoid-list) runs entirely on-device; all new logic is unit-tested; and Phase A is
shippable independently of Phase B.
