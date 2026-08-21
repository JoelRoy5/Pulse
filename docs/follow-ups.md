# Follow-ups

Tracked non-blocking items deferred from completed work.

## Emotion model (2026-08-18 branch `build/emotion-model`)

- **[Design] Make the emotion the single source of truth for automatic deliveries.**
  Today the *shown* emotion is derived from energy×mood biometrics, while the
  verse theme and the "your body is…" body-interpretation text still come from
  the original 12-state classifier. On real biometrics these usually agree, but
  they can diverge on automatic deliveries (e.g. classifier picks "stressed" for
  the verse while good HRV nudges the shown emotion to "Driven"). Manual/picker
  deliveries are already consistent (fixed in the final review). Options:
  derive the verse theme + body text from `emotion.biometricState`, or reconcile
  so the banner emotion and body text come from one classification. Weigh against
  losing the 12-state classifier's richer verse themes (healing, watchman, etc.).

- **[Minor] Personalization** — none outstanding (doc fixed).
- **[Minor] Unused `import Foundation`** in `Emotion.swift` and `EmotionDeriver.swift`.
- **[Minor] TodayPlaceholderView** emotion expression style nit.
- **[Minor] Settings "Your reflections"** shows "0 of 0" for a question type the
  user hasn't answered; and swallows a fetch error silently.

## Analytics (2026-08-20 branch `build/analytics`)

- **[Minor] `AnalyticsQueue.removeBatch`** assumes the queue head is unchanged
  since `makeBatch` — largely closed by the `isFlushing` guard, but keying
  removal by event identity would be fully robust.
- **[Minor] `Analytics.flushTimer`** never invalidated (harmless on a singleton);
  `AnalyticsQueue.requeueFront` (no-op) has no test.
- **[Minor] Debug inspector** relative-time labels can go stale while open with
  no new events (debug-only view).
- **[Manual] Live PostHog verification** — with the key configured (gitignored
  xcconfig), do a device pass: confirm events land in the PostHog dashboard, then
  toggle analytics off in Settings and confirm collection stops.
- **[Release] App Store**: set the privacy nutrition labels + publish the privacy
  policy analytics section (both drafted in `docs/privacy-analytics.md`).
