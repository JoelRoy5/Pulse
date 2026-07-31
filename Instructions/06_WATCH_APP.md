# 06 — Apple Watch App

## Overview

The Apple Watch app is the primary delivery surface for Pulse. It sits on the user's wrist — literally touching their pulse — making it the most intimate and contextually appropriate place to receive scripture. The Watch app is designed for ultra-fast glance interactions (2–5 seconds), with deeper engagement available for those who want it.

---

## watchOS Target Requirements

- **Minimum:** watchOS 10.0
- **Target:** watchOS 11.0+
- **Watch Sizes:** 41mm, 45mm, 49mm (Ultra)
- **Always-On Display:** Dimmed complication supported
- **Independent from iPhone:** No — companion app required for initial setup; operates independently after

---

## Watch App Screen Inventory

| View | Description |
|------|-------------|
| `MainView` | Root tab container |
| `VerseView` | Current verse — primary view |
| `VitalsView` | Live health metrics at a glance |
| `HistoryView` | Recent verse list |
| `PrayerView` | Simple prayer/response interaction |
| `ComplicationView` | Watch face complication (all families) |

---

## Watch App Navigation

The Watch app uses `TabView` with `.tabViewStyle(.verticalPage)` for natural vertical swipe navigation:

```swift
// PulseWatchApp.swift
@main
struct PulseWatchApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}

// MainView.swift
struct MainView: View {
    var body: some View {
        TabView {
            VerseView()
            VitalsView()
            HistoryView()
            PrayerView()
        }
        .tabViewStyle(.verticalPage)
    }
}
```

---

## 1. VerseView (Primary View — Tab 1)

**Purpose:** Display the current verse with state context. Ultra-readable, instantly comforting.

**Layout (45mm watch, full screen):**

```
┌───────────────────────────┐
│  🌊 WEARY SOUL            │  ← State badge (small, top)
│                           │
│                           │
│  "Come to me,             │
│   all you who are         │  ← Verse text (dynamic type,
│   weary and               │    fills ~60% of screen)
│   burdened..."            │
│                           │
│         Matthew 11:28     │  ← Reference (small, right-aligned)
│                           │
│  [♡]    [🔖]    [⬆]      │  ← Action buttons (bottom row)
└───────────────────────────┘
```

**Verse Text Rules:**
- Font: New York (Apple's built-in serif) or custom bundled serif font
- Size: Dynamically scales to fit verse within 4 lines. If > 4 lines, shows abbreviated with "... [hold to expand]"
- Long verses: Double tap to enter full-text scroll mode
- Color: Always white text on dark/colored background for max legibility

**State Badge:**
- Small pill at top with state emoji + abbreviated name
- Background tint matches state color
- Example: `🌊 WEARY SOUL` on blue-gray background

**Background:**
- Full-bleed gradient unique to each state (see Design System)
- Subtle animated ambient effect (slow breathing animation, pulse rhythm)
- The background literally "breathes" at the pace of a resting heart rate

**Action Buttons (Digital Crown scroll reveals if needed):**
- ♡ Love — saves with loved reaction, heart fill animation + haptic
- 🔖 Save — saves to collection, bookmark fill animation
- ⬆ Share — shares to iPhone (WCSession → iOS share sheet)
- Pressing any action: medium haptic feedback

**Interactions:**
- **Single tap anywhere** → does nothing (prevents accidental activation)
- **Digital Crown press** → returns to watch face
- **Hold on verse text (1.5s)** → full-screen text-only mode for long verses
- **Swipe left** → next tab (VitalsView)
- **Crown rotate up** → scrolls if verse is long

**Empty State (no verse yet):**
```
┌───────────────────────────┐
│                           │
│         ❤️               │
│                           │
│   Gathering your          │
│   health data...          │
│                           │
│   Check back in           │
│   a few minutes           │
└───────────────────────────┘
```

---

## 2. VitalsView (Tab 2)

**Purpose:** Live biometric dashboard. Let users see the data that's informing their verse.

**Layout:**
```
┌───────────────────────────┐
│  YOUR VITALS              │  ← Section header
│                           │
│  ♥  72    📊  48ms        │
│  Heart Rate  HRV          │  ← Row 1
│                           │
│  🫁  97%   🌙  81%        │
│  Oxygen    Sleep Eff.     │  ← Row 2
│                           │
│  🏃  4,234  💤  7h 20m    │
│  Steps     Total Sleep    │  ← Row 3
│                           │
│  Updated 4 min ago        │  ← Freshness indicator
└───────────────────────────┘
```

**Design Details:**
- Each metric tile: large value in bold, icon + label below in muted gray
- Color coding: green/yellow/red indicator dot next to each value
- Tapping a tile shows a 24-hour sparkline for that metric (sheet overlay)
- "Updated X min ago" changes color: < 5min = green, 5–15min = yellow, > 15min = red
- If a metric is unavailable: shows "—" with a soft gray dot

**Sparkline Sheet (tap any metric):**
```
┌───────────────────────────┐
│  Heart Rate  ←            │
│                           │
│  72 bpm                   │
│  avg today                │
│                           │
│  ╭─────────────╮          │
│  │   ∧  ∧     │          │
│  │ ∧∨  ∨ ∧∨   │          │  ← 24h sparkline
│  │             │          │
│  ╰─────────────╯          │
│  12am        now          │
│                           │
│  Low: 54  High: 143       │
└───────────────────────────┘
```

---

## 3. HistoryView (Tab 3)

**Purpose:** Recent verse timeline. "Remember what God said when..."

**Layout:**
```
┌───────────────────────────┐
│  RECENT VERSES            │
│                           │
│  ─── Today ───            │
│                           │
│  🌊 Weary Soul  8:14am   │
│  Matthew 11:28  ♡         │
│                           │
│  ─── Yesterday ───        │
│                           │
│  🏆 Victory Lap 6:48pm   │
│  Phil 4:13                │
│                           │
│  🌅 New Mercies 7:02am   │
│  Psalm 118:24   🔖        │
└───────────────────────────┘
```

**Row Details:**
- State emoji + state name + time
- Verse reference
- Reaction icon (♡ loved, 🔖 saved, or nothing)
- Swipe left on row → mark as loved / save / delete

**Tapping a row → Verse detail sheet:**
```
┌───────────────────────────┐
│  🌊 Weary Soul  ←         │
│  Jul 29, 8:14am           │
│                           │
│  "Come to me, all you     │
│   who are weary..."       │
│                           │
│  Matthew 11:28 · NIV      │
│                           │
│  ♥ 58bpm  HRV 31ms        │
│  Sleep: 68%               │
└───────────────────────────┘
```

---

## 4. PrayerView (Tab 4)

**Purpose:** Simple, intimate prayer interaction. Respond to the verse with your heart.

**Layout:**
```
┌───────────────────────────┐
│                           │
│         🙏               │
│                           │
│   How are you feeling     │
│   right now?              │
│                           │
│  [Grateful]  [Struggling] │
│  [At Peace]  [Need Help]  │
│                           │
│  Or just breathe with God │
│  [Begin Breath Prayer]    │
└───────────────────────────┘
```

**Prayer States:**
- **Grateful** → shows a verse of thanksgiving + suggested 30-second prayer
- **Struggling** → shows a verse of comfort + guided lament prayer prompt
- **At Peace** → shows an abiding/praise verse
- **Need Help** → shows a verse of intercession + encouragement

**Breath Prayer Feature:**
- "Begin Breath Prayer" launches a guided breathing exercise
- Uses WatchKit's WKInterfaceHapticFeedbackType for rhythm
- On inhale: "Lord Jesus Christ" text fades in
- On exhale: "have mercy on me" text fades in
- 5 breath cycles (2 min), then shows a final verse
- Optionally logs a mindful session to HealthKit

---

## Watch Complications

Pulse provides complications for all major watch face families.

### Complication Families Supported

| Family | Size | Content |
|--------|------|---------|
| `.accessoryCircular` | Small circle | State emoji + state abbreviation |
| `.accessoryRectangular` | Wide rectangle | Verse excerpt + reference |
| `.accessoryInline` | Single line | Reference + state name |
| `.accessoryCorner` | Corner gauge | Heart rate + state color gauge |
| `.graphicCircular` | Rich circle | Animated state ring |
| `.graphicBezel` | Round bezel | Verse excerpt in bezel text |
| `.graphicCorner` | Corner | Gauge of recovery score |
| `.graphicRectangular` | Large rect | Full verse excerpt 2 lines |
| `.graphicExtraLarge` | Full face | Verse + state + metrics |

### Complication Views (SwiftUI / ClockKit)

#### `.accessoryRectangular` — Most Important
```swift
struct RectangularComplicationView: View {
    let delivery: VerseDelivery?
    
    var body: some View {
        if let delivery {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(delivery.biometricState.emoji)
                        .font(.system(size: 10))
                    Text(delivery.biometricState.abbreviation.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(delivery.verseExcerpt)  // first ~50 chars
                    .font(.system(size: 12, design: .serif))
                    .lineLimit(2)
                Text(delivery.verseReference)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack {
                Image(systemName: "heart.text.square")
                Text("Pulse")
                    .font(.caption2)
            }
        }
    }
}
```

#### `.accessoryCircular` — State Ring
```swift
struct CircularComplicationView: View {
    let state: BiometricState?
    
    var body: some View {
        ZStack {
            // Gauge ring showing recovery score
            Gauge(value: recoveryScore, in: 0...1) {
                Text(state?.emoji ?? "❤️")
                    .font(.system(size: 14))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(state?.color ?? .red)
        }
    }
}
```

#### `.graphicExtraLarge` — Full Face Complication (Ultra / Large)
```swift
struct ExtraLargeComplicationView: View {
    let delivery: VerseDelivery?
    
    var body: some View {
        VStack(spacing: 8) {
            if let delivery {
                // State indicator
                HStack {
                    Text(delivery.biometricState.emoji)
                    Text(delivery.biometricState.displayName.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .kerning(1)
                }
                .foregroundStyle(delivery.biometricState.color)
                
                // Verse text (large, serif)
                Text(delivery.verseExcerpt)
                    .font(.system(size: 15, design: .serif))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                
                // Reference
                Text(delivery.verseReference)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
    }
}
```

### ComplicationController (CLKComplicationDataSource)

```swift
class ComplicationController: NSObject, CLKComplicationDataSource {
    
    func getTimelineEntries(
        for complication: CLKComplication,
        after date: Date,
        limit: Int,
        withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void
    ) {
        // Provide future timeline entries for cached/scheduled verses
        // Apple Watch prefetches complications in advance
        let entries = buildTimelineEntries(for: complication, limit: limit)
        handler(entries)
    }
    
    func getCurrentTimelineEntry(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void
    ) {
        guard let delivery = WatchDataStore.shared.currentDelivery else {
            handler(nil)
            return
        }
        let entry = makeEntry(for: complication, delivery: delivery, date: .now)
        handler(entry)
    }
    
    func getPrivacyBehavior(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void
    ) {
        // Show verse on watch face; no sensitive health data shown in complication
        handler(.showOnLockScreen)
    }
}
```

---

## Haptic Feedback Design

Haptics are central to the Watch experience — they create a physical connection between the user's body and the Word.

| Event | Haptic Type | Description |
|-------|------------|-------------|
| New verse received | `.notification` | Standard alert feel |
| Love reaction | `.success` | Satisfying success pulse |
| Save reaction | `.click` | Clean confirmation click |
| Breath Prayer inhale | `.directionUp` | Gentle upward cue |
| Breath Prayer exhale | `.directionDown` | Gentle downward cue |
| Verse of the Day (morning) | `.start` | Energizing morning wake |
| Stressed/Sad verse arrives | `.retry` | Gentle, compassionate |
| Workout detected | `.start` | Energy start pulse |

---

## Background Tasks (watchOS)

```swift
// WatchAppDelegate.swift
class AppDelegate: NSObject, WKApplicationDelegate {
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let refreshTask as WKApplicationRefreshBackgroundTask:
                Task {
                    await WatchHealthEngine.shared.refreshMetrics()
                    await WatchSessionManager.shared.requestLatestVerse()
                    scheduleNextRefresh()
                    refreshTask.setTaskCompletedWithSnapshot(false)
                }
                
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Update complication snapshot
                WidgetCenter.shared.reloadAllTimelines()
                snapshotTask.setTaskCompleted(
                    restoredDefaultState: true,
                    estimatedSnapshotExpiration: Date(timeIntervalSinceNow: 3600),
                    userInfo: nil
                )
                
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Handle incoming message from phone
                WatchSessionManager.shared.handleBackgroundConnectivity()
                connectivityTask.setTaskCompletedWithSnapshot(false)
                
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
    
    private func scheduleNextRefresh() {
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date(timeIntervalSinceNow: 15 * 60),
            userInfo: nil,
            scheduledCompletion: { _ in }
        )
    }
}
```

---

## Always-On Display

When Always-On Display is enabled, the VerseView shows a dimmed version:

```swift
struct VerseView: View {
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    
    var body: some View {
        ZStack {
            if isLuminanceReduced {
                // AOD mode: black background, essential info only
                AODVerseView(delivery: currentDelivery)
            } else {
                // Full view
                FullVerseView(delivery: currentDelivery)
            }
        }
    }
}

struct AODVerseView: View {
    let delivery: VerseDelivery?
    
    var body: some View {
        VStack {
            Text(delivery?.biometricState.emoji ?? "❤️")
                .font(.system(size: 20))
            Text(delivery?.verseExcerpt(maxChars: 30) ?? "")
                .font(.system(size: 11, design: .serif))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            Text(delivery?.verseReference ?? "")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.3))
        }
        .background(Color.black)
    }
}
```

---

## WatchConnectivity — Watch Side

```swift
// WatchSessionManager.swift
class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()
    
    @Published var currentDelivery: VerseDelivery?
    @Published var healthSummary: WatchHealthSummary?
    
    private let session = WCSession.default
    
    func activate() {
        session.delegate = self
        session.activate()
    }
    
    func session(_ session: WCSession, 
                 didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        
        switch type {
        case "verse_delivery":
            let delivery = VerseDelivery.fromWatchMessage(message)
            DispatchQueue.main.async {
                self.currentDelivery = delivery
                WKInterfaceDevice.current().play(.notification)
                // Update complication
                CLKComplicationServer.sharedInstance()
                    .reloadTimeline(for: allComplications)
            }
            
        case "health_summary":
            let summary = WatchHealthSummary.fromMessage(message)
            DispatchQueue.main.async {
                self.healthSummary = summary
            }
        }
    }
    
    func sendReaction(_ reaction: VerseReaction, deliveryID: UUID) {
        let message: [String: Any] = [
            "type": "verse_reaction",
            "reaction": reaction.rawValue,
            "delivery_id": deliveryID.uuidString,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
    }
}
```
