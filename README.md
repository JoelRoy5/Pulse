# Pulse

**Scripture that meets you where you are.**

Pulse is a native iOS + watchOS app that reads your Apple Watch biometrics, classifies your current physical and emotional state into one of 12 named states, and delivers the most contextually relevant Bible verse directly to your wrist. Gloo AI Studio selects the verse; YouVersion Platform API fetches the text in your preferred translation.

Built for the Kaggle "Scripture in New Frontiers" competition — Wearables track.

---

## Prerequisites

| Requirement | Version |
|---|---|
| macOS | 14.0 (Sonoma) or later |
| Xcode | 15.2 or later (project built and tested with Xcode 26.2) |
| Homebrew | Any recent version |
| XcodeGen | `brew install xcodegen` |
| Apple Developer account | Free account sufficient for simulator; paid account required for device install |

---

## API Keys

Pulse uses two external APIs. You need credentials for both before the app can call live endpoints. Without keys, the app starts in offline-fallback mode and serves bundled emergency verses — all UI still works, but no live AI selection or YouVersion text fetch occurs.

### Gloo AI Studio

1. Go to [studio.ai.gloo.com](https://studio.ai.gloo.com)
2. Sign in and navigate to **Manage API Credentials**
3. Create a new credential set; copy the **Client ID** and **Client Secret**

### YouVersion Platform API

1. Go to [developers.youversion.com](https://developers.youversion.com)
2. Register your application; copy the **App Key**

---

## Setup

```bash
# 1. Clone the repository
git clone <repo-url>
cd Pulse

# 2. Copy the configuration template
cp Config/Debug.xcconfig.template Config/Debug.xcconfig

# 3. Fill in your API keys
#    Open Config/Debug.xcconfig and replace the placeholder values:
#      GLOO_CLIENT_ID = your_gloo_client_id_here
#      GLOO_CLIENT_SECRET = your_gloo_client_secret_here
#      YOUVERSION_APP_KEY = your_youversion_app_key_here

# 4. Generate the Xcode project and build
./Scripts/bootstrap.sh
```

The bootstrap script copies any missing xcconfig templates and runs `xcodegen generate`. The generated `Pulse.xcodeproj` is not committed; it is always regenerated from `project.yml`.

---

## Build and Run

### Simulator (no signing required)

Open the project in Xcode:
```bash
open Pulse.xcodeproj
```

Select the **Pulse** scheme and an iPhone simulator, then press **Run** (⌘R).

To also run the watch app, select **PulseWatch** scheme with a paired Apple Watch simulator.

Via command line (iPhone 16 Pro Max simulator as example):

```bash
# Build the iOS app
xcodebuild \
  -project Pulse.xcodeproj \
  -scheme Pulse \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  -configuration Debug \
  build

# Run the swift package tests
swift test --package-path PulseShared
```

### Physical Device

1. Open `Pulse.xcodeproj` in Xcode
2. Select the **Pulse** target → **Signing & Capabilities**
3. Change **Team** to your Apple Developer team (or let Xcode manage it with your personal team)
4. Connect your iPhone, select it as the run destination, press **Run**

For command-line device installs (replace `YOUR_TEAM_ID`):
```bash
xcodebuild \
  -project Pulse.xcodeproj \
  -scheme Pulse \
  -destination 'generic/platform=iOS' \
  -configuration Debug \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  -allowProvisioningUpdates \
  build install
```

The watch app (`PulseWatch`) is embedded in the iPhone app bundle and installs automatically to the paired Apple Watch via the Watch app on iPhone.

---

## Running Tests

```bash
swift test --package-path PulseShared
```

The `PulseShared` package contains all logic-layer unit tests. As of Phase 1: **53 tests pass, 1 skipped, 0 failures**.

Core logic suites include:
- `StateClassifierTests` — all 12 biometric states + graceful fallback
- `DeliveryRulesEngineTests` — cooldown logic, quiet hours, urgency override
- `HealthSnapshotTests` — metric parsing and completeness threshold
- `GlooAIClientTests` — mocked Gloo transport (token exchange + completion parsing)
- `YouVersionClientTests` — mocked YouVersion transport (passage fetch + error handling)

---

## Demo Mode — Mock Launch Arguments

Pulse supports a full set of launch arguments so judges can demo every state and edge case without wearing an Apple Watch for a week. Set these in Xcode under **Product → Scheme → Edit Scheme → Run → Arguments Passed On Launch**, or pass them to `xcodebuild -testArguments`.

### `-PulseMockState <raw_value>`

Forces the health engine to report a specific biometric state. Use with `-PulseAutoDeliver YES` to trigger immediate verse delivery in that state.

| Raw value | Display name | Scenario |
|---|---|---|
| `energized_post_workout` | Victory Lap | Post-workout recovery |
| `stressed_anxious` | Still Waters | Low HRV, elevated resting HR |
| `exhausted_depleted` | Weary Soul | Poor sleep + low HRV |
| `deep_rest_recovered` | Sabbath Morning | High sleep efficiency |
| `peaceful_steady` | Still Small Voice | Calm vitals, low resting HR |
| `morning_awakening` | New Mercies | First reading after sleep |
| `evening_winding_down` | Evening Psalm | Low activity + late hour |
| `active_engaged` | Purpose Walk | Elevated step count |
| `sad_withdrawn` | Broken Vessel | Very low activity, multi-day |
| `sick_unwell` | Healing Hands | Elevated HR + low SpO2 |
| `peak_performance` | Mountain Top | Elite HRV + great sleep + high activity |
| `spiritual_alert` | Watchman Hour | Late-night wakefulness |

### Additional launch arguments

| Argument | Value | Effect |
|---|---|---|
| `-PulseAutoDeliver` | `YES` | Triggers a live verse delivery immediately at launch (calls Gloo + YouVersion) |
| `-PulseForceOffline` | `YES` | Bypasses all network calls; serves cached or bundled emergency verse |
| `-PulseSkipOnboarding` | `YES` | Jumps directly to the main tab view (skips welcome/permissions/translation steps) |
| `-PulseResetOnboarding` | `YES` | Clears the onboarding-complete flag so onboarding runs again on next launch |
| `-PulseInitialTab` | `home` / `journey` / `settings` | Opens a specific tab on launch |
| `-PulseShowShare` | `YES` | Auto-presents the share card for the most recent delivery on launch |
| `-PulseOnboardingStep` | `welcome` / `permissions` / `translation` / `complete` | Jumps to a specific onboarding step |

**Example — demo "Weary Soul" state with live API call:**
```
-PulseMockState exhausted_depleted -PulseAutoDeliver YES -PulseSkipOnboarding YES
```

**Example — demo offline fallback:**
```
-PulseMockState exhausted_depleted -PulseAutoDeliver YES -PulseForceOffline YES -PulseSkipOnboarding YES
```

---

## Project Structure

```
Pulse/
├── project.yml                     # XcodeGen project definition (source of truth)
├── Scripts/
│   └── bootstrap.sh                # Copy xcconfig templates + xcodegen generate
├── Config/
│   ├── Debug.xcconfig.template     # API key placeholders (committed)
│   └── Release.xcconfig.template
│
├── Pulse/                          # iOS application target
│   ├── App/
│   │   ├── PulseApp.swift          # App entry point, launch argument parsing
│   │   ├── AppDelegate.swift       # BGTaskScheduler registration
│   │   └── AppConfig.swift         # Credential + launch-arg helpers
│   ├── Core/
│   │   ├── Health/                 # HealthEngine, MetricCollector, MockHealthProvider
│   │   └── Scripture/              # ScriptureEngine, VerseCache, DeliveryScheduler
│   └── Features/
│       ├── Home/                   # HomeView — state banner + verse card + metrics grid
│       ├── Onboarding/             # 4-step onboarding flow
│       ├── History/                # HistoryView — date-sectioned verse list
│       ├── Share/                  # ShareCardView + ShareCardRenderer
│       └── Settings/               # SettingsView — translation, notifications, health
│
├── PulseWatch/                     # watchOS application target
│   ├── App/                        # WatchApp entry, WatchSessionManager
│   └── Features/                   # VerseView, VitalsView, HistoryView, PrayerView
│
├── PulseWatchWidgets/              # WidgetKit complication extension
│   ├── PulseComplications.swift    # Widget declaration (4 accessory families)
│   └── ComplicationViews.swift     # accessoryCircular, accessoryRectangular, accessoryInline, accessoryCorner
│
├── PulseShared/                    # Local Swift Package (shared across iOS + watchOS)
│   └── Sources/PulseShared/
│       ├── Models/                 # BiometricState (12 states), HealthSnapshot, BibleVerse, WatchMessage
│       ├── Logic/                  # StateClassifier, SleepAnalyzer, DeliveryRulesEngine, FallbackVerseProvider
│       ├── Scripture/              # GlooAIClient, YouVersionClient, ScriptureProtocols
│       └── Design/                 # Color tokens, typography, spacing, animation constants
│
└── docs/
    ├── acceptance-phase1.md        # Phase 1 acceptance checklist + verification log
    └── screenshots/                # 18+ PNG screenshots (simulator + device)
```

---

## Known Limitations

These are Phase 1 scope decisions, not bugs:

- **Translation selection is limited to translations granted by your App Key.** The YouVersion API returns only the translations your registered application is authorized to access (typically the open-license set: BSB, ASV, WEB, LSV, Geneva, and a few others). Commercial translations (NIV, ESV, KJV) return `Access denied` for unauthorized keys. The Settings translation picker is populated dynamically from `GET /v1/bibles` and shows only what your key grants. Default is BSB (Berean Standard Bible, ID 3034).

- **Watch complications require a physical device for on-face verification.** Xcode simulators do not support adding complications to a watch face programmatically via `simctl`. The complication code (4 WidgetKit accessory families) is implemented and renders correctly in Xcode Previews; physical device verification shows the complication installs via the Watch app.

- **Background verse delivery requires a physical iPhone.** iOS simulators do not fire `BGProcessingTask` or HealthKit background delivery callbacks; these paths are verified on-device.

- **Live Activities, breath prayer, streak tracking, sparklines, and the remaining share card variants are Phase 2.** They are noted as deferred in the design document and are not part of the Phase 1 acceptance criteria.

- **No App Store submission polish.** No Privacy Policy URL, Terms of Service, or App Store listing assets have been created. This is a competition prototype.
