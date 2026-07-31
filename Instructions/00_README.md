# Pulse — Scripture That Meets You Where You Are

> **Kaggle Competition:** Scripture in New Frontiers  
> **APIs:** YouVersion Platform API + Gloo AI Studio  
> **Platform:** iOS 17+ / watchOS 10+ (Native Swift / SwiftUI)  
> **Category:** Wearables Track  

---

## What Is Pulse?

Pulse is a native Apple Watch + iPhone app that reads your body's live biometric data — heart rate, HRV, sleep quality, oxygen saturation, respiratory rate, and more — and uses that physiological fingerprint to determine your current physical and emotional state. It then intelligently surfaces a perfectly matched Bible verse directly on your wrist or phone at exactly the right moment.

When you finish a hard run and your heart rate is still elevated, Pulse sends a verse about strength and perseverance.  
When your HRV is crashed, your sleep was poor, and you've barely moved — it sends comfort and renewal.  
When you wake up rested after deep sleep, it greets you with praise and purpose.

---

## Document Index

| File | Contents |
|------|----------|
| `00_README.md` | This file — project overview and navigation |
| `01_PROJECT_OVERVIEW.md` | Full project vision, competition alignment, core concepts |
| `02_ARCHITECTURE.md` | Technical architecture, data flow diagrams, system design |
| `03_HEALTH_ENGINE.md` | HealthKit integration, biometric state detection, scoring |
| `04_AI_SCRIPTURE_ENGINE.md` | Gloo AI Studio + YouVersion API integration, verse selection logic |
| `05_IPHONE_APP.md` | Complete iPhone app spec — all screens, interactions, flows |
| `06_WATCH_APP.md` | Complete Apple Watch app spec — all complications, views, haptics |
| `07_UI_DESIGN_SYSTEM.md` | Design tokens, typography, color palette, animations, components |
| `08_DATA_MODELS.md` | All Swift data models, enums, structs, and persistence schemas |
| `09_XCODE_PROJECT_SETUP.md` | Step-by-step Xcode project creation, targets, entitlements, signing |
| `10_DELIVERABLES.md` | Contest deliverables, submission checklist, judging criteria |

---

## Quick Start for Claude CLI

To build this project from scratch, process the files **in order**:

1. `09_XCODE_PROJECT_SETUP.md` — create the Xcode project structure first
2. `08_DATA_MODELS.md` — implement all models and enums
3. `03_HEALTH_ENGINE.md` — build the HealthKit layer
4. `04_AI_SCRIPTURE_ENGINE.md` — build the AI + API layer
5. `07_UI_DESIGN_SYSTEM.md` — create the design system
6. `06_WATCH_APP.md` — build the Watch app
7. `05_IPHONE_APP.md` — build the iPhone app
8. `02_ARCHITECTURE.md` — verify architecture is complete

---

## Technology Stack

```
Platform:       iOS 17.0+ / watchOS 10.0+
Language:       Swift 5.9+
UI Framework:   SwiftUI (100% declarative)
Health:         HealthKit + WatchKit
AI:             Gloo AI Studio REST API
Scripture:      YouVersion Platform API
Persistence:    SwiftData (iOS 17+)
Networking:     Swift Concurrency (async/await) + URLSession
Notifications:  UserNotifications + WatchKit Background Tasks
Architecture:   MVVM + Clean Architecture layers
```
---
##Competition Rules
Use the following link to fully understand the competition rules before starting. Check that project is compliant with rules after every major milestone.
https://www.kaggle.com/competitions/scripture-in-new-frontiers
