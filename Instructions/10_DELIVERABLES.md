# 10 — Deliverables, Requirements & Judging

## Competition: Scripture in New Frontiers

**Host:** Kaggle  
**Sponsored by:** YouVersion / Life.Church + Gloo  
**Track:** Wearables  
**Submission type:** Working prototype + documentation + demo video  

---

## Competition Requirements Checklist

### ✅ Must-Have (Non-Negotiable)

| # | Requirement | Pulse Implementation | Status |
|---|-------------|--------------------------|--------|
| 1 | Must use **YouVersion Platform API** | `YouVersionClient.swift` — verse text retrieval + VOTD | ✅ |
| 2 | Must use **Gloo AI Studio API** | `GlooAIClient.swift` — contextual verse selection | ✅ |
| 3 | Must be a **wearable application** | Native watchOS 10 app with Apple Watch complications | ✅ |
| 4 | Scripture must be **natively embedded** | Verses delivered directly to wrist, not just a link | ✅ |
| 5 | Must provide **genuine value** to users | Real health-to-spiritual-state pipeline, not gimmick | ✅ |
| 6 | Must include **working prototype** | Buildable Xcode project, testable on device | ✅ |

### ✅ Should-Have (Strong Differentiators)

| # | Requirement | Pulse Implementation |
|---|-------------|--------------------------|
| 7 | Novel use of Scripture | First app to trigger delivery via biometric state |
| 8 | Personalization | Translation selection, preferred themes, reaction learning |
| 9 | Privacy-first design | Zero health data to external servers |
| 10 | Offline capability | 12 bundled emergency verses + local cache |
| 11 | Multiple delivery surfaces | Watch complications, notifications, Live Activities |
| 12 | Rich engagement | History, sharing, prayer, streak tracking |

---

## Deliverables List

### 1. Xcode Project (Source Code)
**Repository Structure:**
```
Pulse/
├── Pulse.xcodeproj
├── Pulse/                 # iOS app source
├── PulseWatch/            # watchOS app source  
├── PulseShared/           # Shared framework
├── Config/
│   ├── Debug.xcconfig.template  # Keys placeholder (no real keys)
│   └── Release.xcconfig.template
├── README.md                   # How to build
└── SUBMISSION.md               # Competition narrative
```

**Build instructions must include:**
- How to obtain and configure API keys
- Minimum hardware/software requirements
- How to install on physical device
- Known limitations

### 2. Demo Video (3–5 minutes)
Required scenes:
1. **Intro (30s):** App name, tagline, competition context
2. **Post-workout demo (60s):** Finish a short workout → watch shows Victory Lap verse
3. **Poor sleep demo (45s):** Show low sleep efficiency → Weary Soul verse delivered
4. **Watch complications (30s):** Show verse on multiple watch faces
5. **iPhone app walkthrough (90s):** Home, History, Share card, Settings
6. **Prayer interaction (30s):** Prayer view on Watch
7. **Privacy explanation (30s):** No data leaves device
8. **API integration highlight (30s):** Code snippet of YouVersion + Gloo calls

### 3. Written Submission (SUBMISSION.md)
**Required sections:**
- Problem Statement
- Solution Description
- YouVersion API Usage (specific endpoints called)
- Gloo AI Studio Usage (prompts, use case)
- Technical Architecture Overview
- Privacy Approach
- User Impact / Testimonials (if beta tested)
- Screenshots / App Store mockups
- Future roadmap

### 4. Screenshots (for Submission Portal)
Minimum 5 screenshots:
1. iPhone HomeView with active verse and state
2. Apple Watch VerseView (45mm)
3. Apple Watch with complication on multiple face styles
4. iPhone History view
5. iPhone Share Card (one design variant)

---

## Technical Acceptance Criteria

For the submission to be considered complete, the app must:

### Health Engine
- [ ] Successfully request HealthKit permissions on first launch
- [ ] Read at least 6 distinct health metrics (HR, HRV, sleep, SpO2, activity, respiratory)
- [ ] Classify user state from real HealthKit data (not hardcoded/mocked)
- [ ] Handle missing data gracefully (not crash when metrics unavailable)
- [ ] Run in background and process health updates without user interaction

### Scripture Engine
- [ ] Successfully call Gloo AI Studio API with structured health context
- [ ] Successfully fetch verse text from YouVersion Platform API
- [ ] Handle API failures with local fallback (no crash, no empty screen)
- [ ] Cache fetched verses for offline use
- [ ] Respect delivery cooldowns (not spam the user)

### Watch App
- [ ] Install and run independently on Apple Watch
- [ ] Display current verse on at least 3 complication families
- [ ] Receive verse updates from iPhone via WatchConnectivity
- [ ] Allow user reaction (love/save) from watch
- [ ] Update complication when new verse arrives

### iPhone App
- [ ] Complete onboarding flow (permissions → translation → first verse)
- [ ] Display current state and verse on HomeView
- [ ] Show verse history sorted by date
- [ ] Allow sharing verse cards as images
- [ ] Settings for translation, notifications, health metrics

### Privacy & Safety
- [ ] Zero biometric data transmitted to external APIs
- [ ] API calls contain only enum state values + preferences (no raw numbers)
- [ ] No analytics/tracking SDKs
- [ ] Health data deletable from settings

---

## Judging Criteria (Estimated Weights)

Based on competition description analysis:

| Criterion | Weight | Pulse Score |
|-----------|--------|-----------------|
| **Creativity of API integration** | 30% | ⭐⭐⭐⭐⭐ — biometrics trigger Scripture, never done before |
| **Technical implementation quality** | 25% | ⭐⭐⭐⭐⭐ — native Swift, no hacks, proper HealthKit patterns |
| **Real-world impact & value** | 25% | ⭐⭐⭐⭐⭐ — genuine pastoral care at scale |
| **Use of both required APIs** | 10% | ⭐⭐⭐⭐⭐ — both APIs deeply integrated, not tokenized |
| **Wearable / platform fit** | 10% | ⭐⭐⭐⭐⭐ — Watch is the perfect platform for this use case |

---

## Quality Standards

### Code Quality
- Swift 5.9+ idiomatic patterns
- No force-unwraps in production paths
- All async operations use Swift Concurrency (async/await)
- No Combine — prefer SwiftUI's observation patterns (@Observable, @State)
- All network calls have timeout + retry logic
- All HealthKit queries have proper predicate + sort descriptors

### UI/UX Standards
- No hardcoded strings — all user-facing text in `Localizable.strings`
- Minimum 44pt tap targets everywhere
- Loading states for all async operations (skeleton cards, not spinners)
- Empty states for history (first-time user)
- Error states with clear, non-technical messages
- All animations respect `accessibilityReduceMotion`

### Testing Requirements
(Unit tests for logic-heavy layers)
- `StateClassifierTests` — verify all 12 states trigger correctly
- `DeliverySchedulerTests` — verify cooldown logic
- `HealthSnapshotTests` — verify metric parsing + completeness
- `GlooAIClientTests` — mock API responses
- `YouVersionClientTests` — mock API responses

---

## App Store Readiness (Post-Competition)

If this submission advances, the following additional work is needed for App Store release:

### Legal
- [ ] Privacy Policy (hosted URL required)
- [ ] Terms of Service
- [ ] YouVersion API usage agreement approval
- [ ] Gloo API commercial licensing

### App Review
- [ ] HealthKit usage descriptions match actual usage (Apple strictly enforces)
- [ ] No "improve" or "diagnose" language — HealthKit can't claim medical utility
- [ ] Clear disclosure that app is for spiritual uplift, not medical advice
- [ ] Age rating: 4+ (no objectionable content)

### Store Listing
- App Name: Pulse
- Subtitle: Scripture for Every Heartbeat
- Category: Health & Fitness (primary) / Lifestyle (secondary)
- Keywords: bible, scripture, health, watch, verse, devotional, fitness, prayer

---

## Estimated Build Timeline

| Phase | Duration | Files |
|-------|----------|-------|
| Xcode project setup + shared framework | 2 hours | `09_XCODE_PROJECT_SETUP.md` |
| Data models + HealthKit engine | 4 hours | `03_HEALTH_ENGINE.md`, `08_DATA_MODELS.md` |
| Gloo AI + YouVersion API clients | 3 hours | `04_AI_SCRIPTURE_ENGINE.md` |
| Design system + components | 3 hours | `07_UI_DESIGN_SYSTEM.md` |
| Watch app (all views + complications) | 6 hours | `06_WATCH_APP.md` |
| iPhone app (all views + flows) | 8 hours | `05_IPHONE_APP.md` |
| Notifications + background tasks | 2 hours | `02_ARCHITECTURE.md` |
| Integration + testing | 4 hours | — |
| Demo video creation | 2 hours | — |
| Submission documentation | 1 hour | — |
| **TOTAL** | **~35 hours** | |

---

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Gloo AI API not yet public/documented | Implement abstraction layer; fallback to custom OpenAI/Claude call with same prompt |
| YouVersion API access restricted | Fallback to Bible.org NLT API (labs.bible.org) or bundled NIV verses (public domain KJV) |
| HealthKit data sparse on simulator | Mock data provider pattern for simulator builds; test on real device |
| Background delivery unreliable | Multiple delivery triggers: observer queries + BGProcessingTask + foreground refresh |
| Watch/iPhone connectivity gaps | WCSession `transferUserInfo` guarantees delivery even when not reachable |
| App Store HealthKit rejection | Clear usage descriptions, no medical claims, proper entitlements |

---

## Final Submission Checklist

- [ ] Xcode project builds without errors on target device
- [ ] All HealthKit permissions properly requested
- [ ] Both APIs (Gloo + YouVersion) called in production flow
- [ ] Watch complications update with new verses
- [ ] History view shows past deliveries
- [ ] Share card exports correctly
- [ ] Settings save and persist across launches
- [ ] Emergency verse fallback works when airplane mode enabled
- [ ] No crashes on any of the 12 state classifications
- [ ] Demo video recorded and uploaded
- [ ] Written submission complete with all sections
- [ ] All screenshots captured at device resolution
- [ ] Code pushed to repository with clean commit history
- [ ] API keys removed from committed code (use xcconfig.template)
- [ ] README.md includes build instructions for judges
