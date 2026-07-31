# 02 — Technical Architecture

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER'S APPLE WATCH                          │
│                                                                     │
│  ┌─────────────────┐    ┌─────────────────┐    ┌────────────────┐  │
│  │   HealthKit     │    │   WatchKit UI   │    │  Complications │  │
│  │   Sensors       │───▶│   (SwiftUI)     │    │  (CLKCompl.)   │  │
│  │  Live Metrics   │    │                 │    │                │  │
│  └────────┬────────┘    └────────┬────────┘    └───────┬────────┘  │
│           │                     │                      │           │
│           └──────────────────┬──┘                      │           │
│                              │                         │           │
│              ┌───────────────▼────────────────┐        │           │
│              │     HealthEngine (watchOS)      │        │           │
│              │  - Background Task Refresh      │        │           │
│              │  - Metric Aggregation           │        │           │
│              │  - State Pre-Scoring            │        │           │
│              └───────────────┬────────────────┘        │           │
└──────────────────────────────┼─────────────────────────┼───────────┘
                               │ WatchConnectivity        │
                    (WCSession bidirectional sync)         │
┌──────────────────────────────┼─────────────────────────┼───────────┐
│                         USER'S iPHONE                   │           │
│                              │                         │           │
│  ┌───────────────────────────▼──────────────────────┐  │           │
│  │                  HealthEngine (iOS)               │  │           │
│  │  - HKObserverQuery (background delivery)         │  │           │
│  │  - HKAnchoredObjectQuery (incremental updates)   │  │           │
│  │  - HKStatisticsCollectionQuery (time windows)    │  │           │
│  │  - BiometricStateClassifier                      │  │           │
│  │  - StateHistory (SwiftData)                      │  │           │
│  └───────────────────────┬───────────────────────────┘  │           │
│                          │                              │           │
│  ┌───────────────────────▼───────────────────────────┐  │           │
│  │              ScriptureEngine (iOS)                │  │           │
│  │  - GlooAIClient (REST + async/await)              │  │           │
│  │  - YouVersionClient (REST + async/await)           │  │           │
│  │  - VerseCache (SwiftData)                         │  │           │
│  │  - DeliveryScheduler                             │  │           │
│  └───────────────────────┬───────────────────────────┘  │           │
│                          │                              │           │
│  ┌───────────────────────▼───────────────────────────┐  │           │
│  │            Notification Layer (iOS)               │  │           │
│  │  - UNUserNotificationCenter                      │  │           │
│  │  - WatchKit Push (via WCSession)                  │  │           │
│  │  - Rich notification with verse + reference       │  │           │
│  └───────────────────────┬───────────────────────────┘  │           │
│                          │                              │           │
│  ┌───────────────────────▼───────────────────────────┐  │           │
│  │              SwiftUI App (iOS)                    │  │           │
│  │  - HomeView, HistoryView, SettingsView            │  │           │
│  │  - VerseDetailView, ShareView                     │  │           │
│  │  - OnboardingFlow                                 │  │           │
│  └───────────────────────────────────────────────────┘  │           │
└─────────────────────────────────────────────────────────────────────┘
                               │
              ┌────────────────▼────────────────┐
              │          EXTERNAL APIs           │
              │                                  │
              │  ┌──────────────────────────┐   │
              │  │   Gloo AI Studio API      │   │
              │  │   POST /api/v1/prompt     │   │
              │  │   Input: state context    │   │
              │  │   Output: verse refs      │   │
              │  └──────────────────────────┘   │
              │                                  │
              │  ┌──────────────────────────┐   │
              │  │  YouVersion Platform API  │   │
              │  │  GET /bible/verse         │   │
              │  │  GET /bible/votd          │   │
              │  │  Input: verse reference   │   │
              │  │  Output: verse text+meta  │   │
              │  └──────────────────────────┘   │
              └──────────────────────────────────┘
```

---

## Xcode Project Structure

```
Pulse/
├── Pulse.xcodeproj
├── Pulse/                          # iOS App Target
│   ├── App/
│   │   ├── PulseApp.swift          # @main entry point
│   │   └── AppDelegate.swift            # Background task registration
│   ├── Core/
│   │   ├── Models/                      # Data models (shared)
│   │   │   ├── BiometricState.swift
│   │   │   ├── VerseDelivery.swift
│   │   │   ├── HealthSnapshot.swift
│   │   │   └── UserPreferences.swift
│   │   ├── Health/
│   │   │   ├── HealthEngine.swift       # Main HealthKit coordinator
│   │   │   ├── MetricCollector.swift    # Individual metric queries
│   │   │   ├── StateClassifier.swift    # Biometric → State logic
│   │   │   └── SleepAnalyzer.swift      # Sleep stage parsing
│   │   ├── Scripture/
│   │   │   ├── ScriptureEngine.swift    # Orchestrator
│   │   │   ├── GlooAIClient.swift       # Gloo API client
│   │   │   ├── YouVersionClient.swift   # YouVersion API client
│   │   │   ├── VerseCache.swift         # SwiftData persistence
│   │   │   └── DeliveryScheduler.swift  # When/how to deliver
│   │   ├── Persistence/
│   │   │   ├── PulseSchema.swift   # SwiftData schema
│   │   │   └── ModelContainer+Setup.swift
│   │   └── Connectivity/
│   │       └── PhoneSessionManager.swift # WCSession (phone side)
│   ├── Features/
│   │   ├── Onboarding/
│   │   │   ├── OnboardingFlow.swift
│   │   │   ├── WelcomeView.swift
│   │   │   ├── PermissionsView.swift
│   │   │   ├── TranslationPickerView.swift
│   │   │   └── OnboardingViewModel.swift
│   │   ├── Home/
│   │   │   ├── HomeView.swift
│   │   │   ├── CurrentVerseCard.swift
│   │   │   ├── StateRingView.swift
│   │   │   ├── MetricsGridView.swift
│   │   │   └── HomeViewModel.swift
│   │   ├── History/
│   │   │   ├── HistoryView.swift
│   │   │   ├── HistoryRowView.swift
│   │   │   ├── VerseDetailView.swift
│   │   │   └── HistoryViewModel.swift
│   │   ├── Share/
│   │   │   ├── ShareCardView.swift
│   │   │   └── ShareCardRenderer.swift
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       ├── TranslationSettingsView.swift
│   │       ├── NotificationSettingsView.swift
│   │       ├── HealthPermissionsView.swift
│   │       └── SettingsViewModel.swift
│   ├── DesignSystem/
│   │   ├── Colors.swift
│   │   ├── Typography.swift
│   │   ├── Animations.swift
│   │   ├── Gradients.swift
│   │   └── Components/
│   │       ├── PSButton.swift
│   │       ├── PSCard.swift
│   │       ├── PulseRing.swift
│   │       ├── VerseTextView.swift
│   │       └── StateChipView.swift
│   ├── Notifications/
│   │   ├── NotificationService.swift
│   │   └── NotificationContent.swift
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Pulse.entitlements
│       └── Info.plist
│
├── PulseWatch/                     # watchOS App Target
│   ├── App/
│   │   └── PulseWatchApp.swift
│   ├── Core/
│   │   ├── WatchHealthEngine.swift      # watchOS HealthKit
│   │   └── WatchSessionManager.swift   # WCSession (watch side)
│   ├── Features/
│   │   ├── MainView.swift               # Tab root
│   │   ├── VerseView.swift              # Current verse full-screen
│   │   ├── VitalsView.swift             # Live metrics view
│   │   ├── HistoryView.swift            # Recent verses
│   │   └── PrayerView.swift             # Tap-to-pray interaction
│   ├── Complications/
│   │   ├── VerseComplication.swift      # CLKComplicationDataSource
│   │   ├── ComplicationViews.swift      # SwiftUI complication views
│   │   └── ComplicationController.swift
│   └── Resources/
│       ├── Assets.xcassets
│       └── Info.plist
│
└── PulseShared/                    # Shared Framework Target
    ├── Models/
    │   ├── BiometricState.swift
    │   ├── VerseDelivery.swift
    │   ├── HealthSnapshot.swift
    │   └── WatchMessage.swift
    └── Extensions/
        ├── Color+Pulse.swift
        └── Date+Helpers.swift
```

---

## Data Flow: Complete Verse Delivery Cycle

```
1. HEALTH OBSERVATION (Background / Every 15 min)
   HKObserverQuery fires →
   MetricCollector.fetchLatestSnapshot() →
   Returns: HealthSnapshot {
     heartRate: Double,
     hrv: Double,
     restingHR: Double,
     respiratoryRate: Double,
     oxygenSaturation: Double,
     sleepEfficiency: Double,
     deepSleepMinutes: Double,
     remMinutes: Double,
     lateNightWakeMinutes: Double,
     activeEnergyBurned: Double,
     stepCount: Int,
     vo2Max: Double,
     mindfulMinutes: Double,
     timestamp: Date
   }

2. STATE CLASSIFICATION
   StateClassifier.classify(snapshot: HealthSnapshot) →
   Returns: BiometricState (enum case + confidence: Double)
   
   Algorithm:
   - Compute 8 sub-scores (0.0–1.0 each)
   - Apply weighted formula per state
   - Select highest-confidence state above 0.65 threshold
   - If no state > 0.65, use time-of-day fallback

3. DELIVERY DECISION
   DeliveryScheduler.shouldDeliver(state, history) →
   Checks:
   - Was a verse delivered for this state in last N hours? (cooldown)
   - Is this a significant state change from last delivery?
   - Is it an appropriate time (not 3am unless night-wake state)?
   - Has user exceeded max daily deliveries (user-configurable, default 5)?

4. GLOO AI CALL (if delivery approved)
   GlooAIClient.selectVerse(context: BiometricContext) →
   Sends: {
     "state": "exhausted_depleted",
     "time_of_day": "morning",
     "state_confidence": 0.87,
     "recent_states": ["stressed_anxious", "poor_sleep"],
     "preferred_theme": null,
     "translation": "NIV"
   }
   Returns: {
     "verse_reference": "Matthew 11:28",
     "book": "Matthew",
     "chapter": 11,
     "verse": 28,
     "rationale": "User is exhausted; Jesus's invitation to rest is directly relevant",
     "theme": "rest_renewal"
   }

5. YOUVERSION FETCH
   YouVersionClient.fetchVerse(reference, translation) →
   Returns: {
     "text": "Come to me, all you who are weary...",
     "reference": "Matthew 11:28",
     "translation": "NIV",
     "copyright": "..."
   }

6. DELIVERY
   NotificationService.deliver(verse, state, device) →
   - iPhone: Rich UNNotification with verse text, reference, state name
   - Watch: WCSession message → WatchKit notification OR complication update
   - In-app: Persisted to SwiftData, HomeView updates

7. PERSISTENCE
   VerseDelivery saved to SwiftData with:
   - Full verse text + reference
   - BiometricState at time of delivery
   - HealthSnapshot at time of delivery
   - User reaction (liked/saved/dismissed)
   - Timestamp
```

---

## Background Execution Strategy

### iOS Background Tasks
```swift
// Register in AppDelegate
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.pulse.health-check",
    using: nil
) { task in
    self.handleHealthCheckTask(task as! BGProcessingTask)
}

// Schedule next refresh
let request = BGProcessingTaskRequest(
    identifier: "com.pulse.health-check"
)
request.requiresNetworkConnectivity = true
request.requiresExternalPower = false
request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 min
```

### watchOS Background Refresh
```swift
// WKExtension background task
WKExtension.shared().scheduleBackgroundRefresh(
    withPreferredDate: Date(timeIntervalSinceNow: 15 * 60),
    userInfo: nil
) { error in ... }
```

### HKObserverQuery (Always-On)
HealthKit observer queries run even when app is terminated, waking the app in background to process new samples.

---

## API Configuration

All API keys are stored in **Xcode's build configuration** (never hardcoded):

```
// Debug.xcconfig
GLOO_API_KEY = your_gloo_key_here
YOUVERSION_API_KEY = your_youversion_key_here
YOUVERSION_BASE_URL = https://api.youversion.com/v1

// Info.plist entries
GlooAPIKey = $(GLOO_API_KEY)
YouVersionAPIKey = $(YOUVERSION_API_KEY)
YouVersionBaseURL = $(YOUVERSION_BASE_URL)
```

Retrieved at runtime:
```swift
Bundle.main.object(forInfoDictionaryKey: "GlooAPIKey") as! String
```

---

## WatchConnectivity Protocol

Messages passed between Watch and Phone via WCSession:

```swift
// Phone → Watch: new verse delivery
{
  "type": "verse_delivery",
  "verse_text": "Come to me...",
  "reference": "Matthew 11:28",
  "state": "exhausted_depleted",
  "state_display_name": "Weary Soul",
  "timestamp": 1234567890.0
}

// Watch → Phone: user reaction
{
  "type": "verse_reaction",
  "reaction": "loved",  // loved | saved | dismissed
  "delivery_id": "uuid-string",
  "timestamp": 1234567890.0
}

// Phone → Watch: health snapshot summary
{
  "type": "health_summary",
  "heart_rate": 72.0,
  "hrv": 48.5,
  "state": "peaceful_steady",
  "last_updated": 1234567890.0
}
```
