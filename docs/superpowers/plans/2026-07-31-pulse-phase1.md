# Pulse Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete Phase-1 Pulse app — iOS + watchOS + watch complications — satisfying every item in the technical acceptance checklist in `Instructions/10_DELIVERABLES.md`.

**Architecture:** XcodeGen-generated Xcode project with three products: `Pulse` (iOS 17 app), `PulseWatch` (watchOS 10 app) with `PulseWatchWidgets` (WidgetKit complications extension), and `PulseShared` (local Swift Package holding all models, scoring logic, API clients, and design tokens so they are testable with plain `swift test`). Health data flows: HealthKit → `HealthSnapshot` → `StateClassifier` → `DeliveryRulesEngine` → Gloo AI (verse selection) → YouVersion (verse text) → SwiftData persistence + notification + WatchConnectivity push → Watch UI/complication.

**Tech Stack:** Swift (language mode 5), SwiftUI, SwiftData, HealthKit, WatchConnectivity, WidgetKit, UserNotifications, BackgroundTasks, XcodeGen, XCTest.

## Global Constraints

Copied from the Instructions docs and the approved design doc (`docs/superpowers/specs/2026-07-31-pulse-build-design.md`). Every task implicitly includes these:

- Deployment targets: **iOS 17.0**, **watchOS 10.0**. Xcode 26.2 on this Mac.
- Bundle IDs: iOS `com.joelroy.pulse`, watch `com.joelroy.pulse.watchkitapp`, widgets `com.joelroy.pulse.watchkitapp.widgets`. App Group `group.com.joelroy.pulse`. Team `APQT8U28NL`, automatic signing.
- **No third-party dependencies.** Apple frameworks + XcodeGen (build tool) only.
- **No force-unwraps in production paths.** All async via Swift Concurrency (no Combine). View models use `@Observable`.
- **Zero raw health numbers sent to any external API** — only enum state strings, time-of-day, confidence, and preferences.
- Missing health metrics render as `—`, never as errors. Classification tolerates nil fields.
- Fallback chain (never show an empty screen): Gloo → local reference map → SwiftData cache → bundled `emergency_verses.json`.
- The app is **always dark** (no light mode). Colors/typography/spacing exactly per `Instructions/07_UI_DESIGN_SYSTEM.md`.
- The 12 states, their raw values, display names, copy, emojis, gradients, and fallback references are **verbatim** from `Instructions/07` and `Instructions/08`. Do not paraphrase user-facing copy.
- API keys live only in gitignored `Config/Debug.xcconfig` / `Config/Release.xcconfig`; committed `*.xcconfig.template` files hold placeholders.
- Complications use **WidgetKit accessory families** (not ClockKit). Watch lifecycle uses `WKApplicationDelegate` (not WKExtension).
- Commits: small, per task, message style `feat:`/`test:`/`chore:`, each ending with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Verification commands used throughout:
  - Package tests: `swift test --package-path PulseShared`
  - Regenerate project: `xcodegen generate`
  - iOS build: `xcodebuild -project Pulse.xcodeproj -scheme Pulse -destination 'platform=iOS Simulator,name=iPhone 16' build`
  - Watch build: `xcodebuild -project Pulse.xcodeproj -scheme PulseWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build`

## File Structure (end state of Phase 1)

```
Pulse/
├── project.yml                      # XcodeGen definition (single source of truth)
├── Pulse.xcodeproj                  # generated, committed for judges
├── Config/
│   ├── Debug.xcconfig.template      # committed placeholders
│   ├── Release.xcconfig.template
│   ├── Debug.xcconfig               # gitignored, real keys
│   └── Release.xcconfig             # gitignored
├── Scripts/bootstrap.sh             # copies templates → real xcconfigs if absent, runs xcodegen
├── PulseShared/                     # local Swift Package
│   ├── Package.swift
│   ├── Sources/PulseShared/
│   │   ├── Models/  (BiometricState, HealthSnapshot, ClassificationResult,
│   │   │             BibleVerse, BibleTranslationID, VerseReaction, WatchMessage,
│   │   │             TimeOfDay, SleepBreakdown, HealthQuality)
│   │   ├── Logic/   (SleepAnalyzer, StateClassifier, DeliveryRulesEngine,
│   │   │             FallbackVerseProvider)
│   │   ├── Scripture/ (VerseSelecting, VerseFetching, GlooAIClient,
│   │   │               YouVersionClient, ScriptureAPIError)
│   │   ├── Design/  (Colors, Gradients, Typography, Spacing, Animations)
│   │   └── Resources/emergency_verses.json
│   └── Tests/PulseSharedTests/  (one test file per logic unit)
├── Pulse/                           # iOS app target sources
│   ├── App/          (PulseApp.swift, AppDelegate.swift, AppConfig.swift)
│   ├── Core/Health/  (HealthDataProviding.swift, MetricCollector.swift,
│   │                  MockHealthProvider.swift, HealthEngine.swift)
│   ├── Core/Scripture/ (ScriptureEngine.swift, VerseCache.swift, DeliveryScheduler.swift)
│   ├── Core/Persistence/ (PulseSchema.swift, ModelContainer+Setup.swift)
│   ├── Core/Connectivity/ (PhoneSessionManager.swift)
│   ├── Notifications/ (NotificationService.swift)
│   ├── Features/Onboarding|Home|History|Share|Settings/
│   ├── DesignSystem/Components/ (PSCard, PSButton, PulseRing, VerseTextView,
│   │                             StateChipView, MetricTile)
│   └── Resources/ (Assets.xcassets, Pulse.entitlements)
├── PulseWatch/                      # watchOS app target sources
│   ├── App/ (PulseWatchApp.swift, WatchAppDelegate.swift)
│   ├── Core/ (WatchSessionManager.swift, WatchDataStore.swift, WatchHealthEngine.swift)
│   ├── Features/ (MainView, VerseView, VitalsView, HistoryView, PrayerView)
│   └── Resources/ (Assets.xcassets, PulseWatch.entitlements)
├── PulseWatchWidgets/               # WidgetKit extension sources
│   ├── PulseComplications.swift     # Widget + TimelineProvider
│   ├── ComplicationViews.swift
│   └── Resources/ (PulseWatchWidgets.entitlements)
├── README.md                        # build instructions for judges
└── SUBMISSION.md                    # competition narrative skeleton
```

Design rule baked into this structure: **everything that contains logic lives in `PulseShared`** where `swift test` runs it in seconds without simulators. The app targets contain only HealthKit/SwiftData/WCSession/UI glue.

---

### Task 0: Toolchain + project scaffold

**Files:**
- Create: `project.yml`, `Scripts/bootstrap.sh`, `Config/Debug.xcconfig.template`, `Config/Release.xcconfig.template`, `.gitignore` (extend), `PulseShared/Package.swift`, `PulseShared/Sources/PulseShared/Placeholder.swift`, `PulseShared/Tests/PulseSharedTests/PlaceholderTests.swift`, `Pulse/App/PulseApp.swift`, `Pulse/Resources/Pulse.entitlements`, `PulseWatch/App/PulseWatchApp.swift`, `PulseWatch/Resources/PulseWatch.entitlements`, `PulseWatchWidgets/PulseComplications.swift`, `PulseWatchWidgets/Resources/PulseWatchWidgets.entitlements`, minimal `Assets.xcassets` for both app targets (empty catalogs with AppIcon placeholder set).

**Interfaces:**
- Consumes: nothing (first task).
- Produces: a generated `Pulse.xcodeproj` in which all three product targets build; `PulseShared` imported by all app targets; xcconfig-driven `GLOO_CLIENT_ID`, `GLOO_CLIENT_SECRET`, `YOUVERSION_APP_KEY` reachable via Info.plist keys `GlooClientID`, `GlooClientSecret`, `YouVersionAppKey`.

- [ ] **Step 1: Install XcodeGen**

```bash
brew install xcodegen && xcodegen --version
```

- [ ] **Step 2: Write the Swift package manifest**

`PulseShared/Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PulseShared",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [.library(name: "PulseShared", targets: ["PulseShared"])],
    targets: [
        .target(
            name: "PulseShared",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "PulseSharedTests", dependencies: ["PulseShared"]),
    ]
)
```

macOS is included solely so `swift test` runs natively on this Mac. Add `PulseShared/Sources/PulseShared/Placeholder.swift` containing `public enum PulseShared {}` and a trivial passing test so the package builds before real models arrive; both are deleted in Task 1. Create `PulseShared/Sources/PulseShared/Resources/.gitkeep` so the resources directory exists.

- [ ] **Step 3: Write xcconfig templates and gitignore entries**

`Config/Debug.xcconfig.template` (Release template identical except `SWIFT_ACTIVE_COMPILATION_CONDITIONS = RELEASE` and no DEBUG):

```
// Copy to Debug.xcconfig and fill in real values. NEVER commit real keys.
GLOO_CLIENT_ID = your_gloo_client_id_here
GLOO_CLIENT_SECRET = your_gloo_client_secret_here
YOUVERSION_APP_KEY = your_youversion_app_key_here
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG
```

Append to `.gitignore`:

```gitignore
Config/Debug.xcconfig
Config/Release.xcconfig
*.xcuserdata
xcuserdata/
DerivedData/
build/
```

`Scripts/bootstrap.sh` (chmod +x):

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
for cfg in Debug Release; do
  [ -f "Config/$cfg.xcconfig" ] || cp "Config/$cfg.xcconfig.template" "Config/$cfg.xcconfig"
done
xcodegen generate
```

- [ ] **Step 4: Write `project.yml`**

```yaml
name: Pulse
options:
  bundleIdPrefix: com.joelroy
  deploymentTarget:
    iOS: "17.0"
    watchOS: "10.0"
  createIntermediateGroups: true
configFiles:
  Debug: Config/Debug.xcconfig
  Release: Config/Release.xcconfig
settings:
  base:
    DEVELOPMENT_TEAM: APQT8U28NL
    CODE_SIGN_STYLE: Automatic
    SWIFT_VERSION: "5.0"
    CURRENT_PROJECT_VERSION: 1
    MARKETING_VERSION: 1.0
packages:
  PulseShared:
    path: PulseShared
targets:
  Pulse:
    type: application
    platform: iOS
    sources: [Pulse]
    dependencies:
      - package: PulseShared
      - target: PulseWatch
    entitlements:
      path: Pulse/Resources/Pulse.entitlements
      properties:
        com.apple.developer.healthkit: true
        com.apple.developer.healthkit.background-delivery: true
        com.apple.security.application-groups: [group.com.joelroy.pulse]
    info:
      path: Pulse/Resources/Info.plist
      properties:
        UILaunchScreen: {}
        NSHealthShareUsageDescription: "Pulse reads your health data to find scripture that meets your current physical and emotional state. This data stays on your device."
        NSHealthUpdateUsageDescription: "Pulse can save mindfulness sessions to your Health app after Scripture-inspired breathing exercises."
        BGTaskSchedulerPermittedIdentifiers:
          - com.joelroy.pulse.health-check
          - com.joelroy.pulse.verse-refresh
        UIBackgroundModes: [fetch, processing]
        GlooClientID: $(GLOO_CLIENT_ID)
        GlooClientSecret: $(GLOO_CLIENT_SECRET)
        YouVersionAppKey: $(YOUVERSION_APP_KEY)
        CFBundleURLTypes:
          - CFBundleURLName: com.joelroy.pulse
            CFBundleURLSchemes: [pulse]
  PulseWatch:
    type: application.watchapp2
    platform: watchOS
    sources: [PulseWatch]
    dependencies:
      - package: PulseShared
      - target: PulseWatchWidgets
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.joelroy.pulse.watchkitapp
        INFOPLIST_KEY_WKCompanionAppBundleIdentifier: com.joelroy.pulse
    entitlements:
      path: PulseWatch/Resources/PulseWatch.entitlements
      properties:
        com.apple.developer.healthkit: true
        com.apple.security.application-groups: [group.com.joelroy.pulse]
    info:
      path: PulseWatch/Resources/Info.plist
      properties:
        WKApplication: true
        NSHealthShareUsageDescription: "Pulse reads your health data on Apple Watch to deliver contextual scripture to your wrist."
  PulseWatchWidgets:
    type: app-extension
    platform: watchOS
    sources: [PulseWatchWidgets]
    dependencies:
      - package: PulseShared
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.joelroy.pulse.watchkitapp.widgets
    entitlements:
      path: PulseWatchWidgets/Resources/PulseWatchWidgets.entitlements
      properties:
        com.apple.security.application-groups: [group.com.joelroy.pulse]
    info:
      path: PulseWatchWidgets/Resources/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
```

Notes for the implementer: if `xcodegen` rejects `type: application.watchapp2` under Xcode 26 conventions, use `type: application` with `platform: watchOS` — modern single-target watch apps are plain applications; keep the `WKApplication: true` Info key and the `WKCompanionAppBundleIdentifier` setting. Verify the generated pbxproj embeds PulseWatch inside Pulse (XcodeGen does this automatically for watch targets) and embeds the widget extension inside PulseWatch.

- [ ] **Step 5: Write minimal app entry points**

`Pulse/App/PulseApp.swift`:

```swift
import SwiftUI

@main
struct PulseApp: App {
    var body: some Scene {
        WindowGroup { Text("Pulse") }
    }
}
```

`PulseWatch/App/PulseWatchApp.swift`:

```swift
import SwiftUI

@main
struct PulseWatchApp: App {
    var body: some Scene {
        WindowGroup { Text("Pulse") }
    }
}
```

`PulseWatchWidgets/PulseComplications.swift` (minimal valid widget; real one in Task 12):

```swift
import WidgetKit
import SwiftUI

struct PulseEntry: TimelineEntry { let date: Date }

struct PulseProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseEntry { PulseEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (PulseEntry) -> Void) {
        completion(PulseEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PulseEntry>) -> Void) {
        completion(Timeline(entries: [PulseEntry(date: .now)], policy: .never))
    }
}

@main
struct PulseWidgets: WidgetBundle {
    var body: some Widget { PulseComplication() }
}

struct PulseComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PulseComplication", provider: PulseProvider()) { _ in
            Image(systemName: "heart.text.square")
        }
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
```

- [ ] **Step 6: Generate and build all targets**

```bash
./Scripts/bootstrap.sh
swift test --package-path PulseShared
xcodebuild -project Pulse.xcodeproj -scheme Pulse -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -project Pulse.xcodeproj -scheme PulseWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

Expected: all succeed. Iterate on `project.yml` until they do — this step is the point of the task.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "chore: XcodeGen scaffold with iOS, watchOS, widget targets and PulseShared package"
```

---

### Task 1: Shared models — `BiometricState`, `TimeOfDay`, supporting enums

**Files:**
- Create: `PulseShared/Sources/PulseShared/Models/BiometricState.swift`, `Models/TimeOfDay.swift`, `Models/VerseReaction.swift`, `Models/BibleTranslationID.swift`, `Models/HealthQuality.swift`
- Delete: both Placeholder files from Task 0
- Test: `PulseShared/Tests/PulseSharedTests/BiometricStateTests.swift`, `TimeOfDayTests.swift`, `HealthQualityTests.swift`

**Interfaces:**
- Produces (all `public`):
  - `enum BiometricState: String, Codable, CaseIterable, Identifiable, Sendable` — 12 cases with raw values exactly as `Instructions/08_DATA_MODELS.md:17-28`; properties `displayName`, `abbreviation`, `bodyInterpretation`, `verseTheme` (all String, copy verbatim from `Instructions/08_DATA_MODELS.md:32-110`), `emoji` (from `Instructions/07_UI_DESIGN_SYSTEM.md:155-171`), `deliveryUrgency: DeliveryUrgency` (nested enum `high | timeSensitive | standard`, mapping from `Instructions/08_DATA_MODELS.md:112-127`).
  - `enum TimeOfDay: String, Codable, Sendable` — `earlyMorning, morning, afternoon, evening, night` with `public init(hour: Int)` implementing the boundaries in `Instructions/08_DATA_MODELS.md:269-275` (5–8 earlyMorning, 8–12 morning, 12–17 afternoon, 17–21 evening, else night) and `public init(date: Date, calendar: Calendar = .current)` delegating to it.
  - `enum VerseReaction: String, Codable, Sendable` with `displayName` and `icon` per `Instructions/08_DATA_MODELS.md:475-501`.
  - `enum BibleTranslationID: Int, Codable, CaseIterable, Sendable` with `abbreviation`, `fullName`, `previewVerse` per `Instructions/08_DATA_MODELS.md:504-548` (raw values: NIV 111, ESV 59, NLT 116, KJV 1, CSB 1713, NASB 2016, MSG 97, AMP 1588, NKJV 114, NCV 105).
  - `enum HealthQuality` with `label` and the four static factories per `Instructions/08_DATA_MODELS.md:634-695`, **excluding** the `color` property (colors attach in Task 4 where the design tokens live, via an extension in `Design/Colors.swift`).

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import PulseShared

final class BiometricStateTests: XCTestCase {
    func testTwelveStatesWithStableRawValues() {
        XCTAssertEqual(BiometricState.allCases.count, 12)
        XCTAssertEqual(BiometricState.energizedPostWorkout.rawValue, "energized_post_workout")
        XCTAssertEqual(BiometricState.spiritualAlert.rawValue, "spiritual_alert")
        XCTAssertEqual(BiometricState(rawValue: "exhausted_depleted"), .exhaustedDepleted)
    }
    func testDisplayMetadataPresent() {
        for state in BiometricState.allCases {
            XCTAssertFalse(state.displayName.isEmpty)
            XCTAssertFalse(state.bodyInterpretation.isEmpty)
            XCTAssertFalse(state.emoji.isEmpty)
            XCTAssertFalse(state.verseTheme.isEmpty)
        }
        XCTAssertEqual(BiometricState.exhaustedDepleted.displayName, "Weary Soul")
        XCTAssertEqual(BiometricState.stressedAnxious.deliveryUrgency, .high)
        XCTAssertEqual(BiometricState.energizedPostWorkout.deliveryUrgency, .timeSensitive)
        XCTAssertEqual(BiometricState.peacefulSteady.deliveryUrgency, .standard)
    }
}

final class TimeOfDayTests: XCTestCase {
    func testHourBoundaries() {
        XCTAssertEqual(TimeOfDay(hour: 5), .earlyMorning)
        XCTAssertEqual(TimeOfDay(hour: 7), .earlyMorning)
        XCTAssertEqual(TimeOfDay(hour: 8), .morning)
        XCTAssertEqual(TimeOfDay(hour: 11), .morning)
        XCTAssertEqual(TimeOfDay(hour: 12), .afternoon)
        XCTAssertEqual(TimeOfDay(hour: 16), .afternoon)
        XCTAssertEqual(TimeOfDay(hour: 17), .evening)
        XCTAssertEqual(TimeOfDay(hour: 20), .evening)
        XCTAssertEqual(TimeOfDay(hour: 21), .night)
        XCTAssertEqual(TimeOfDay(hour: 2), .night)
    }
}

final class HealthQualityTests: XCTestCase {
    func testFactories() {
        XCTAssertEqual(HealthQuality.forHeartRate(70, restingBPM: 60), .good)
        XCTAssertEqual(HealthQuality.forHeartRate(85, restingBPM: 60), .fair)
        XCTAssertEqual(HealthQuality.forHeartRate(100, restingBPM: 60), .poor)
        XCTAssertEqual(HealthQuality.forHeartRate(100, restingBPM: nil), .unavailable)
        XCTAssertEqual(HealthQuality.forHRV(55), .good)
        XCTAssertEqual(HealthQuality.forOxygen(0.95), .fair)
        XCTAssertEqual(HealthQuality.forSleepEfficiency(0.6), .poor)
    }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --package-path PulseShared` → compile errors (types undefined).
- [ ] **Step 3: Implement the five model files.** Copy enum bodies verbatim from the Instruction doc line ranges listed in Interfaces above, adding `public` access, `Sendable`, and the two `TimeOfDay` initializers. Delete the Task-0 placeholder source and test files.
- [ ] **Step 4: Run tests** — expected: all PASS.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: shared model enums (BiometricState, TimeOfDay, translations, reactions)"`

---

### Task 2: Shared models — `HealthSnapshot`, `SleepBreakdown`, `ClassificationResult`, `BibleVerse`, `WatchMessage`

**Files:**
- Create: `PulseShared/Sources/PulseShared/Models/HealthSnapshot.swift`, `Models/SleepBreakdown.swift`, `Models/ClassificationResult.swift`, `Models/BibleVerse.swift`, `Models/WatchMessage.swift`
- Test: `PulseShared/Tests/PulseSharedTests/HealthSnapshotTests.swift`, `BibleVerseTests.swift`

**Interfaces:**
- Produces (all `public`, all `Codable, Sendable`):
  - `struct HealthSnapshot` — every stored property exactly as `Instructions/08_DATA_MODELS.md:141-186` (`lastWorkoutType` is `String?`), plus computed `sleepQuality: SleepQualityLevel`, `hrvCategory: HRVCategory`, `isPostWorkout: Bool`, and `mutating func computeCompleteness()` per `Instructions/08_DATA_MODELS.md:189-230`. Public memberwise-style init with every parameter defaulted to `nil` (timestamp defaults `.now`, dataCompleteness `0`). Nested `enum SleepQualityLevel: String, Codable, Sendable { case excellent, good, fair, poor, veryPoor, unknown }` and `enum HRVCategory: String, Codable, Sendable { case veryLow, low, moderate, high, veryHigh, unknown }`.
  - `struct SleepBreakdown` — fields per `Instructions/03_HEALTH_ENGINE.md:185-198`: `inBedMinutes, totalSleepMinutes, deepSleepMinutes, remMinutes, lightSleepMinutes, awakeMinutes, lateNightWakeMinutes, sleepOnsetMinutes: Double`, `bedtime: Date?`, `wakeTime: Date?`, computed `efficiency: Double` (`totalSleepMinutes / inBedMinutes`, 0 when inBed is 0).
  - `struct BiometricSubScores` — per `Instructions/08_DATA_MODELS.md:260-276` with `timeOfDay: TimeOfDay` (Task 1's type).
  - `struct ClassificationResult: Sendable` — `state: BiometricState`, `confidence: Double`, `snapshot: HealthSnapshot`, `classifiedAt: Date`, `subScores: BiometricSubScores`, computed `isHighConfidence` (≥ 0.80) and `isMarginal` (< 0.65). Public init with `classifiedAt` defaulting `.now`.
  - `struct BibleVerse: Codable, Identifiable, Hashable, Sendable` — per `Instructions/08_DATA_MODELS.md:286-305`: `id` (USFM string), `reference`, `text`, `translationAbbreviation`, `copyright`, `chapterURLString: String?`, computed `chapterURL: URL?`, `func excerpt(maxChars: Int = 60) -> String` (truncate at last space, append `"..."`).
  - `enum WatchMessage` namespace — `MessageType: String` enum (`verseDelivery = "verse_delivery"`, `healthSummary = "health_summary"`, `verseReaction = "verse_reaction"`, `settingsUpdate = "settings_update"`) and three Codable payload structs exactly per `Instructions/08_DATA_MODELS.md:567-597` (`VerseDeliveryPayload`, `HealthSummaryPayload`, `ReactionPayload`). Add on each payload: `func dictionary(type:) -> [String: Any]` (JSON-encode → JSONSerialization) and `static func from(_ dict: [String: Any]) -> Self?` — WCSession transports `[String: Any]`, these two helpers keep every conversion in one tested place.

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import PulseShared

final class HealthSnapshotTests: XCTestCase {
    func testCompletenessCountsNineTrackedFields() {
        var s = HealthSnapshot()
        s.computeCompleteness()
        XCTAssertEqual(s.dataCompleteness, 0.0)

        s.heartRate = 72; s.heartRateVariability = 48; s.restingHeartRate = 58
        s.respiratoryRate = 15; s.oxygenSaturation = 0.97
        s.sleepEfficiency = 0.85; s.totalSleepMinutes = 420
        s.stepCount = 4000; s.activeEnergyBurned = 300
        s.computeCompleteness()
        XCTAssertEqual(s.dataCompleteness, 1.0, accuracy: 0.001)

        var half = HealthSnapshot()
        half.heartRate = 72; half.heartRateVariability = 48
        half.restingHeartRate = 58; half.respiratoryRate = 15
        half.computeCompleteness()
        XCTAssertEqual(half.dataCompleteness, 4.0/9.0, accuracy: 0.001)
    }
    func testSleepQualityBands() {
        var s = HealthSnapshot()
        XCTAssertEqual(s.sleepQuality, .unknown)
        s.sleepEfficiency = 0.95; s.totalSleepMinutes = 450
        XCTAssertEqual(s.sleepQuality, .excellent)
        s.sleepEfficiency = 0.85; s.totalSleepMinutes = 400
        XCTAssertEqual(s.sleepQuality, .good)
        s.sleepEfficiency = 0.75; s.totalSleepMinutes = 320
        XCTAssertEqual(s.sleepQuality, .fair)
        s.sleepEfficiency = 0.9; s.totalSleepMinutes = 200
        XCTAssertEqual(s.sleepQuality, .veryPoor)
    }
    func testIsPostWorkoutWindow() {
        var s = HealthSnapshot()
        XCTAssertFalse(s.isPostWorkout)
        s.lastWorkoutEndedMinutesAgo = 10
        XCTAssertTrue(s.isPostWorkout)
        s.lastWorkoutEndedMinutesAgo = 61
        XCTAssertFalse(s.isPostWorkout)
    }
    func testWatchMessageRoundTrip() {
        let payload = WatchMessage.VerseDeliveryPayload(
            deliveryID: "abc", verseText: "Come to me", verseReference: "Matthew 11:28",
            translationAbbreviation: "NIV", stateRaw: "exhausted_depleted",
            stateDisplayName: "Weary Soul", stateEmoji: "🌙",
            stateBodyText: "Your body is asking for rest. Come and lay it down.",
            primaryColor: "#6366F1", timestamp: 123.0)
        let dict = payload.dictionary(type: .verseDelivery)
        XCTAssertEqual(dict["type"] as? String, "verse_delivery")
        let decoded = WatchMessage.VerseDeliveryPayload.from(dict)
        XCTAssertEqual(decoded?.verseReference, "Matthew 11:28")
    }
}

final class BibleVerseTests: XCTestCase {
    func testExcerptTruncatesAtWordBoundary() {
        let verse = BibleVerse(id: "MAT.11.28", reference: "Matthew 11:28",
            text: "Come to me, all you who are weary and burdened, and I will give you rest.",
            translationAbbreviation: "NIV", copyright: "©", chapterURLString: nil)
        XCTAssertEqual(verse.excerpt(maxChars: 20), "Come to me, all you...")
        XCTAssertEqual(verse.excerpt(maxChars: 200), verse.text)
    }
}
```

- [ ] **Step 2: Run to verify failure** — compile errors expected.
- [ ] **Step 3: Implement the five files** per the Interfaces block. `computeCompleteness` counts exactly the 9 fields listed in `Instructions/08_DATA_MODELS.md:219-229` (5 vitals + sleepEfficiency + totalSleepMinutes + stepCount + activeEnergyBurned).
- [ ] **Step 4: Run tests** — expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat: HealthSnapshot, ClassificationResult, BibleVerse, WatchMessage models"`

---

### Task 3: `SleepAnalyzer`

**Files:**
- Create: `PulseShared/Sources/PulseShared/Logic/SleepAnalyzer.swift`
- Test: `PulseShared/Tests/PulseSharedTests/SleepAnalyzerTests.swift`

**Interfaces:**
- Produces:
  - `enum SleepStage: Sendable { case inBed, awake, core, deep, rem, unspecified }` and `struct SleepSample: Sendable { public let stage: SleepStage; public let start: Date; public let end: Date }` — the HealthKit-free representation. (Task 9's `MetricCollector` maps `HKCategoryValueSleepAnalysis` → `SleepStage`.)
  - `struct SleepAnalyzer { public init(); public func analyze(samples: [SleepSample], calendar: Calendar = .current) -> SleepBreakdown? }` — returns nil for empty input. Mapping rules per `Instructions/03_HEALTH_ENGINE.md:166-206`: core→light, deep→deep, rem→rem, unspecified→total only, awake→awakeMinutes (and →lateNightWakeMinutes when the sample starts after midnight of the wake day), inBed→inBedMinutes only. `totalSleepMinutes` = light+deep+rem+unspecified. `sleepOnsetMinutes` = minutes from first inBed start to first asleep-stage start (0 if no inBed sample). `bedtime` = earliest sample start; `wakeTime` = latest asleep-sample end. When no `.inBed` samples exist, `inBedMinutes` = span from bedtime to wakeTime.

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import PulseShared

final class SleepAnalyzerTests: XCTestCase {
    // Helper: a date at a given hour:minute on a fixed day (Jan 2, 2026)
    private func t(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 1; c.day = day
        c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(SleepAnalyzer().analyze(samples: []))
    }

    func testFullNightBreakdown() {
        // In bed 23:00–07:00. Asleep 23:20–06:50 with stages; awake 03:00–03:15.
        let samples: [SleepSample] = [
            SleepSample(stage: .inBed, start: t(1, 23), end: t(2, 7)),
            SleepSample(stage: .core,  start: t(1, 23, 20), end: t(2, 1)),   // 100m light
            SleepSample(stage: .deep,  start: t(2, 1),      end: t(2, 2, 30)), // 90m deep
            SleepSample(stage: .awake, start: t(2, 3),      end: t(2, 3, 15)), // 15m awake after midnight
            SleepSample(stage: .rem,   start: t(2, 3, 15),  end: t(2, 5)),   // 105m REM
            SleepSample(stage: .core,  start: t(2, 5),      end: t(2, 6, 50)), // 110m light
        ]
        let b = SleepAnalyzer().analyze(samples: samples)!
        XCTAssertEqual(b.inBedMinutes, 480, accuracy: 0.5)
        XCTAssertEqual(b.deepSleepMinutes, 90, accuracy: 0.5)
        XCTAssertEqual(b.remMinutes, 105, accuracy: 0.5)
        XCTAssertEqual(b.lightSleepMinutes, 210, accuracy: 0.5)
        XCTAssertEqual(b.totalSleepMinutes, 405, accuracy: 0.5)
        XCTAssertEqual(b.awakeMinutes, 15, accuracy: 0.5)
        XCTAssertEqual(b.lateNightWakeMinutes, 15, accuracy: 0.5)
        XCTAssertEqual(b.sleepOnsetMinutes, 20, accuracy: 0.5)
        XCTAssertEqual(b.efficiency, 405.0/480.0, accuracy: 0.01)
        XCTAssertEqual(b.bedtime, t(1, 23))
        XCTAssertEqual(b.wakeTime, t(2, 6, 50))
    }

    func testNoInBedSamplesFallsBackToSpan() {
        let samples: [SleepSample] = [
            SleepSample(stage: .unspecified, start: t(1, 23), end: t(2, 6)),
        ]
        let b = SleepAnalyzer().analyze(samples: samples)!
        XCTAssertEqual(b.totalSleepMinutes, 420, accuracy: 0.5)
        XCTAssertEqual(b.inBedMinutes, 420, accuracy: 0.5)
        XCTAssertEqual(b.efficiency, 1.0, accuracy: 0.01)
    }
}
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement** — pure arithmetic over the samples per the Interfaces rules.
- [ ] **Step 4: Run tests** — PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat: SleepAnalyzer with stage mapping and efficiency"`

---

### Task 4: Design tokens in `PulseShared/Design`

**Files:**
- Create: `PulseShared/Sources/PulseShared/Design/Colors.swift`, `Design/Gradients.swift`, `Design/Typography.swift`, `Design/Spacing.swift`, `Design/Animations.swift`
- Test: `PulseShared/Tests/PulseSharedTests/ColorHexTests.swift`

**Interfaces:**
- Produces (all `public`):
  - `Color(hex: String)` failable-tolerant init (accepts `#RRGGBB`, falls back to black on bad input — never crashes).
  - `extension Color` with the 10 brand/semantic colors named exactly per `Instructions/07_UI_DESIGN_SYSTEM.md:21-35` (`psDeepNavy` … `psAlert`).
  - `extension BiometricState`: `var gradient: LinearGradient` and `var primaryColor: Color` — hex values and start/end points verbatim from `Instructions/07_UI_DESIGN_SYSTEM.md:46-153`; `var primaryColorHex: String` (the same hex strings, used by WatchMessage payloads).
  - `enum PSFont` (`verseText(size:)` = `.system(size:design:.serif)`, `label(size:weight:)` rounded, `metric(size:)` monospaced) per `Instructions/07_UI_DESIGN_SYSTEM.md:180-197`; use the system serif design rather than `.custom("NewYork",…)` — New York is the built-in serif.
  - `enum PSSpacing`, `enum PSRadius` per `Instructions/07_UI_DESIGN_SYSTEM.md:218-243`.
  - `extension Animation` (psCardSpring, psVerseTransition, psTapFeedback, psStateChange, psPulse) and `extension AnyTransition` (psSlideUp, psFadeScale) per `Instructions/07_UI_DESIGN_SYSTEM.md:452-487`.
  - `extension View`: `psCardShadow()`, `psSubtleShadow()`, `psGlowEffect(color:)` per `Instructions/07_UI_DESIGN_SYSTEM.md:250-263`.
  - `extension HealthQuality { var color: Color }` mapping per `Instructions/08_DATA_MODELS.md:640-647`.

- [ ] **Step 1: Write failing test**

```swift
import XCTest
import SwiftUI
@testable import PulseShared

final class ColorHexTests: XCTestCase {
    func testHexParsingProducesExpectedComponents() {
        let gold = Color(hex: "#C9A96E")
        let resolved = gold.resolve(in: .init())
        XCTAssertEqual(resolved.red, 201.0/255.0, accuracy: 0.01)
        XCTAssertEqual(resolved.green, 169.0/255.0, accuracy: 0.01)
        XCTAssertEqual(resolved.blue, 110.0/255.0, accuracy: 0.01)
    }
    func testBadHexDoesNotCrash() {
        _ = Color(hex: "not-a-color")
    }
    func testEveryStateHasGradientAndPrimaryColor() {
        for state in BiometricState.allCases {
            _ = state.gradient
            _ = state.primaryColor
            XCTAssertTrue(state.primaryColorHex.hasPrefix("#"))
        }
    }
}
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement the five design files**, copying every hex value and constant verbatim from the doc-07 line ranges above.
- [ ] **Step 4: Run tests** — PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat: design tokens (colors, state gradients, typography, spacing, motion)"`

---

### Task 5: `StateClassifier`

**Files:**
- Create: `PulseShared/Sources/PulseShared/Logic/StateClassifier.swift`
- Test: `PulseShared/Tests/PulseSharedTests/StateClassifierTests.swift`

**Interfaces:**
- Consumes: `HealthSnapshot`, `BiometricSubScores`, `ClassificationResult`, `TimeOfDay`.
- Produces: `struct StateClassifier { public init(); public func classify(_ snapshot: HealthSnapshot, at date: Date = .now, calendar: Calendar = .current) -> ClassificationResult; public func computeSubScores(_ snapshot: HealthSnapshot, at date: Date, calendar: Calendar) -> BiometricSubScores }`.
- Sub-score formulas exactly per `Instructions/03_HEALTH_ENGINE.md:239-299` (hrStress, hrvRecovery, sleepQuality, oxygenLevel, activityLevel; defaults when nil: 0.5, 0.5, 0.5, 0.7, computed-from-zeros respectively). `respiratoryStress`: 1.0 for rate ≤ 16, linearly down to 0.0 at 24, default 0.5 when nil. `recoveryPost` is not a stored sub-score (doc 08's struct omits it) — post-workout timing lives in the Victory Lap confidence function.
- The five spec'd confidence functions verbatim per `Instructions/03_HEALTH_ENGINE.md:304-358` (victoryLap, stressed, exhausted, sabbathMorning, watchman — watchman requires `timeOfDay == .night`). The seven remaining functions follow the doc-01 trigger table (`Instructions/01_PROJECT_OVERVIEW.md:52-65`), implemented as:
  - `peaceful`: `(scores.hrStress * 0.4 + scores.hrvRecovery * 0.4 + (1 - abs(scores.activityLevel - 0.4)) * 0.2)`, gated to 0 unless no workout within 60 min.
  - `morning`: gated to `timeOfDay == .earlyMorning`; `0.6 + scores.sleepQuality * 0.4` scaled by whether wakeTime (snapshot) is within 90 min of `date` when available, else `0.55`.
  - `evening`: gated to `timeOfDay == .evening`; `(1 - scores.activityLevel) * 0.5 + scores.hrStress * 0.5`.
  - `active`: `scores.activityLevel * 0.7 + scores.hrStress * 0.3`, gated to 0 if `isPostWorkout`.
  - `sad`: `(1 - scores.activityLevel) * 0.4 + (1 - scores.sleepQuality) * 0.3 + (1 - scores.hrvRecovery) * 0.3`, capped at 0.9.
  - `sick`: requires restingHeartRate and respiratoryRate present, else 0; `((1 - scores.respiratoryStress) * 0.4 + (1 - scores.oxygenLevel) * 0.4 + (1 - scores.hrvRecovery) * 0.2) * 1.15` capped 1.0.
  - `peak`: `(scores.hrvRecovery * 0.35 + scores.sleepQuality * 0.3 + scores.oxygenLevel * 0.15 + scores.activityLevel * 0.2)`, gated to 0 unless hrvRecovery ≥ 0.7 and sleepQuality ≥ 0.6.
- Final selection per `Instructions/03_HEALTH_ENGINE.md:360-389`: highest confidence ≥ 0.65 wins; otherwise time-of-day fallback with confidence 0.5 (`earlyMorning→.morningAwakening`, `morning/afternoon→.peacefulSteady`, `evening→.eveningWindingDown`, `night→.peacefulSteady`).

- [ ] **Step 1: Write failing tests** — one snapshot fixture per state that must win, plus the fallback:

```swift
import XCTest
@testable import PulseShared

final class StateClassifierTests: XCTestCase {
    private let classifier = StateClassifier()
    private func date(hour: Int) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 1; c.day = 15; c.hour = hour
        return Calendar.current.date(from: c)!
    }
    private func classify(_ s: HealthSnapshot, hour: Int) -> ClassificationResult {
        var snap = s; snap.computeCompleteness()
        return classifier.classify(snap, at: date(hour: hour))
    }

    func testVictoryLapAfterWorkout() {
        var s = HealthSnapshot()
        s.heartRate = 110; s.restingHeartRate = 58; s.heartRateVariability = 55
        s.lastWorkoutEndedMinutesAgo = 20; s.lastWorkoutType = "running"
        s.stepCount = 9000; s.activeEnergyBurned = 520; s.exerciseMinutes = 40
        XCTAssertEqual(classify(s, hour: 18).state, .energizedPostWorkout)
    }
    func testStressedAnxious() {
        var s = HealthSnapshot()
        s.heartRate = 96; s.restingHeartRate = 58; s.heartRateVariability = 18
        s.sleepEfficiency = 0.8; s.totalSleepMinutes = 400; s.stepCount = 3000
        XCTAssertEqual(classify(s, hour: 14).state, .stressedAnxious)
    }
    func testExhaustedDepleted() {
        var s = HealthSnapshot()
        s.heartRate = 64; s.restingHeartRate = 60; s.heartRateVariability = 16
        s.oxygenSaturation = 0.93; s.sleepEfficiency = 0.55; s.totalSleepMinutes = 250
        s.deepSleepMinutes = 15; s.stepCount = 800; s.activeEnergyBurned = 60
        XCTAssertEqual(classify(s, hour: 14).state, .exhaustedDepleted)
    }
    func testSabbathMorning() {
        var s = HealthSnapshot()
        s.heartRate = 56; s.restingHeartRate = 55; s.heartRateVariability = 85
        s.oxygenSaturation = 0.99; s.sleepEfficiency = 0.95; s.totalSleepMinutes = 480
        s.deepSleepMinutes = 100; s.remSleepMinutes = 110
        XCTAssertEqual(classify(s, hour: 9).state, .deepRestRecovered)
    }
    func testWatchmanHourAtNight() {
        var s = HealthSnapshot()
        s.heartRate = 58; s.restingHeartRate = 56; s.heartRateVariability = 50
        s.lateNightWakeMinutes = 35
        s.sleepEfficiency = 0.7; s.totalSleepMinutes = 300; s.stepCount = 0
        XCTAssertEqual(classify(s, hour: 2).state, .spiritualAlert)
    }
    func testSickUnwell() {
        var s = HealthSnapshot()
        s.heartRate = 88; s.restingHeartRate = 72; s.heartRateVariability = 22
        s.respiratoryRate = 23; s.oxygenSaturation = 0.92
        s.sleepEfficiency = 0.75; s.totalSleepMinutes = 380; s.stepCount = 900
        XCTAssertEqual(classify(s, hour: 11).state, .sickUnwell)
    }
    func testPeakPerformance() {
        var s = HealthSnapshot()
        s.heartRate = 60; s.restingHeartRate = 52; s.heartRateVariability = 95
        s.oxygenSaturation = 0.99; s.sleepEfficiency = 0.93; s.totalSleepMinutes = 470
        s.deepSleepMinutes = 95; s.stepCount = 11000; s.activeEnergyBurned = 640
        s.exerciseMinutes = 45
        let r = classify(s, hour: 15)
        XCTAssertTrue([.peakPerformance, .activeEngaged].contains(r.state))
        XCTAssertEqual(r.state, .peakPerformance)
    }
    func testActiveEngaged() {
        var s = HealthSnapshot()
        s.heartRate = 72; s.restingHeartRate = 60; s.heartRateVariability = 45
        s.sleepEfficiency = 0.78; s.totalSleepMinutes = 380
        s.stepCount = 9500; s.activeEnergyBurned = 480; s.exerciseMinutes = 35
        XCTAssertEqual(classify(s, hour: 15).state, .activeEngaged)
    }
    func testFallbackWhenNothingConfident() {
        var s = HealthSnapshot()
        s.heartRate = 70; s.restingHeartRate = 62; s.heartRateVariability = 45
        let r = classify(s, hour: 14)
        XCTAssertEqual(r.confidence, 0.5, accuracy: 0.001)
        XCTAssertEqual(r.state, .peacefulSteady)
    }
    func testNeverCrashesOnEmptySnapshot() {
        for hour in [3, 7, 10, 14, 19, 22] {
            _ = classify(HealthSnapshot(), hour: hour)
        }
    }
}
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement** sub-scores, twelve confidence functions, and selection per Interfaces. If a fixture selects the wrong state, adjust the *fixture toward a more clearly representative body state* first; only touch weights the spec leaves open (the seven non-spec'd functions), never the five spec'd formulas.
- [ ] **Step 4: Run tests** — PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat: StateClassifier with 12-state scoring matrix"`

---

### Task 6: `DeliveryRulesEngine`

**Files:**
- Create: `PulseShared/Sources/PulseShared/Logic/DeliveryRulesEngine.swift`
- Test: `PulseShared/Tests/PulseSharedTests/DeliveryRulesEngineTests.swift`

**Interfaces:**
- Consumes: `ClassificationResult`, `BiometricState`.
- Produces:

```swift
public enum DeliveryRules {
    public static let minimumTimeBetweenDeliveries: TimeInterval = 2 * 3600
    public static let minimumSameStateDelay: TimeInterval = 12 * 3600
    public static let defaultMaxDailyDeliveries = 5
    public static let nightSilenceHours: ClosedRange<Int> = 0...5
    public static let minimumDataCompleteness = 0.40
    public static let minimumConfidence = 0.65
    public static let urgencyOverrideConfidence = 0.85
}

public struct DeliveryContext: Sendable {
    public var now: Date
    public var todayDeliveryCount: Int
    public var lastDeliveryAt: Date?
    public var lastSameStateDeliveryAt: Date?
    public var maxDailyDeliveries: Int   // 0 or less means "use default"
    public init(...)                      // memberwise, defaults: counts 0, dates nil, max 5
}

public struct DeliveryDecision: Sendable {
    public let approved: Bool
    public let reason: String            // machine-readable, e.g. "night_silence"
}

public struct DeliveryRulesEngine {
    public init()
    public func shouldDeliver(for result: ClassificationResult,
                              context: DeliveryContext,
                              calendar: Calendar = .current) -> DeliveryDecision
}
```

- Rule order exactly per `Instructions/04_AI_SCRIPTURE_ENGINE.md:449-491`: (1) hours 0–5 rejected unless state is `.spiritualAlert` → reason `night_silence`; (2) completeness < 0.40 → `insufficient_data`; (3) confidence < 0.65 → `low_confidence`; (4) daily limit → `daily_limit`; (5) global 2h cooldown → `cooldown`; (6) same-state 12h cooldown → `same_state_cooldown`. The urgency override (high-urgency states with confidence > 0.85) bypasses rules 5 and 6 only — reason `approved_urgent`; normal approval reason `approved`.

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import PulseShared

final class DeliveryRulesEngineTests: XCTestCase {
    private let engine = DeliveryRulesEngine()
    private func result(_ state: BiometricState, confidence: Double,
                        completeness: Double = 0.8) -> ClassificationResult {
        var snap = HealthSnapshot(); snap.dataCompleteness = completeness
        let scores = BiometricSubScores(hrStress: 0.5, hrvRecovery: 0.5, sleepQuality: 0.5,
            oxygenLevel: 0.7, activityLevel: 0.5, respiratoryStress: 0.5, timeOfDay: .afternoon)
        return ClassificationResult(state: state, confidence: confidence,
                                    snapshot: snap, subScores: scores)
    }
    private func at(hour: Int) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 1; c.day = 15; c.hour = hour
        return Calendar.current.date(from: c)!
    }

    func testNightSilenceBlocksExceptWatchman() {
        let ctx = DeliveryContext(now: at(hour: 3))
        XCTAssertFalse(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.9), context: ctx).approved)
        XCTAssertTrue(engine.shouldDeliver(for: result(.spiritualAlert, confidence: 0.9), context: ctx).approved)
    }
    func testDataAndConfidenceThresholds() {
        let ctx = DeliveryContext(now: at(hour: 10))
        XCTAssertEqual(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.9, completeness: 0.2), context: ctx).reason, "insufficient_data")
        XCTAssertEqual(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.5), context: ctx).reason, "low_confidence")
    }
    func testDailyLimitAndCooldowns() {
        var ctx = DeliveryContext(now: at(hour: 10))
        ctx.todayDeliveryCount = 5
        XCTAssertEqual(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.8), context: ctx).reason, "daily_limit")

        ctx = DeliveryContext(now: at(hour: 10))
        ctx.lastDeliveryAt = at(hour: 9)  // 1h ago < 2h cooldown
        XCTAssertEqual(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.8), context: ctx).reason, "cooldown")

        ctx = DeliveryContext(now: at(hour: 22))
        ctx.lastDeliveryAt = at(hour: 8)
        ctx.lastSameStateDeliveryAt = at(hour: 14) // 8h ago < 12h same-state
        XCTAssertEqual(engine.shouldDeliver(for: result(.peacefulSteady, confidence: 0.8), context: ctx).reason, "same_state_cooldown")
    }
    func testUrgencyOverrideBypassesCooldownsOnly() {
        var ctx = DeliveryContext(now: at(hour: 10))
        ctx.lastDeliveryAt = at(hour: 9, minute: 30)
        let urgent = result(.stressedAnxious, confidence: 0.9)
        XCTAssertEqual(engine.shouldDeliver(for: urgent, context: ctx).reason, "approved_urgent")
        // but not the daily limit
        ctx.todayDeliveryCount = 5
        XCTAssertFalse(engine.shouldDeliver(for: urgent, context: ctx).approved)
        // and not night silence
        let night = DeliveryContext(now: at(hour: 2))
        XCTAssertFalse(engine.shouldDeliver(for: urgent, context: night).approved)
    }
    private func at(hour: Int, minute: Int) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 1; c.day = 15
        c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }
}
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement** per rule order above.
- [ ] **Step 4: Run tests** — PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat: DeliveryRulesEngine with cooldowns and urgency override"`

---

### Task 7: Emergency verses + `FallbackVerseProvider`

**Files:**
- Create: `PulseShared/Sources/PulseShared/Resources/emergency_verses.json`, `PulseShared/Sources/PulseShared/Logic/FallbackVerseProvider.swift`
- Test: `PulseShared/Tests/PulseSharedTests/FallbackVerseProviderTests.swift`

**Interfaces:**
- Produces:
  - `emergency_verses.json` — copy verbatim from `Instructions/04_AI_SCRIPTURE_ENGINE.md:512-573` (12 entries keyed by state raw value, each `{reference, text, translation}`).
  - `public struct FallbackVerseProvider { public init(); public func emergencyVerse(for state: BiometricState) -> BibleVerse; public static func fallbackReference(for state: BiometricState) -> String }`. `fallbackReference` map verbatim per `Instructions/04_AI_SCRIPTURE_ENGINE.md:117-134`. `emergencyVerse` decodes the bundled JSON via `Bundle.module`; on any decode failure returns the hardcoded Matthew 11:28 NIV verse (belt-and-braces — the acceptance criteria forbid an empty screen). BibleVerse `id` for emergency verses: the reference string; `copyright`: `"NIV. Bundled for offline use."`.

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import PulseShared

final class FallbackVerseProviderTests: XCTestCase {
    func testEveryStateHasEmergencyVerse() {
        let provider = FallbackVerseProvider()
        for state in BiometricState.allCases {
            let verse = provider.emergencyVerse(for: state)
            XCTAssertFalse(verse.text.isEmpty, "no emergency verse for \(state.rawValue)")
            XCTAssertFalse(verse.reference.isEmpty)
        }
    }
    func testKnownMappings() {
        XCTAssertEqual(FallbackVerseProvider.fallbackReference(for: .exhaustedDepleted), "Matthew 11:28-30")
        XCTAssertEqual(FallbackVerseProvider.fallbackReference(for: .peakPerformance), "Isaiah 40:31")
        let verse = FallbackVerseProvider().emergencyVerse(for: .stressedAnxious)
        XCTAssertEqual(verse.reference, "John 14:27")
    }
}
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement** JSON + provider.
- [ ] **Step 4: Run tests** — PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat: bundled emergency verses and fallback provider"`

---

### Task 8: API clients — `GlooAIClient` + `YouVersionClient` (live contracts)

**Files:**
- Create: `PulseShared/Sources/PulseShared/Scripture/ScriptureProtocols.swift`, `Scripture/GlooAIClient.swift`, `Scripture/YouVersionClient.swift`
- Test: `PulseShared/Tests/PulseSharedTests/GlooAIClientTests.swift`, `YouVersionClientTests.swift`

**Interfaces:**
- Produces:

```swift
public struct VerseSelectionContext: Sendable {
    public var state: BiometricState
    public var timeOfDay: TimeOfDay
    public var confidence: Double
    public var recentStates: [BiometricState]
    public var translation: BibleTranslationID
    public var preferredThemes: [String]
    public var avoidRepeats: [String]
    public init(...)  // memberwise, arrays default []
}

public struct VerseSelection: Sendable {
    public let reference: String          // "Matthew 11:28" or "Matthew 11:28-30"
    public let theme: String
    public let themeDisplayName: String
    public let rationale: String?
    public let alternates: [String]
    public let isFallback: Bool
    public init(...)
}

public protocol VerseSelecting: Sendable {
    func selectVerse(for context: VerseSelectionContext) async throws -> VerseSelection
}

public protocol VerseFetching: Sendable {
    func fetchVerse(reference: String, translation: BibleTranslationID) async throws -> BibleVerse
}

public enum ScriptureAPIError: Error, Equatable {
    case notConfigured, authFailed, requestFailed(status: Int), decodingFailed, timedOut
}
```

  - `public actor GlooAIClient: VerseSelecting` — `init(clientID: String, clientSecret: String, session: URLSession = .shared)`. OAuth2 client-credentials token fetch (cached until expiry with 60s margin), then a chat-completions call carrying the doc-04 system prompt (`Instructions/04_AI_SCRIPTURE_ENGINE.md:141-158`) and a user message containing ONLY the `VerseSelectionContext` fields as JSON. Response must be parsed from the model's JSON output into `VerseSelection`; on any parse failure throw `.decodingFailed`. **The exact endpoint URLs, token URL, model name, and header shapes MUST be verified against the live Gloo AI Studio docs before implementing** (see Step 0 below). Requests time out at 15s.
  - `public struct YouVersionClient: VerseFetching` — `init(appKey: String, session: URLSession = .shared)`. Fetches verse text for a human reference + translation ID. **Endpoint shape verified against live YouVersion Platform docs in Step 0.** Must handle verse ranges ("Matthew 11:28-30"). Timeout 10s. Reference→USFM conversion helper `public enum USFM { public static func usfm(for reference: String) -> String? }` with the 66-book abbreviation table (BibleVerse ids like `MAT.11.28`); if the live API accepts human-readable references directly, USFM is still needed for `BibleVerse.id` and bible.com chapter URLs.
  - Both clients accept an injected `URLSession` so tests use `URLProtocol` stubs; add `final class StubURLProtocol: URLProtocol` in the test target with a static `requestHandler` closure.

- [ ] **Step 0: Verify live API contracts.** Using WebFetch/WebSearch from the coordinating session (subagents relay findings): fetch the current docs at `https://docs.ai.gloo.com` (or whatever `https://studio.ai.gloo.com` links as API docs) and `https://developers.youversion.com` / YouVersion Platform docs. Record in code comments at the top of each client file: auth mechanism, base URL, endpoint paths, request/response JSON. If the real contracts differ from the expectations above, adjust the client internals — the `VerseSelecting`/`VerseFetching` public interfaces must not change.
- [ ] **Step 1: Ask Joel for credentials** (coordinator does this — AskUserQuestion): Gloo client ID + secret, YouVersion app key. Write them into `Config/Debug.xcconfig` (gitignored). Verify with `git status` that no xcconfig with keys is staged.
- [ ] **Step 2: Write failing tests** (transport-stubbed; no live network in tests):

```swift
import XCTest
@testable import PulseShared

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.requestHandler else { return }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

func stubbedSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: config)
}

final class GlooAIClientTests: XCTestCase {
    func testSelectVerseParsesModelJSON() async throws {
        // Handler: first request (token) → access_token JSON;
        // second (completion) → chat response whose message content is the doc-04 JSON:
        // {"verse_reference":"Matthew 11:28","theme":"rest_renewal",
        //  "theme_display_name":"Rest & Renewal","rationale":"…","alternates":["Psalm 23:1"]}
        // (Exact wrapper shape per the verified live contract — adjust in Step 3.)
        // Assert: returned VerseSelection.reference == "Matthew 11:28",
        //         theme == "rest_renewal", isFallback == false.
        // Assert on the captured completion request body: it contains
        // "exhausted_depleted" and does NOT contain any digit-bearing health field
        // (scan for "heartRate", "hrv", "bpm").
    }
    func testGarbageModelOutputThrowsDecodingFailed() async {
        // Model content = "I think Psalm 23 is nice" (not JSON) → expect .decodingFailed
    }
    func testHTTP500ThrowsRequestFailed() async { /* status 500 → .requestFailed(500) */ }
}

final class YouVersionClientTests: XCTestCase {
    func testFetchVerseParsesResponse() async throws {
        // Stub the verified live response shape for Matthew 11:28 NIV;
        // assert BibleVerse.reference/text/translationAbbreviation.
    }
    func testUSFMConversion() {
        XCTAssertEqual(USFM.usfm(for: "Matthew 11:28"), "MAT.11.28")
        XCTAssertEqual(USFM.usfm(for: "Psalm 34:18"), "PSA.34.18")
        XCTAssertEqual(USFM.usfm(for: "1 John 4:19"), "1JN.4.19")
        XCTAssertEqual(USFM.usfm(for: "Matthew 11:28-30"), "MAT.11.28-MAT.11.30")
        XCTAssertNil(USFM.usfm(for: "Bogus 99:99"))
    }
    func testAuthFailureThrows() async { /* status 401 → .authFailed */ }
}
```

The comment-bodied tests above are written out fully once the Step-0 contract is known — the assertions listed are the required minimum.

- [ ] **Step 3: Run to verify failure, then implement both clients** against the verified contracts.
- [ ] **Step 4: Run tests** — PASS.
- [ ] **Step 5: Live smoke test.** Temporary executable check (not committed as a target): a small `swift run`-able snippet or `swift test` tagged `LiveSmokeTests` (skipped unless env `PULSE_LIVE_SMOKE=1`) that reads keys from `Config/Debug.xcconfig`, calls Gloo with state `exhausted_depleted`, feeds the returned reference to YouVersion, and prints the verse. Run once: `PULSE_LIVE_SMOKE=1 swift test --package-path PulseShared --filter LiveSmokeTests`. Expected: a real verse prints. If either live API rejects us, stop and resolve with Joel before proceeding — downstream tasks depend on the contract.
- [ ] **Step 6: Commit** — `git commit -m "feat: Gloo AI and YouVersion clients with verified live contracts"` (confirm `git status` shows no real keys).

---

### Task 9: iOS persistence + health engine

**Files:**
- Create: `Pulse/Core/Persistence/PulseSchema.swift`, `Pulse/Core/Persistence/ModelContainer+Setup.swift`, `Pulse/Core/Health/HealthDataProviding.swift`, `Pulse/Core/Health/MetricCollector.swift`, `Pulse/Core/Health/MockHealthProvider.swift`, `Pulse/Core/Health/HealthEngine.swift`, `Pulse/App/AppConfig.swift`
- Modify: `Pulse/App/PulseApp.swift` (attach model container)

**Interfaces:**
- Consumes: `HealthSnapshot`, `SleepAnalyzer`, `SleepSample`, `StateClassifier`, `ClassificationResult` from PulseShared.
- Produces:
  - SwiftData `@Model` classes `VerseDelivery`, `CachedVerse`, `UserPreferences` — properties exactly per `Instructions/08_DATA_MODELS.md:318-465` including computed `biometricState`, `userReaction`, `preferredTranslation` bridges. `ModelContainer.pulse` per `Instructions/08_DATA_MODELS.md:609-626` but **without `try!`**: a throwing factory `static func makePulseContainer() throws -> ModelContainer` plus an in-memory fallback if the App Group container fails (log + degrade, never crash).
  - `protocol HealthDataProviding: Sendable { func requestAuthorization() async throws; func fetchSnapshot() async throws -> HealthSnapshot; var isAvailable: Bool { get } }`
  - `final class MetricCollector: HealthDataProviding` — real HealthKit. Read-type set per `Instructions/03_HEALTH_ENGINE.md:29-59`; query windows per the table at `Instructions/03_HEALTH_ENGINE.md:79-97`; sleep samples mapped `HKCategoryValueSleepAnalysis` → `SleepStage` and run through `SleepAnalyzer`; workout lookup within last 3 hours. Every metric fetch is failure-isolated (a failed query yields nil for that field, never throws out of `fetchSnapshot`). Ends with `snapshot.computeCompleteness()`.
  - `struct MockHealthProvider: HealthDataProviding` — `init(scenario: BiometricState)` returning the Task-5 test fixtures as snapshots (reuse: put the 12 fixture builders in this file as `static func snapshot(for state: BiometricState) -> HealthSnapshot`). Active automatically when `!HKHealthStore.isHealthDataAvailable()` (simulator) or launch argument `-PulseMockState <raw_value>` is present.
  - `@Observable @MainActor final class HealthEngine` — `var currentSnapshot: HealthSnapshot?`, `var currentClassification: ClassificationResult?`, `func refresh() async` (fetch → classify → publish), `func enableBackgroundDelivery()` registering `HKObserverQuery` + `enableBackgroundDelivery(.hourly)` for the five types per `Instructions/03_HEALTH_ENGINE.md:398-429`, with an `onClassification: ((ClassificationResult) async -> Void)?` callback hook that Task 10's ScriptureEngine sets.
  - `enum AppConfig` — reads `GlooClientID`, `GlooClientSecret`, `YouVersionAppKey` from `Bundle.main` Info.plist; `static var isConfigured: Bool` false when any is a `your_…_here` placeholder or empty.
- Verification for this task is the iOS build (HealthKit types don't exist on macOS; package tests can't cover MetricCollector).

- [ ] **Step 1: Implement persistence files** per Interfaces.
- [ ] **Step 2: Implement AppConfig + HealthDataProviding + MockHealthProvider.**
- [ ] **Step 3: Implement MetricCollector** (largest file of the task — one private `fetch…` method per metric, all called concurrently from `fetchSnapshot` via `async let`).
- [ ] **Step 4: Implement HealthEngine**, wire `.modelContainer` + a temporary debug HomeView placeholder in `PulseApp` that shows `currentClassification?.state.displayName ?? "—"` after `refresh()`.
- [ ] **Step 5: Build** — `xcodebuild … -scheme Pulse … build` → succeeds. Boot iPhone 16 simulator, `xcrun simctl launch` with `-PulseMockState exhausted_depleted`, screenshot shows "Weary Soul". 
- [ ] **Step 6: Commit** — `git commit -m "feat: SwiftData persistence, HealthKit MetricCollector, HealthEngine with mock provider"`

---

### Task 10: iOS ScriptureEngine + VerseCache + DeliveryScheduler + NotificationService

**Files:**
- Create: `Pulse/Core/Scripture/VerseCache.swift`, `Pulse/Core/Scripture/DeliveryScheduler.swift`, `Pulse/Core/Scripture/ScriptureEngine.swift`, `Pulse/Notifications/NotificationService.swift`
- Modify: `Pulse/App/PulseApp.swift`, `Pulse/App/AppDelegate.swift` (create; BGTask registration + notification categories)

**Interfaces:**
- Consumes: `VerseSelecting`, `VerseFetching`, `FallbackVerseProvider`, `DeliveryRulesEngine`, `DeliveryContext`, PulseShared models; Task-9 SwiftData models + `HealthEngine`.
- Produces:
  - `@MainActor final class VerseCache` — wraps ModelContext: `func verse(reference: String, translation: BibleTranslationID) -> BibleVerse?`, `func store(_ verse: BibleVerse)` (LRU eviction beyond 500 entries by `lastAccessedAt`), `func saveDelivery(_ delivery: VerseDelivery)`, `func todayDeliveryCount() -> Int`, `func lastDelivery() -> VerseDelivery?`, `func lastDelivery(for state: BiometricState) -> VerseDelivery?`, `func recentReferences(limit: Int) -> [String]`.
  - `@MainActor final class DeliveryScheduler` — builds `DeliveryContext` from VerseCache + UserPreferences (maxDailyVerses) and calls `DeliveryRulesEngine`.
  - `@Observable @MainActor final class ScriptureEngine` — `var currentDelivery: VerseDelivery?`, `var isLoading = false`; `func processStateChange(_ result: ClassificationResult) async` implementing the doc-04 pipeline (`Instructions/04_AI_SCRIPTURE_ENGINE.md:325-397`) with the full fallback chain: Gloo fails → `FallbackVerseProvider.fallbackReference` → cache → YouVersion → emergency verse; every path produces a `VerseDelivery` with `isOfflineFallback` set appropriately. Also `func deliverFirstVerse() async -> VerseDelivery` (onboarding: bypasses scheduler rules, always yields a verse) and `func deliverVerseOfDay() async` (Phase-2 stub not included — YAGNI). After persisting: post notification via NotificationService, send `WatchMessage.VerseDeliveryPayload` via PhoneSessionManager (Task 11 — until then, a `var onDelivery: ((VerseDelivery) -> Void)?` hook), `WidgetCenter.shared.reloadAllTimelines()`.
  - `final class NotificationService` — singleton; `func requestAuthorization() async -> Bool`; `func scheduleVerseNotification(_ delivery: VerseDelivery) async` with title per state category (post-workout / morning / standard templates verbatim from `Instructions/05_IPHONE_APP.md:362-379`), body = excerpt + reference; registers categories/actions `LOVE_VERSE`, `SAVE_VERSE`, `DISMISS` per `Instructions/05_IPHONE_APP.md:383-399`; delegate handles action → updates `VerseDelivery.userReaction`.
  - `AppDelegate` — registers BGProcessingTask `com.joelroy.pulse.health-check` (15-min earliest, network required) whose handler runs `HealthEngine.refresh()` → `ScriptureEngine.processStateChange` → reschedules; `UNUserNotificationCenter` delegate wiring.
- App composition in `PulseApp`: build `MetricCollector`/`MockHealthProvider` → `HealthEngine`; build clients from `AppConfig` (when `!AppConfig.isConfigured`, inject `FallbackVerseProvider`-backed stand-ins conforming to the same protocols so the app still runs) → `ScriptureEngine`; connect `healthEngine.onClassification = scriptureEngine.processStateChange`.

- [ ] **Step 1: Implement VerseCache + DeliveryScheduler.**
- [ ] **Step 2: Implement ScriptureEngine** with the full fallback chain.
- [ ] **Step 3: Implement NotificationService + AppDelegate.**
- [ ] **Step 4: Build + simulator run.** Launch with `-PulseMockState stressed_anxious`; debug placeholder shows a verse (from live APIs if keys valid on simulator network, else fallback path) and a local notification arrives. Verify by `xcrun simctl` screenshot and checking the delivery row exists (debug text shows `currentDelivery?.verseReference`).
- [ ] **Step 5: Airplane-mode check** — relaunch with network disabled in simulator (`xcrun simctl status_bar` can't kill network; instead temporarily point AppConfig at a bad host via launch arg `-PulseForceOffline YES` which makes clients throw) → emergency verse still displayed, `isOfflineFallback == true`.
- [ ] **Step 6: Commit** — `git commit -m "feat: ScriptureEngine pipeline with cache, scheduler, notifications, fallback chain"`

---

### Task 11: WatchConnectivity both sides + Watch data store

**Files:**
- Create: `Pulse/Core/Connectivity/PhoneSessionManager.swift`, `PulseWatch/Core/WatchSessionManager.swift`, `PulseWatch/Core/WatchDataStore.swift`, `PulseWatch/App/WatchAppDelegate.swift`
- Modify: `Pulse/App/PulseApp.swift` (activate session, wire ScriptureEngine.onDelivery), `PulseWatch/App/PulseWatchApp.swift` (adaptor + activate)

**Interfaces:**
- Consumes: `WatchMessage` payloads (Task 2), `VerseDelivery` (Task 9), `ScriptureEngine.onDelivery` hook (Task 10).
- Produces:
  - `final class PhoneSessionManager: NSObject, WCSessionDelegate` — singleton; `func activate()`; `func sendVerse(_ delivery: VerseDelivery)` → builds `VerseDeliveryPayload` (primaryColor from `state.primaryColorHex`), `sendMessage` when reachable else `transferUserInfo` (guaranteed delivery per `Instructions/10_DELIVERABLES.md` risk table); `func sendHealthSummary(_ snapshot: HealthSnapshot, state: BiometricState)`; receives `ReactionPayload` → updates the matching `VerseDelivery.userReaction` in SwiftData.
  - `final class WatchSessionManager: NSObject, WCSessionDelegate` (watch) — `@Observable`-published via a small `@Observable final class WatchState { var currentVerse: WatchMessage.VerseDeliveryPayload?; var healthSummary: WatchMessage.HealthSummaryPayload?; var history: [WatchMessage.VerseDeliveryPayload] }`; on receive: update WatchState, persist via WatchDataStore, `WKInterfaceDevice.current().play(.notification)`, `WidgetCenter.shared.reloadAllTimelines()`; `func sendReaction(_ reaction: VerseReaction, deliveryID: String)` with reachable/transferUserInfo fallback.
  - `struct WatchDataStore` — reads/writes a JSON file (`current_verse.json`, `history.json` capped at 20) in `FileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.joelroy.pulse")`, falling back to app documents when nil. This is the **only** channel the widget extension reads. API: `func save(current: WatchMessage.VerseDeliveryPayload)`, `func loadCurrent() -> WatchMessage.VerseDeliveryPayload?`, `func appendHistory(_:) / loadHistory() -> [WatchMessage.VerseDeliveryPayload]`, `func save(summary:)/loadSummary()`.
  - `WatchAppDelegate: NSObject, WKApplicationDelegate` — `handle(_ backgroundTasks:)` per `Instructions/06_WATCH_APP.md:437-476` modernized: `WKApplicationRefreshBackgroundTask` → request latest via session + reschedule 15 min via `WKApplication.shared().scheduleBackgroundRefresh`; snapshot + connectivity task branches as spec'd.
- Verification: both simulators paired (`xcrun simctl list pairs`; create with `xcrun simctl pair` if none), phone app launched with mock state, watch app shows the pushed verse text in a debug Text view.

- [ ] **Step 1: Implement all four files + wiring.**
- [ ] **Step 2: Build both schemes** — success required.
- [ ] **Step 3: Paired-simulator smoke test** — boot paired iPhone+Watch simulators, launch phone app with `-PulseMockState energized_post_workout`, then launch watch app; expected: watch debug view shows "Philippians 4:13" (or live-API-chosen reference). Screenshot both.
- [ ] **Step 4: Commit** — `git commit -m "feat: WatchConnectivity sync, watch data store, watch background tasks"`

---

### Task 12: Watch app UI (VerseView, VitalsView, HistoryView, PrayerView) + complications

**Files:**
- Create: `PulseWatch/Features/MainView.swift`, `Features/VerseView.swift`, `Features/VitalsView.swift`, `Features/HistoryView.swift`, `Features/PrayerView.swift`, `PulseWatch/Core/WatchHealthEngine.swift`
- Modify: `PulseWatch/App/PulseWatchApp.swift` (MainView as root), `PulseWatchWidgets/PulseComplications.swift` (real provider), Create: `PulseWatchWidgets/ComplicationViews.swift`

**Interfaces:**
- Consumes: `WatchState`, `WatchSessionManager`, `WatchDataStore` (Task 11), design tokens + `BiometricState` metadata (Tasks 1/4), `FallbackVerseProvider` (empty-state fill), `MockHealthProvider` fixtures via launch arg on watch too.
- Produces: the four tab views per `Instructions/06_WATCH_APP.md` layouts:
  - `MainView` — `TabView` `.tabViewStyle(.verticalPage)` per `Instructions/06_WATCH_APP.md:50-61`.
  - `VerseView` — state pill (emoji + abbreviation, tinted `state.primaryColor`), serif verse text auto-scaling (use `.minimumScaleFactor(0.6)` + `lineLimit(4)`; `.sheet` full-text on long-press 1.5s), reference right-aligned, action row ♡ (`.success` haptic) / 🔖 (`.click`) / ⬆ (sends `verse_reaction` shared), full-bleed `state.gradient` background with `PulseRing`-style breathing opacity animation (respect `accessibilityReduceMotion`), AOD dimmed variant via `\.isLuminanceReduced` per `Instructions/06_WATCH_APP.md:482-519`, empty state copy per `Instructions/06_WATCH_APP.md:117-127`.
  - `VitalsView` — 3×2 metric grid from `WatchState.healthSummary` (HR, HRV, SpO2, sleep eff, steps + freshness line with the <5min green / 5–15 yellow / >15 red rule); `—` for nil. On-watch refresh via `WatchHealthEngine` (a thin `HealthDataProviding` user: authorization + `fetchSnapshot` subset: heartRate, hrv, spo2, steps — reuses `MetricCollector` code compiled into the watch target? No: **create `WatchHealthEngine` as its own small HKHealthStore wrapper** fetching just those four; watch-local freshness beats waiting for the phone).
  - `HistoryView` — grouped list (Today/Yesterday/Earlier) from `WatchDataStore.loadHistory()`, rows per `Instructions/06_WATCH_APP.md:188-211`; row tap → detail sheet with verse + metrics per `:213-226`.
  - `PrayerView` — Phase-1 version: the four feeling buttons per `Instructions/06_WATCH_APP.md:234-255`; each shows a matching emergency-verse response (Grateful→`deep_rest_recovered` verse, Struggling→`sad_withdrawn`, At Peace→`peaceful_steady`, Need Help→`stressed_anxious`) and sends reaction `.prayed`. Breath prayer button present but shows "Coming soon" footnote — Phase 2.
  - Complications (`PulseComplications.swift` + `ComplicationViews.swift`): `TimelineProvider` reading `WatchDataStore.loadCurrent()`; entry carries payload; families `accessoryRectangular` (state line + 2-line serif excerpt + reference per `Instructions/06_WATCH_APP.md:289-317`), `accessoryCircular` (emoji in `Gauge` tinted state color), `accessoryInline` (`"\(emoji) \(reference)"`), `accessoryCorner` (emoji + state-color gauge). Placeholder variants when no verse yet (`heart.text.square` + "Pulse"). Timeline policy `.never` (reloaded explicitly on delivery).
- Verification: watch simulator screenshots of all four tabs + widget gallery.

- [ ] **Step 1: Implement WatchHealthEngine + the four views + MainView.**
- [ ] **Step 2: Implement complication provider + views.**
- [ ] **Step 3: Build watch scheme; run on watch simulator with a delivered verse; screenshot every tab and at least 3 complication families (add to `docs/screenshots/`).** Long-verse truncation and empty states verified visually.
- [ ] **Step 4: Commit** — `git commit -m "feat: watch app UI and WidgetKit complications"`

---

### Task 13: iOS design-system components

**Files:**
- Create: `Pulse/DesignSystem/Components/PSCard.swift`, `PSButton.swift`, `PulseRing.swift`, `VerseTextView.swift`, `StateChipView.swift`, `MetricTile.swift`

**Interfaces:**
- Consumes: design tokens (Task 4), `BiometricState`, `HealthQuality`.
- Produces: components with the exact signatures in `Instructions/07_UI_DESIGN_SYSTEM.md:272-443` (`PSCard` with 4 styles; `PulseRing(color:bpm:)`; `VerseTextView(text:reference:translation:fontSize:)`; `StateChip(state:showConfidence:confidence:)`; `MetricTile(icon:value:unit:label:quality:action:)`), plus `PSButton(title:style:action:)` — primary = gold `psAccent` capsule with `psDeepNavy` 17pt semibold label, secondary = stroked capsule; min height 50. All animations gated on `accessibilityReduceMotion`.

- [ ] **Step 1: Implement all six files**, each with a `#Preview` block.
- [ ] **Step 2: Build** — success.
- [ ] **Step 3: Commit** — `git commit -m "feat: iOS design-system components"`

---

### Task 14: Onboarding flow + app navigation shell

**Files:**
- Create: `Pulse/Features/Onboarding/OnboardingFlow.swift`, `WelcomeView.swift`, `PermissionsView.swift`, `TranslationPickerView.swift`, `OnboardingCompleteView.swift`, `OnboardingViewModel.swift`, `Pulse/Features/MainTabView.swift`
- Modify: `Pulse/App/PulseApp.swift` (route onboarding vs MainTabView from `UserPreferences.hasCompletedOnboarding`; remove debug placeholder)

**Interfaces:**
- Consumes: PSButton/PSCard/VerseTextView/PulseRing (Task 13), `HealthEngine`, `ScriptureEngine.deliverFirstVerse()`, `NotificationService.requestAuthorization()`, `UserPreferences`, `BibleTranslationID.previewVerse`.
- Produces:
  - `@Observable @MainActor final class OnboardingViewModel` — `var step: Step` (`welcome, permissions, translation, complete`), `var selectedTranslation: BibleTranslationID = .NIV`, `var firstVerse: VerseDelivery?`, `func grantPermissions() async` (HealthKit then notifications, degrade gracefully per `Instructions/05_IPHONE_APP.md:115-117` — denial shows "Some features will be limited" and continues), `func finish() async` (persist prefs, `hasCompletedOnboarding = true`, request first verse).
  - Views per `Instructions/05_IPHONE_APP.md:76-155` layouts: Welcome (gradient bg, logo, tagline serif, 3 feature rows staggered fade-in, "Begin Your Journey →"; particles = Phase 2, use `PulseRing` ambient instead), Permissions (6-row list + Grant Access), TranslationPicker (10 cards, tap previews John 3:16 crossfade, "Continue with NIV →" label updates), Complete (black bg, `PulseRing` gold at 60bpm, 1.5s pause then verse card `psSlideUp` + success haptic, "Open Pulse").
  - `MainTabView` — Today/Journey/Settings tabs per `Instructions/05_IPHONE_APP.md:47-68`, `.tint(Color.psAccent)`, placeholder screens for Home/History/Settings (filled Tasks 15–17).
- Verification: fresh-install simulator run through all 4 steps; first verse appears (mock state + live-or-fallback verse).

- [ ] **Step 1: Implement view model + five views + MainTabView + routing.**
- [ ] **Step 2: Build, erase simulator content, run through onboarding end-to-end, screenshot each step.**
- [ ] **Step 3: Commit** — `git commit -m "feat: onboarding flow with first personalized verse"`

---

### Task 15: HomeView + VerseDetailSheet

**Files:**
- Create: `Pulse/Features/Home/HomeView.swift`, `HomeViewModel.swift`, `CurrentVerseCard.swift`, `StateBannerCard.swift`, `MetricsGridView.swift`, `RecentVersesRow.swift`, `Pulse/Features/Home/VerseDetailSheet.swift`

**Interfaces:**
- Consumes: `HealthEngine.currentClassification/currentSnapshot`, `ScriptureEngine.currentDelivery`, `VerseCache.recentReferences`, SwiftData `VerseDelivery` query, all Task-13 components.
- Produces: HomeView scroll stack per `Instructions/05_IPHONE_APP.md:158-234`: top bar (app name + date), StateBannerCard (state gradient, emoji + name + confidence %, `bodyInterpretation` line, metric chips), CurrentVerseCard (VerseTextView on `.verse` PSCard + Love/Save/Share/Read More actions), MetricsGridView (2×3 MetricTiles: HR, HRV, SpO2, sleep eff, steps, total sleep; HealthQuality color dots; `—` for nil; sparkline = Phase 2, tap is no-op), RecentVersesRow (horizontal last 5 deliveries), streak widget omitted (Phase 2). Pull-to-refresh calls `healthEngine.refresh()`. Loading state: skeleton pulse card (`redacted(reason: .placeholder)` + `psPulse`). VerseDetailSheet per `Instructions/05_IPHONE_APP.md:238-253`: drag handle, small state banner, 22pt serif verse, "Why this verse?" expandable (composed from stored `heartRateAtDelivery`/`hrvAtDelivery`/`sleepEfficiencyAtDelivery` + `glooRationale` when present), Read Full Chapter → `chapterURL` (bible.com) via `openURL`, action row Love/Save/Share (Share → Task 16 sheet). "Related verses" = the 3 `alternates` stored from Gloo when available, else hidden.
- `HomeViewModel` mediates: `var delivery: VerseDelivery?`, `var classification: ClassificationResult?`, `func react(_ reaction: VerseReaction)` (persists + sends to watch).

- [ ] **Step 1: Implement all seven files; wire Home tab.**
- [ ] **Step 2: Build + run with `-PulseMockState exhausted_depleted`; verify banner shows Weary Soul 🌙 with indigo gradient, verse card, metric grid with mock values; screenshot.**
- [ ] **Step 3: Commit** — `git commit -m "feat: HomeView with state banner, verse card, metrics grid, verse detail"`

---

### Task 16: HistoryView + ShareCard

**Files:**
- Create: `Pulse/Features/History/HistoryView.swift`, `HistoryViewModel.swift`, `HistoryRowView.swift`, `HistoryDetailView.swift`, `Pulse/Features/Share/ShareCardView.swift`, `Pulse/Features/Share/ShareCardRenderer.swift`

**Interfaces:**
- Consumes: SwiftData `VerseDelivery` (`@Query` sorted by `deliveredAt` desc), `BiometricState` metadata, design tokens.
- Produces:
  - HistoryView per `Instructions/05_IPHONE_APP.md:257-283`: filter bar (All | Loved | Saved | state menu), sections Today/Yesterday/This Week/Earlier, `HistoryRowView` (emoji, state, time, reference, excerpt, reaction icon), empty state ("Your journey begins with your first verse" + heart icon), row → HistoryDetailView (full verse, state chip, metric chips from stored values, reaction, Share button).
  - ShareCardView per `Instructions/05_IPHONE_APP.md:287-302`, Phase-1 variants **Classic** (psCream bg, dark serif) and **Night** (deep navy, gold accent) in a swipeable `TabView(.page)`; each card 1080×1350pt content: verse, reference · translation, small "Pulse" wordmark bottom-right; toggle for context line ("Delivered during: Weary Soul"). `ShareCardRenderer.render(card:) -> UIImage` using `ImageRenderer` (scale 3), presented via `ShareLink(item: Image(uiImage:)…)`.
- Verification: create 3+ deliveries by relaunching with different mock states; filter, open detail, export a share image to Photos in simulator.

- [ ] **Step 1: Implement history files.**
- [ ] **Step 2: Implement share card + renderer.**
- [ ] **Step 3: Build, generate 3 deliveries via mock relaunches, screenshot History and an exported share card.**
- [ ] **Step 4: Commit** — `git commit -m "feat: history timeline and shareable verse cards"`

---

### Task 17: SettingsView

**Files:**
- Create: `Pulse/Features/Settings/SettingsView.swift`, `SettingsViewModel.swift`, `TranslationSettingsView.swift`, `NotificationSettingsView.swift`, `HealthPermissionsView.swift`, `AboutView.swift`

**Interfaces:**
- Consumes: `UserPreferences` (SwiftData singleton — fetch-or-create helper `UserPreferences.current(in: ModelContext)` added here), `NotificationService`, `PhoneSessionManager` (settings_update push), `BibleTranslationID`.
- Produces: sections per `Instructions/05_IPHONE_APP.md:306-356` (Phase-1 scope): Profile (display name, translation), Notifications (master toggle mirrors system permission state, max/day picker 1·2·3·5·unlimited, quiet hours, emergency override, preview style), Health Metrics (the 9 toggles per doc; toggles gate which fields MetricCollector requests/uses), Scripture (default translation, preferred themes multi-select: the 8 listed themes), Privacy & Data (Clear verse history with confirmation `.destructive` alert → deletes all `VerseDelivery`+`CachedVerse`; privacy explanation text), About (version from bundle, competition credit line "Built for Scripture in New Frontiers — Kaggle", YouVersion + Gloo credits). Every change persists immediately to SwiftData and is honored by DeliveryScheduler (max/day, quiet hours), MetricCollector (metric toggles), ScriptureEngine (translation).
- Verification: change translation → new deliveries fetch in that translation; set max/day to 1 → second delivery blocked (`daily_limit`).

- [ ] **Step 1: Implement all six files; wire Settings tab.**
- [ ] **Step 2: Build + manual verification of the two behaviors above via mock relaunches; screenshot.**
- [ ] **Step 3: Commit** — `git commit -m "feat: settings with translation, notification, health, privacy controls"`

---

### Task 18: End-to-end integration + device deployment

**Files:**
- Modify: whatever the following verification uncovers. No new features.

**Interfaces:** none new — this task proves the existing ones.

- [ ] **Step 1: Full simulator pass.** Paired iPhone+Watch simulators: onboarding → home shows state+verse → notification fires → watch receives verse → complication shows it (add complication to a watch face in simulator) → reaction on watch appears on phone history row → history/share/settings all work. Fix everything that breaks.
- [ ] **Step 2: All package tests green** — `swift test --package-path PulseShared`.
- [ ] **Step 3: Device build.** With Joel present (his iPhone + Watch connected and trusted): `xcodebuild -scheme Pulse -destination 'generic/platform=iOS' build` first, then install to his device via Xcode/`xcrun devicectl`. HealthKit permission sheet appears; real data classifies (no `-PulseMockState`). If the free-vs-paid account blocks an entitlement, drop to what the account supports and record the limitation in README.
- [ ] **Step 4: Acceptance checklist.** Walk `Instructions/10_DELIVERABLES.md:94-131` line by line; record pass/fail in `docs/acceptance-phase1.md`; fix fails before proceeding.
- [ ] **Step 5: Kaggle rules check** — WebFetch https://www.kaggle.com/competitions/scripture-in-new-frontiers, confirm compliance (API usage, originality, submission format), note deadlines in `docs/acceptance-phase1.md`.
- [ ] **Step 6: Commit** — `git commit -m "chore: end-to-end integration fixes and acceptance verification"`

---

### Task 19: Judge-facing docs

**Files:**
- Create: `README.md`, `SUBMISSION.md`

**Interfaces:** consumes everything; produces the doc-10 deliverables.

- [ ] **Step 1: Write README.md** — prerequisites (Xcode 26+, brew, xcodegen), setup (`./Scripts/bootstrap.sh`, where to get Gloo/YouVersion keys and where to paste them), build/run commands for simulator and device, mock-state launch arguments for demoing all 12 states, known limitations (from Task 18), project structure map.
- [ ] **Step 2: Write SUBMISSION.md** — all sections per `Instructions/10_DELIVERABLES.md:72-82`: problem statement, solution, exact YouVersion endpoints used, Gloo prompt + usage, architecture overview (reuse design-doc diagramless summary), privacy approach, screenshots links (`docs/screenshots/`), roadmap (= Phase 2 list).
- [ ] **Step 3: Commit** — `git commit -m "docs: README build instructions and SUBMISSION narrative"`

---

## Phase 2 backlog (separate plan after Phase 1 ships)

Live Activities, breath prayer with haptic rhythm, streak tracking, 7-day sparklines, remaining 3 share-card variants, extra complication polish, onboarding particle effect, Verse of the Day bonus delivery, Localizable.strings extraction, app icon + image assets.

## Self-review notes

- Spec coverage: every doc-10 Phase-1 acceptance item maps to a task (health engine 5/9/18, scripture engine 8/10/18, watch 11/12, iPhone 14–17, privacy enforced in 8's no-raw-numbers test + 17's clear-history).
- Deferred by explicit decision (recorded in design doc / Phase 2): streaks, sparklines, Live Activities, breath prayer, 3 share variants, localization, app icon art.
- Type consistency: `WatchMessage.VerseDeliveryPayload` field list fixed in Task 2 and reused 11/12; `HealthDataProviding` fixed in Task 9, reused 12 (WatchHealthEngine is deliberately its own type, not a conformer); `VerseSelecting/VerseFetching` fixed in Task 8, consumed in 10.
