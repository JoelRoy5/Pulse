# 01 — Project Overview

## Vision Statement

Pulse transforms the Apple Watch from a health tracker into a spiritual companion. Every heartbeat, every breath, every night of sleep becomes a signal — and that signal unlocks exactly the right word from Scripture at exactly the right moment.

This is the first app to natively embed Scripture delivery into the wearable health experience, fulfilling the Kaggle "Scripture in New Frontiers" competition goal of building YouVersion Scripture and Gloo AI into non-traditional platforms.

---

## Competition Alignment

**Competition:** Scripture in New Frontiers (Kaggle / YouVersion / Gloo)  
**Track:** Wearables  
**Goal:** Build Scripture natively into wearables using YouVersion Platform and Gloo AI Studio APIs  

### How Pulse Meets the Competition Brief

| Requirement | Pulse Implementation |
|-------------|--------------------------|
| Uses YouVersion Platform API | Verse retrieval, translation selection, verse metadata |
| Uses Gloo AI Studio API | Health-context-to-scripture matching via AI prompting |
| Native wearable integration | watchOS 10 app with HealthKit live data |
| Novel/non-traditional use of Scripture | First app to gate scripture delivery on biometric state |
| Practical real-world value | Genuine spiritual uplift precisely when user needs it |

---

## Core Concept: The Biometric-to-Scripture Bridge

```
BODY STATE → EMOTIONAL STATE → SCRIPTURE NEED → VERSE SELECTION → DELIVERY
```

The app runs a continuous loop:

1. **HealthKit Observation** — passive background monitoring of all available sensors
2. **State Scoring** — a weighted scoring algorithm converts raw metrics into one of 12 emotional/physical states
3. **Context Generation** — the state + recent history is serialized into a structured prompt
4. **Gloo AI Call** — the AI selects the most contextually relevant scripture category and suggests specific verses
5. **YouVersion Fetch** — the verse text is retrieved in the user's preferred translation
6. **Smart Delivery** — verse is pushed to Watch face complication, watch notification, or iPhone notification based on user's current device posture

---

## The 12 Biometric States

Pulse classifies all user data into one of 12 named states. Each state has a unique visual identity, verse category, and delivery style.

### State Taxonomy

| State ID | Name | Primary Trigger | Scripture Theme | Delivery Urgency |
|----------|------|-----------------|-----------------|-----------------|
| `energized_post_workout` | **Victory Lap** | HR recovery after elevated workout HR | Strength, perseverance, finishing the race | Immediate (5 min post-workout) |
| `stressed_anxious` | **Still Waters** | Low HRV + elevated resting HR | Peace, "do not fear," rest in God | High urgency |
| `exhausted_depleted` | **Weary Soul** | Poor sleep + low HRV + low SpO2 | Renewal, "come to me all who are weary" | High urgency |
| `deep_rest_recovered` | **Sabbath Morning** | High sleep efficiency + good deep sleep | Praise, gratitude, new mercies | Morning delivery |
| `peaceful_steady` | **Still Small Voice** | Low HR, good HRV, normal activity | Abiding, dwelling, God's presence | Gentle |
| `morning_awakening` | **New Mercies** | First reading post-sleep window | Morning devotional, Lamentations 3:22-23 | Morning |
| `evening_winding_down` | **Evening Psalm** | Low activity + declining HR + low light (time-of-day) | Rest, Psalm 91, trust | Evening |
| `active_engaged` | **Purpose Walk** | Moderate-high step count + healthy HR | Calling, purpose, walking in Spirit | Motivating |
| `sad_withdrawn` | **Broken Vessel** | Very low activity + poor sleep + low HRV multi-day | Hope, Psalm 34, God near the brokenhearted | Compassionate |
| `sick_unwell` | **Healing Hands** | Elevated resting HR + low SpO2 + high respiratory rate | Healing, Psalm 103, God as healer | Gentle, hopeful |
| `peak_performance` | **Mountain Top** | Elite HRV + high SpO2 + great sleep + high activity | Excellence, calling, Philippians 4:13 | Celebratory |
| `spiritual_alert` | **Watchman Hour** | Late night wake + irregular patterns | Prayer, Isaiah 40, midnight watch | Quiet, personal |

---

## User Journey

### First Launch (Onboarding)
1. Welcome screen with animated verse particle effect
2. HealthKit permission request (comprehensive)
3. Preferred Bible translation selection (NIV, ESV, NLT, KJV, CSB, NASB, MSG, AMP)
4. Notification preference configuration
5. Watch app pairing confirmation
6. "Your first verse, chosen just for you" → immediate personalized verse based on current vitals

### Daily Life
- **Morning:** Watch complication shows a new verse on wakeup, matched to sleep quality
- **During day:** Background monitoring triggers contextual verse notifications
- **Post-workout:** 5-minute cooldown detection triggers "Victory Lap" verse push to watch
- **Evening:** Gentle evening verse pushed at detected wind-down time
- **Night wake:** If watch detects wakefulness at 2am+, a quiet "watchman hour" verse appears

### Long-term
- Verse history with biometric context saved
- Favorite verses bookmarked
- Weekly "Your body told us" spiritual recap
- Streak tracking for daily engagement
- Shareable verse cards with blurred health context

---

## App Name & Identity

**App Name:** Pulse  
**Tagline:** *Scripture that meets you where you are*  
**Bundle ID:** `com.yourteam.pulse`  
**App Icon Concept:** A heartbeat ECG line that transitions into an open Bible or cross  

### Brand Personality
- Warm, not clinical
- Spiritual, not religious-institutional
- Personal, not generic
- Trustworthy, not intrusive

---

## Privacy & Ethics

- **All health data stays on device** — HealthKit data is NEVER sent to any external server
- The Gloo AI call receives ONLY a structured state object (e.g., `{state: "exhausted_depleted", time_of_day: "morning"}`) — no raw metrics, no personal identifiers
- Users can disable any health metric individually
- Full data deletion available in Settings
- HealthKit access follows Apple's strict privacy model
- No tracking, no advertising, no data selling

---

## Target Audience

- **Primary:** Christians aged 25–55 who are health-conscious and active
- **Secondary:** Anyone seeking daily spiritual grounding
- **Tertiary:** Athletes who want faith integrated into their fitness journey
- **Competition Judges:** Technology innovators evaluating creative, respectful use of Scripture APIs
