# Pulse Usage Analytics — Design (2026-08-20)

## What this document is

The design for Pulse's product-usage analytics, agreed with Joel on 2026-08-20.
Pulse is live on TestFlight; this adds a way to see how people use the app —
which features they touch — so we know what to cut and what to improve. It builds
on the existing privacy stance (raw health data never leaves the device) and does
not weaken it.

## Goal

Capture every meaningful user interaction as an anonymous event, send it to a
backend we can view in dashboards, and make instrumentation a durable part of the
build process so future features are recorded automatically — without ever
transmitting health data.

## Confirmed decisions

| Decision | Choice |
|---|---|
| Destination | **Backend analytics** — PostHog, via plain `URLSession` HTTP POST (no third-party SDK). Self-hostable later; full dashboards from day one. |
| Consent posture | **On by default, with a clear opt-out toggle in Settings.** Disclosed in a privacy policy + App Store labels. First-party, so no ATT prompt. |
| Privacy scope | The ironclad promise stays scoped to **health data**. Usage analytics is a separate, less-sensitive category. Analytics **never** includes any health metric, the biometric **state classification**, verse text/reference, or identity. |
| Emotion values | `feeling_picked` / `feedback_correction` **may include the user-selected emotion** (it is self-reported mood, not a measured health value). Automatic biometric state is never sent. |
| Sustainability | Central typed event catalog + chokepoint instrumentation + a `.trackScreen()` modifier + a **written build rule in the project instructions** + a debug event inspector. |
| Watch | Watch events route **through the phone** (phone owns the network + opt-out gate). |
| Process | TDD for the queue/serialization logic; no third-party deps (URLSession only); no force-unwraps. |

## Event taxonomy

Named events, each carrying only neutral properties (anonymous install ID, app
version, platform, timestamp) plus the few listed below.

- **Lifecycle:** `app_opened`, `session_start`, `session_end` (+ `duration_s`)
- **Onboarding funnel:** `onboarding_step_viewed` (`step`: welcome/permissions/translation), `permission_result` (`kind`: health/notifications; `granted`: bool), `onboarding_completed`
- **Verse delivery:** `verse_delivered` (`method`: auto/manual/votd), `verse_detail_opened`
- **Verse actions:** `verse_loved`, `verse_saved`, `verse_shared`, `verse_read_more`
- **Feeling picker:** `feeling_picker_opened`, `feeling_picked` (`emotion`: the chosen Emotion)
- **Feedback:** `feedback_fit` (`answer`: yes/not_quite), `feedback_helpful` (`answer`: yes/no), `feedback_correction` (`emotion`: corrected-to Emotion)
- **Prayer:** `prayer_started`, `prayer_completed` (+ `duration_s`), `prayer_amen_early`
- **VOTD / streak:** `votd_opened`, `streak_viewed`
- **Settings:** `setting_changed` (`setting`: key; and a specific `analytics_opt_out` when the toggle flips off — sent before collection stops)
- **Notifications:** `notification_opened`, `notification_action` (`action`: love/save)
- **Watch:** `watch_opened`, `watch_tab_viewed` (`tab`: verse/vitals/history/prayer), `watch_prayer_started`, `watch_feeling_requested`
- **Reliability:** `api_fallback_used` (an offline/fallback verse was served)
- **Screens (uniform):** `screen_viewed` (`screen`: name; + `duration_s` on leave) via the `.trackScreen()` modifier

**Never sent (hard guardrail):** any health metric (HR/HRV/sleep/SpO2/steps/etc.),
the automatic **biometric state**, verse text or reference, user name, or any
identifier beyond the random install ID.

## Sustainability strategy (how every new feature stays recorded)

Four reinforcing mechanisms — no fragile runtime swizzling:

1. **One typed event catalog.** `AnalyticsEvent` enum lists every event and its
   allowed properties in one file. Adding a feature = adding a case there.
2. **Chokepoint instrumentation.** Shared paths that most interactions already
   flow through — `HomeViewModel.react()` / `HistoryViewModel.react()`,
   `ScriptureEngine` delivery, `NotificationService` actions, `WatchSessionManager`
   — emit events once, so future features reusing them are covered for free.
3. **`.trackScreen("Name")` view modifier** on each screen root → uniform
   screen-view + dwell tracking. New screen = one line.
4. **Written build rule** in `CLAUDE.md` and project memory:
   *"Every new user-facing action adds an `AnalyticsEvent` case + a `track()`
   call; every new screen adds `.trackScreen()`."* Enforced as part of how
   features are built.

Plus a **debug-only event inspector** (a hidden screen / console stream printing
events as they fire) so missing instrumentation is caught during development.

## Client architecture

- **`Analytics` service** (`@MainActor`, no SDK): `track(_ event: AnalyticsEvent)`
  and `flush()`. The **closed `AnalyticsEvent` enum is the structural guardrail** —
  `track()` accepts only that enum, so there is no code path that can transmit a
  health value.
- **Anonymous install ID:** a random `UUID` created once, stored in `UserDefaults`,
  used as PostHog's `distinct_id`. No PII, no account.
- **Queue + batching + offline:** events append to a disk-persisted queue (survives
  app kill), flushed to PostHog's batch capture endpoint via `URLSession` — on a
  size threshold (~20), on app-background, and on a periodic timer. Offline → stay
  queued, retry with backoff. A cap (~500) drops oldest to bound storage. Failures
  never crash or block UI.
- **Opt-out:** `UserPreferences.analyticsEnabled` (default `true`). Off → `track()`
  is a no-op and the pending queue is cleared; zero network. The opt-out event is
  emitted just before collection stops.
- **Config:** PostHog project **write-only capture key** (safe to ship in-app) +
  host URL, provided via the existing `Config` xcconfig → Info.plist pattern (not
  hardcoded).

## Watch analytics

- A new WatchConnectivity `analytics_event` message. The watch queues events
  locally and forwards them to the phone; the phone merges them into its own queue
  and posts. Phone unreachable → the watch persists and forwards on reconnect. The
  watch never posts directly.
- The phone is the **opt-out gatekeeper**: with analytics off, forwarded watch
  events are discarded.

## Privacy, consent, disclosure

- **Settings toggle:** "Share anonymous usage" (default ON), one-line description
  ("Helps improve Pulse. Never includes your health data or verses."), link to the
  privacy policy. Immediate off + queue clear.
- **First-run disclosure:** a brief, non-blocking line in onboarding — "Pulse
  collects anonymous usage to improve. Your health data never leaves your device —
  manage anytime in Settings."

### App Store nutrition labels (exact selections)
- **Usage Data → Product Interaction:** *Collected.* Linked to user: **No.** Used
  for tracking: **No.** Purpose: **App Functionality / Analytics.**
- **Identifiers:** the random install ID is app-scoped and not linked to identity;
  declare only if required by the chosen category — as *not linked, not tracking.*
- **Health & Fitness:** **Not Collected** (never transmitted off-device).

### Compliance rationale (reference)
First-party analytics not linked to third-party data → **no ATT prompt** required.
HealthKit data is never transmitted or used for analytics → satisfies Apple's
HealthKit rules. Disclosure via privacy policy + labels satisfies the guideline.

### Privacy-policy "Analytics" section (draft, ready to paste)
> **Usage analytics.** To understand which features are used and improve Pulse, we
> collect anonymous usage events (for example, opening a screen or saving a verse),
> along with your app version and a random, app-generated identifier that is not
> tied to your name or account. This data is processed by PostHog on our behalf.
> **We do not collect or transmit your health data, the emotional/physical states
> Pulse infers, the verses you receive, or any personal identity through
> analytics** — your health data stays on your device. You can turn analytics off
> at any time in Settings → Privacy, which stops all collection immediately.

(If no full privacy policy exists yet, one is drafted as a release task — required
for the App Store regardless.)

## Architecture / new units

- **PulseShared:** `AnalyticsEvent` (enum + allowed properties), `AnalyticsQueue`
  (pure queue/batching/persistence/eviction logic, unit-tested with a stubbed
  transport), event-payload serialization.
- **iOS:** `Analytics` service (id, flush timing, URLSession transport, opt-out),
  `.trackScreen()` view modifier, chokepoint calls, `UserPreferences.analyticsEnabled`
  + Settings toggle, onboarding disclosure line, debug event inspector.
- **watch:** analytics forwarding via `WatchSessionManager` + a WatchMessage
  `analytics_event` type.
- **docs:** privacy-policy section, nutrition-label selections; the build rule
  added to `CLAUDE.md`.

## Error handling / edge cases

- Network failure → events remain queued, retried with backoff; never surfaced to
  the user.
- Queue over cap → oldest events dropped (bounded storage).
- Opt-out mid-session → immediate no-op + queue cleared; no further network.
- Missing/failed disk persistence → fall back to in-memory queue for the session;
  never crash.
- Analytics is entirely best-effort: no analytics failure may ever affect app
  behavior, UI, or the verse pipeline.

## Testing

Unit tests with a stubbed transport (YouVersion-test pattern): batch-threshold
flush; disk persistence across a simulated restart; offline retry; **opt-out makes
`track()` a no-op and clears the queue**; cap-eviction drops oldest; anonymous-ID
stability across launches; and a **serialization test asserting no disallowed keys
(health/state) appear in any payload** — belt-and-suspenders on top of the
compile-time guarantee. Manual verification via the debug event inspector.

## Out of scope (deferred)

Self-hosting PostHog (cloud first; migratable later), server-side event
enrichment, A/B experimentation, per-user cohorts beyond the anonymous ID, and any
identified (logged-in) analytics.

## Acceptance

Done when: interactions across every feature emit anonymous events to PostHog,
viewable in dashboards; the closed `AnalyticsEvent` enum makes it impossible to
send health data; a Settings opt-out (default on) immediately stops and clears
collection; the watch forwards events through the phone; the build rule is in
`CLAUDE.md`; the privacy-policy section + nutrition-label selections are documented;
and the queue/serialization logic is unit-tested (including the no-health-keys
assertion).
