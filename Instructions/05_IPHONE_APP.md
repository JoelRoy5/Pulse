# 05 — iPhone App

## Overview

The iPhone app is the primary configuration, history, and deep-engagement surface of Pulse. It handles onboarding, displays the current verse with health context, maintains a rich history of verse deliveries, and provides full settings control.

---

## Screen Inventory

| Screen | Route/Navigation | Description |
|--------|-----------------|-------------|
| Splash / Launch | App start | Animated launch screen |
| Onboarding — Welcome | `OnboardingFlow` step 1 | Brand intro + value prop |
| Onboarding — Permissions | `OnboardingFlow` step 2 | HealthKit + Notifications |
| Onboarding — Translation | `OnboardingFlow` step 3 | Preferred Bible version |
| Onboarding — Complete | `OnboardingFlow` step 4 | First verse reveal |
| Home | `.tab(.home)` | Current state + verse card |
| Verse Detail | Sheet over Home | Full verse with context |
| History | `.tab(.history)` | Timeline of past deliveries |
| History Detail | Push from History | Single delivery with full health data |
| Share Card | Sheet from Verse | Beautiful shareable card |
| Settings | `.tab(.settings)` | All app preferences |
| Settings › Translation | Push | Choose Bible version |
| Settings › Notifications | Push | Timing + frequency |
| Settings › Health | Push | Which metrics to use |
| Settings › About | Push | Credits, licenses, competition info |

---

## Navigation Structure

```swift
@main
struct PulseApp: App {
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    
    enum Tab { case home, history, settings }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Today", systemImage: "heart.fill") }
                .tag(Tab.home)
            
            HistoryView()
                .tabItem { Label("Journey", systemImage: "book.closed.fill") }
                .tag(Tab.history)
            
            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(Tab.settings)
        }
        .tint(Color.psAccent)
    }
}
```

---

## 1. Onboarding Flow

### WelcomeView
**Purpose:** First impression. Establish emotional resonance.

**Layout:**
- Full-screen dark gradient background (deep navy → rich purple)
- Animated floating particles made of tiny heart-and-cross icons
- Center: Pulse logo (heartbeat line morphing into cross)
- Tagline: *"Scripture that meets you where you are"* in large elegant serif
- Below tagline: 3 short feature rows with icons:
  - ♥ "Reads your heartbeat"
  - 🌙 "Watches while you sleep"
  - 📖 "Speaks God's Word when you need it"
- Bottom: Large primary button "Begin Your Journey →"
- Subtle "Already have an account? Sign in" link (future feature placeholder)

**Animations:**
- Particles drift upward and fade out, regenerating from bottom
- Logo draws itself on first appear (stroke animation)
- Feature rows stagger in with fade+slide from left

### PermissionsView
**Purpose:** Request HealthKit and Notification permissions with clear, warm explanation.

**Layout:**
- Title: "Let Pulse listen to your body"
- Subtitle: "To deliver the right verse at the right time, we need to read your health data. This data stays on your device — always."
- List of 6 permission items with icons and brief descriptions:
  ```
  ❤️  Heart Rate            "Detect stress and exercise"
  📊  Heart Rate Variability "Measure recovery and tension"
  🌙  Sleep Analysis         "Understand your rest"
  🫁  Blood Oxygen           "Monitor vitality levels"
  🏃  Activity & Exercise    "Celebrate your movement"
  🔔  Notifications          "Receive verses at the right moment"
  ```
- Bottom: "Grant Access" button → triggers `requestAuthorization()`
- Tap "Grant Access" → iOS permission dialogs appear in sequence
- After approval: "All set! Your body is ready to speak." + checkmark animation
- Privacy policy link at bottom: "Your privacy is sacred. Read our commitment →"

**Edge Cases:**
- If user denies HealthKit: show "Some features will be limited" + continue option
- If user denies all: gracefully degrade to Verse of the Day mode

### TranslationPickerView
**Purpose:** Select preferred Bible translation — make it feel like a personal choice, not a form.

**Layout:**
- Title: "Which translation speaks to your heart?"
- Subtitle: "You can always change this later."
- Scrollable list of translations in stylized cards:

  ```
  ┌────────────────────────────────────────┐
  │  NIV  New International Version        │
  │  "For God so loved the world..." ✓     │ ← selected
  └────────────────────────────────────────┘
  ┌────────────────────────────────────────┐
  │  ESV  English Standard Version         │
  │  "For God so loved the world..."       │
  └────────────────────────────────────────┘
  ```
  
- 10 translations available: NIV, ESV, NLT, KJV, CSB, NASB 2020, MSG, AMP, NKJV, NCV
- Tapping a card previews John 3:16 in that translation with smooth text crossfade
- "Continue with [TRANSLATION] →" button updates as user selects

### OnboardingCompleteView
**Purpose:** Reveal the first personalized verse. Emotional payoff.

**Layout:**
- Black background with slowly pulsing golden ring (like a heartbeat rhythm)
- "Your first verse, chosen just for you"
- After 1.5 second pause: verse card slides up from bottom with spring animation
  - Shows current biometric state name
  - Full verse text
  - Reference
- "This is just the beginning" text fades in below
- Single button: "Open Pulse"
- Haptic: gentle success haptic on verse card appear

---

## 2. HomeView

**Purpose:** The daily hub. Shows current state, current verse, live health preview.

**Layout (Scroll View, all cards stack vertically):**

### Top Bar
```
Pulse                    [Profile avatar / streak badge]
Thursday, July 31
```

### State Banner Card
```
┌─────────────────────────────────────────────────────┐
│                                                     │
│   🌊  WEARY SOUL                          87% match │
│   Your body is asking for rest                      │
│                                                     │
│   ┄ ♥ 58 bpm  ┄ HRV 31ms  ┄ Sleep 68%  ┄         │
│                                                     │
└─────────────────────────────────────────────────────┘
```
- Full-width card with state-specific gradient background
- State emoji + all-caps state name + confidence percentage
- One-line interpretation of the state
- Scrolling metric chips at bottom (heart rate, HRV, sleep quality)
- Background gradient: each state has its own palette (see Design System)

### Verse Card (Hero Element)
```
┌─────────────────────────────────────────────────────┐
│                                                     │
│  "Come to me, all you who are weary               │
│   and burdened, and I will give you rest."          │
│                                                     │
│                          Matthew 11:28 · NIV        │
│                                                     │
│  [♡ Love]  [🔖 Save]  [⬆ Share]  [📖 Read More]  │
└─────────────────────────────────────────────────────┘
```
- Large serif font for verse text (minimum 20pt)
- Right-aligned reference
- 4 action buttons at bottom
- Subtle paper texture background
- Tap anywhere on card → VerseDetailSheet

### Daily Metrics Grid
```
┌──────────────┬──────────────┬──────────────┐
│  ♥  72 bpm   │  📊 48ms HRV │  🫁  97% O₂  │
│  Heart Rate  │  Recovery    │  Oxygen      │
├──────────────┼──────────────┼──────────────┤
│  🌙 81% Eff  │  🏃 4,234    │  💤 7h 20m   │
│  Sleep       │  Steps       │  Total Sleep │
└──────────────┴──────────────┴──────────────┘
```
- 2-row × 3-column grid of metric tiles
- Each tile: large value, unit, icon, label
- Color-coded: green = good, yellow = fair, red = poor (against personal baselines)
- Tap any tile → expands to 7-day sparkline chart for that metric
- Missing data shows "—" not error state

### Recent Verses Row (Horizontal Scroll)
- "Recent Verses" section header with "See All →" link
- Horizontal scroll of small verse cards (last 5 deliveries)
- Each card: state color, state name, reference, date
- Tap → HistoryDetailView

### Streak Widget
```
┌─────────────────────────────────────────────────────┐
│  🔥 12-Day Streak                                   │
│  You've engaged with Scripture every day this week  │
│  ████████░░░░░  12 of 14 days this month           │
└─────────────────────────────────────────────────────┘
```

---

## 3. VerseDetailSheet (Slides up from HomeView)

**Purpose:** Deep engagement with a single verse.

**Layout:**
- Drag handle at top
- State banner (same gradient, smaller)
- Large verse text (22pt serif, generous line height)
- Reference + Translation badge
- "Why this verse?" section:
  - Expandable card showing: "Your heart rate was 58 bpm, your HRV was 31ms (below your average of 48ms), and your sleep efficiency last night was 68%. Pulse recognized you may be carrying some burden today, and chose this verse of rest."
- Related verses (3 suggestions — same theme)
- "Read Full Chapter" → opens Bible.com/YouVersion app deep link
- Action row: Love | Save | Share | Pray with This
- "Pray with This" → PrayerPromptView (simple guided prayer based on verse)

---

## 4. HistoryView

**Purpose:** Your spiritual journey, told through biometric moments.

**Layout:**
- Title: "Your Journey"
- Filter bar: All | Loved | Saved | [State filter dropdown]
- Grouped list by date (Today, Yesterday, This Week, Earlier)

### HistoryRow
```
┌─────────────────────────────────────────────────────┐
│  🌊 Weary Soul    •    Jul 29  8:14am               │
│  Matthew 11:28                                      │
│  "Come to me, all you who are weary..."             │
│  ♡ Loved                                           │
└─────────────────────────────────────────────────────┘
```

### HistoryDetailView
- Full verse text
- State at time of delivery
- Mini health snapshot (horizontal metric chips)
- Time delivered
- User reaction
- "Share" button

---

## 5. ShareCardView

**Purpose:** Generate a beautiful verse card to share to Instagram, iMessage, etc.

**Layout variants (user swipes to pick):**
1. **Classic** — cream background, dark serif text, minimal
2. **Luminous** — state gradient background, white text, glow effect
3. **Dawn** — warm sunrise gradient, verse centered
4. **Night** — deep navy, gold accent, starfield subtle
5. **Minimal** — white background, accent color reference text

**Each card:**
- Verse text (large)
- Reference + Translation
- Pulse logo (small, bottom right) — for competition attribution
- Optional: health context line ("After my morning run" — user can toggle off)

**Export:** `ImageRenderer` to PNG → `UIActivityViewController`

---

## 6. SettingsView

### Sections

#### Profile
- Display name (used in greeting)
- Bible Translation (picker)
- Language preference

#### Notifications
- Master on/off toggle
- Max verses per day (1/2/3/5/unlimited)
- Quiet hours (time range picker)
- Emergency override: "Always notify for Stressed/Sad states"
- Notification preview style (title only / with verse / full)

#### Health Metrics
- List of each metric with on/off toggle
- "All metrics contribute to better verse matching"
- Heart Rate (on by default)
- HRV (on by default)
- Sleep Analysis (on by default)
- Blood Oxygen (on if available)
- Respiratory Rate (on if available)
- Body Temperature (off by default, experimental)
- Activity / Steps (on by default)
- VO2 Max (on if available)
- Mindfulness Minutes (on if available)

#### Scripture
- Default translation
- "Include Verse of the Day" toggle (daily bonus verse at 8am regardless of state)
- Preferred themes (multi-select): Peace | Strength | Hope | Guidance | Praise | Rest | Love | Purpose

#### Watch
- Complication style preference
- "Send verses to Watch" toggle
- Sync status indicator

#### Privacy & Data
- "Clear verse history" (destructive, confirmation required)
- "Reset health baselines"
- Privacy policy link
- Data storage explanation

#### About
- App version
- Competition entry: "Built for Scripture in New Frontiers — Kaggle 2024"
- Credits: YouVersion API + Gloo AI Studio
- Feedback / Rate App
- Open Source acknowledgments

---

## Notification Design

### Standard Verse Notification
```
Title:    🌊 A word for you right now
Body:     "Come to me, all you who are weary..." — Matthew 11:28
Subtitle: Tap to read the full verse
Category: verse_notification
```

### Post-Workout Notification  
```
Title:    🏆 Well done! Here's your verse
Body:     "I can do all things through Christ..." — Phil 4:13
```

### Morning Verse Notification
```
Title:    ☀️ Good morning — new mercies today
Body:     "This is the day the Lord has made..." — Psalm 118:24
```

### Notification Actions (registered in AppDelegate)
```swift
UNNotificationAction(
    identifier: "LOVE_VERSE",
    title: "♡ Love",
    options: []
),
UNNotificationAction(
    identifier: "SAVE_VERSE", 
    title: "🔖 Save",
    options: []
),
UNNotificationAction(
    identifier: "DISMISS",
    title: "Dismiss",
    options: [.destructive]
)
```

---

## Live Activities (iOS 16.2+)

When a workout is in progress (detected via HealthKit), a Live Activity appears on the Dynamic Island / Lock Screen:

**Compact view (Dynamic Island):**
```
[♥ 142bpm]  ···  Pulse  ···  [🏃 Running 18min]
```

**Expanded Lock Screen view:**
```
┌──────────────────────────────────────────────┐
│  Pulse  ·  Active Workout                │
│  Running  ·  18 min  ·  ♥ 142 bpm            │
│                                              │
│  "I can do all this through him..."          │
│                        — Phil 4:13           │
└──────────────────────────────────────────────┘
```

Post-workout, the Live Activity transitions to the Victory Lap verse for 5 minutes then dismisses.
