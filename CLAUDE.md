# Pulse — Project Instructions for Claude

## Analytics instrumentation

Every new user-facing action MUST add an `AnalyticsEvent` case + a `track()` call
(or `WatchAnalytics.shared.track` on the watch); every new screen MUST add
`.trackScreen("Name")`. Analytics must NEVER carry health metrics, the biometric
state classification, or verse content — only neutral properties (and the
user-SELECTED emotion is allowed). Watch events forward through the phone; the phone
is the opt-out gatekeeper.
