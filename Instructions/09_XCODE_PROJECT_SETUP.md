# 09 — Xcode Project Setup

## Complete Step-by-Step Project Creation

This document provides every step needed to create the Pulse Xcode project from scratch, including all targets, entitlements, capabilities, build settings, and dependencies.

---

## Prerequisites

- Xcode 15.2+
- macOS Sonoma 14.0+
- Apple Developer account (paid — required for HealthKit + watchOS)
- Active Apple Watch for testing
- iPhone running iOS 17+

---

## Step 1: Create the Xcode Project

```
File → New → Project
Template: iOS → App
Product Name: Pulse
Team: [Your Team]
Organization Identifier: com.yourteam
Bundle Identifier: com.yourteam.pulse
Interface: SwiftUI
Language: Swift
Storage: SwiftData ← IMPORTANT
Include Tests: Yes
```

Click **Next**, choose location, click **Create**.

---

## Step 2: Add watchOS Target

```
File → New → Target
Platform: watchOS
Template: Watch App
Product Name: PulseWatch
Team: [Same Team]
Bundle Identifier: com.yourteam.pulse.watchkitapp
Watch App for: Pulse (iOS app)
Language: Swift
Interface: SwiftUI
```

In the scheme dropdown, you'll now see both `Pulse` and `PulseWatch`.

---

## Step 3: Add Shared Framework Target

```
File → New → Target
Platform: iOS (multiplatform)
Template: Framework
Product Name: PulseShared
Bundle Identifier: com.yourteam.pulseshared
```

After creation:
1. Select `PulseShared` target → General → Supported Destinations
2. Add: iOS, watchOS, macOS Catalyst (optional)
3. In both `Pulse` and `PulseWatch` targets → General → Frameworks, Libraries, and Embedded Content → Add `PulseShared.framework`

---

## Step 4: Create App Group

App Groups enable data sharing between iOS app, Watch app, and Widget extension.

```
Apple Developer Portal → Certificates, IDs & Profiles → Identifiers
Create App Group: group.com.yourteam.pulse
```

In Xcode, for **each target** (Pulse, PulseWatch):
```
Target → Signing & Capabilities → + Capability → App Groups
Add: group.com.yourteam.pulse
```

---

## Step 5: Add Required Capabilities

### Pulse (iOS) Target — Signing & Capabilities

Add these capabilities:
1. **HealthKit** — check "Background Delivery"
2. **Push Notifications**
3. **Background Modes** — check:
   - Background fetch
   - Remote notifications
   - Background processing
4. **App Groups** — `group.com.yourteam.pulse`
5. **WatchKit App Companion** (auto-added when Watch target was created)

### PulseWatch (watchOS) Target — Signing & Capabilities

Add these capabilities:
1. **HealthKit**
2. **Background Modes** — check:
   - Background App Refresh
   - Workout Processing (for extended runtime during workouts)
3. **App Groups** — `group.com.yourteam.pulse`

---

## Step 6: Configure Info.plist Files

### Pulse/Info.plist
Add these keys (right-click Info.plist → Open As → Source Code):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- HealthKit Permissions -->
    <key>NSHealthShareUsageDescription</key>
    <string>Pulse reads your health data to find scripture that meets your current physical and emotional state. This data stays on your device.</string>
    
    <key>NSHealthUpdateUsageDescription</key>
    <string>Pulse can save mindfulness sessions to your Health app after Scripture-inspired breathing exercises.</string>
    
    <!-- Background Tasks -->
    <key>BGTaskSchedulerPermittedIdentifiers</key>
    <array>
        <string>com.yourteam.pulse.health-check</string>
        <string>com.yourteam.pulse.verse-refresh</string>
    </array>
    
    <!-- API Keys (populated from xcconfig) -->
    <key>GlooAPIKey</key>
    <string>$(GLOO_API_KEY)</string>
    
    <key>YouVersionAPIKey</key>
    <string>$(YOUVERSION_API_KEY)</string>
    
    <key>YouVersionBaseURL</key>
    <string>$(YOUVERSION_BASE_URL)</string>
    
    <!-- App Transport Security (allow HTTPS only) -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
    </dict>
    
    <!-- Watch URL Scheme for deep linking from complications -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.yourteam.pulse</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>pulse</string>
            </array>
        </dict>
    </array>
    
    <!-- Privacy - Location NOT needed -->
    
    <!-- UIBackgroundModes already handled by Capabilities -->
</dict>
</plist>
```

### PulseWatch/Info.plist
Add:
```xml
<key>NSHealthShareUsageDescription</key>
<string>Pulse reads your health data on Apple Watch to deliver contextual scripture to your wrist.</string>
```

---

## Step 7: Create Build Configuration Files

Create two `.xcconfig` files in the project root:

### `Config/Debug.xcconfig`
```
// Debug Build Configuration
// NEVER commit real API keys — use environment variables in CI

GLOO_API_KEY = your_gloo_dev_api_key_here
YOUVERSION_API_KEY = your_youversion_dev_api_key_here  
YOUVERSION_BASE_URL = https://api.youversion.com/v1

// Build settings
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG
DEBUG_INFORMATION_FORMAT = dwarf
```

### `Config/Release.xcconfig`
```
// Release Build Configuration
// Keys injected by CI/CD environment

GLOO_API_KEY = $(GLOO_API_KEY_ENV)
YOUVERSION_API_KEY = $(YOUVERSION_API_KEY_ENV)
YOUVERSION_BASE_URL = https://api.youversion.com/v1

SWIFT_ACTIVE_COMPILATION_CONDITIONS = RELEASE
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
```

### Apply Configs to Build Configurations
```
Project → Pulse (project, not target) → Info → Configurations
Debug: Based on Config File → Config/Debug.xcconfig
Release: Based on Config File → Config/Release.xcconfig
```

Apply for **all three targets**.

### Add .xcconfig to .gitignore
```gitignore
# API Keys
Config/Debug.xcconfig
Config/Release.xcconfig
# Use .xcconfig.template files instead (with placeholder values)
```

---

## Step 8: Create Folder Structure

In Xcode's project navigator, create the following groups/folders:
(Right-click → New Group)

```
Pulse/
├── App/
├── Core/
│   ├── Health/
│   ├── Scripture/
│   ├── Persistence/
│   └── Connectivity/
├── Features/
│   ├── Onboarding/
│   ├── Home/
│   ├── History/
│   ├── Share/
│   └── Settings/
├── DesignSystem/
│   └── Components/
├── Notifications/
└── Resources/
    └── Assets.xcassets

PulseWatch/
├── App/
├── Core/
├── Features/
├── Complications/
└── Resources/

PulseShared/
├── Models/
└── Extensions/
```

---

## Step 9: Entitlements Files

### Pulse.entitlements
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.background-delivery</key>
    <true/>
    <key>aps-environment</key>
    <string>development</string>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yourteam.pulse</string>
    </array>
</dict>
</plist>
```

### PulseWatch.entitlements
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yourteam.pulse</string>
    </array>
</dict>
</plist>
```

---

## Step 10: Swift Package Dependencies

In Xcode: **File → Add Package Dependencies**

Add these packages:

### 1. No external dependencies needed!

Pulse is intentionally built using only:
- **HealthKit** (Apple framework — built-in)
- **SwiftData** (Apple framework — built-in)
- **WatchKit / WatchConnectivity** (Apple framework — built-in)
- **UserNotifications** (Apple framework — built-in)
- **WidgetKit** (Apple framework — built-in)
- **ClockKit** (Apple framework — built-in)
- **BackgroundTasks** (Apple framework — built-in)
- **Network** (Apple framework — for connectivity monitoring)

This ensures:
- No supply chain risks
- Minimal app size
- No licensing complications for competition submission

---

## Step 11: Initial File Creation Order

Create files in this exact order to avoid compile errors:

### Phase 1: Shared Framework Files
```
PulseShared/
  Models/BiometricState.swift
  Models/HealthSnapshot.swift
  Models/BibleVerse.swift
  Models/WatchMessage.swift
  Extensions/Color+Pulse.swift
  Extensions/Date+Helpers.swift
```

### Phase 2: iOS Core
```
Pulse/Core/Persistence/PulseSchema.swift
Pulse/Core/Persistence/ModelContainer+Setup.swift
Pulse/Core/Health/MetricCollector.swift
Pulse/Core/Health/SleepAnalyzer.swift
Pulse/Core/Health/StateClassifier.swift
Pulse/Core/Health/HealthEngine.swift
Pulse/Core/Scripture/GlooAIClient.swift
Pulse/Core/Scripture/YouVersionClient.swift
Pulse/Core/Scripture/VerseCache.swift
Pulse/Core/Scripture/DeliveryScheduler.swift
Pulse/Core/Scripture/ScriptureEngine.swift
Pulse/Core/Connectivity/PhoneSessionManager.swift
Pulse/Notifications/NotificationService.swift
```

### Phase 3: iOS Design System
```
Pulse/DesignSystem/Colors.swift
Pulse/DesignSystem/Typography.swift
Pulse/DesignSystem/Animations.swift
Pulse/DesignSystem/Gradients.swift
Pulse/DesignSystem/Components/PSCard.swift
Pulse/DesignSystem/Components/PulseRing.swift
Pulse/DesignSystem/Components/VerseTextView.swift
Pulse/DesignSystem/Components/StateChipView.swift
Pulse/DesignSystem/Components/MetricTile.swift
```

### Phase 4: iOS Features
```
Pulse/Features/Onboarding/OnboardingFlow.swift
Pulse/Features/Onboarding/WelcomeView.swift
Pulse/Features/Onboarding/PermissionsView.swift
Pulse/Features/Onboarding/TranslationPickerView.swift
Pulse/Features/Onboarding/OnboardingViewModel.swift
Pulse/Features/Home/HomeViewModel.swift
Pulse/Features/Home/HomeView.swift
Pulse/Features/Home/CurrentVerseCard.swift
Pulse/Features/Home/StateRingView.swift
Pulse/Features/Home/MetricsGridView.swift
Pulse/Features/History/HistoryViewModel.swift
Pulse/Features/History/HistoryView.swift
Pulse/Features/History/HistoryRowView.swift
Pulse/Features/History/VerseDetailView.swift
Pulse/Features/Share/ShareCardView.swift
Pulse/Features/Share/ShareCardRenderer.swift
Pulse/Features/Settings/SettingsViewModel.swift
Pulse/Features/Settings/SettingsView.swift
```

### Phase 5: iOS App Entry
```
Pulse/App/AppDelegate.swift
Pulse/App/PulseApp.swift
```

### Phase 6: Watch App
```
PulseWatch/Core/WatchHealthEngine.swift
PulseWatch/Core/WatchSessionManager.swift
PulseWatch/Features/VerseView.swift
PulseWatch/Features/VitalsView.swift
PulseWatch/Features/HistoryView.swift
PulseWatch/Features/PrayerView.swift
PulseWatch/Features/MainView.swift
PulseWatch/Complications/ComplicationViews.swift
PulseWatch/Complications/ComplicationController.swift
PulseWatch/App/PulseWatchApp.swift
```

---

## Step 12: Assets Configuration

### App Icon
In `Assets.xcassets`:
- Create `AppIcon` image set
- Required sizes: 1024×1024 (App Store), 180×180, 167×167, 152×152, 120×120, 87×87, 80×80, 76×76, 60×60, 58×58, 40×40, 29×29, 20×20
- Watch icon: 1024×1024 (watches auto-scale)

**Icon Design Brief:**
- Deep navy background (#0A0E1A)
- White/gold ECG heartbeat line arcing left-to-right
- The peak of the ECG beat is an open Bible or subtle cross
- Gold accent (#C9A96E) on the cross/Bible
- Rounded square corners (system-applied)

### Color Sets
Create named color sets in `Assets.xcassets/Colors/`:
- `VVDeepNavy`
- `VVNavy`
- `VVAccent`
- `VVAccentLight`
- `VVCream`
- `VVGrayMuted`
- `VVSuccess`
- `VVWarning`
- `VVAlert`

Set Light Appearance = same value, Dark Appearance = same value (app is always dark).

### Image Assets
- `particles_heart.png` — small heart icon for particle effects
- `particles_cross.png` — small cross icon for particle effects
- `verse_card_texture.png` — subtle paper texture for verse cards
- `logo_full.png` — full Pulse logo with text
- `logo_icon.png` — icon only (for share cards)

---

## Step 13: Bundle the Emergency Verses

Add `emergency_verses.json` to **both** the iOS and watchOS targets:

1. Create `Pulse/Resources/emergency_verses.json` (content from `04_AI_SCRIPTURE_ENGINE.md`)
2. In File Inspector: make sure both `Pulse` and `PulseWatch` targets are checked under "Target Membership"

---

## Step 14: Scheme Configuration

### Debug Scheme (for Simulator)
- Run: Pulse (iOS)
- Run destination: iPhone 15 Pro (or any iOS 17+ device)
- Diagnostics → Enable Main Thread Checker

### Watch Scheme
- Run: PulseWatch
- Requires paired physical watch for HealthKit (simulator has limited HK)

### Test Configuration
For HealthKit testing on simulator, use `HKHealthStore.isHealthDataAvailable()` guard and mock data provider pattern.

---

## Step 15: Signing

```
Each Target → Signing & Capabilities
Team: [Your developer account team]
Bundle Identifier: as defined above
Signing Certificate: Apple Development (Debug), Apple Distribution (Release)
Provisioning Profile: Automatic (Xcode Managed)
```

For WatchKit, Xcode manages the WatchKit Extension profile automatically.

---

## Step 16: Build & Run

```
1. Connect iPhone to Mac via cable
2. Trust the computer on iPhone
3. Select "Pulse" scheme
4. Select your connected iPhone as destination
5. Product → Build (⌘B) — fix any compile errors
6. Product → Run (⌘R) — app installs on device

For Watch:
1. Pair Apple Watch with iPhone
2. Select "PulseWatch" scheme
3. Select "Pulse on iPhone (Watch)" destination
4. Product → Run
```

---

## Troubleshooting Common Issues

### "HealthKit is not available on this device"
- Must run on physical device, not simulator
- Some HK types available in simulator — use `HKHealthStore.isHealthDataAvailable()` check

### "WCSession not reachable"
- Both iOS app and Watch app must be running simultaneously
- Use `session.transferUserInfo()` for non-real-time delivery

### "Background delivery not firing"
- Requires physical device
- HealthKit background delivery is rate-limited by iOS
- Hourly frequency is the most reliable
- Test by generating HealthKit data from a workout or by writing test HK samples

### Build error: "Cannot find type in scope"
- Ensure `PulseShared` is added to target's framework dependencies
- Check `import PulseShared` at top of files using shared types
