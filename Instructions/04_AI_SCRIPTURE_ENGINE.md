# 04 — AI & Scripture Engine

## Overview

The AI & Scripture Engine bridges health state data to the Word of God using two APIs:
1. **Gloo AI Studio** — selects the contextually appropriate scripture reference using AI
2. **YouVersion Platform API** — retrieves the actual verse text in the user's chosen translation

---

## Gloo AI Studio Integration

### What is Gloo AI Studio?
Gloo AI Studio (https://studio.ai.gloo.com) is an API platform providing AI capabilities specifically designed for faith-based applications. It offers Scripture-aware AI prompting with built-in theological integrity and alignment with human flourishing.

### GlooAIClient

File: `Pulse/Core/Scripture/GlooAIClient.swift`

```swift
import Foundation

// MARK: - Request / Response Models

struct GlooVerseRequest: Encodable {
    let physicalState: String          // e.g. "exhausted_depleted"
    let stateDisplayName: String       // e.g. "Weary Soul"
    let timeOfDay: String              // morning | afternoon | evening | night
    let stateConfidence: Double        // 0.0–1.0
    let recentStates: [String]         // last 3 states (for context continuity)
    let preferredTranslation: String   // NIV | ESV | NLT | KJV | CSB | NASB | MSG | AMP
    let preferredThemes: [String]?     // user's saved/liked verse themes
    let avoidRepeats: [String]?        // recently delivered references to avoid
    
    enum CodingKeys: String, CodingKey {
        case physicalState = "physical_state"
        case stateDisplayName = "state_display_name"
        case timeOfDay = "time_of_day"
        case stateConfidence = "state_confidence"
        case recentStates = "recent_states"
        case preferredTranslation = "preferred_translation"
        case preferredThemes = "preferred_themes"
        case avoidRepeats = "avoid_repeats"
    }
}

struct GlooVerseResponse: Decodable {
    let verseReference: String         // e.g. "Matthew 11:28"
    let book: String                   
    let chapter: Int                   
    let verse: Int                     
    let endVerse: Int?                 // for ranges (e.g., v28-30)
    let theme: String                  // e.g. "rest_renewal"
    let themeDisplayName: String       // e.g. "Rest & Renewal"
    let rationale: String              // AI's explanation (for debug/display)
    let alternates: [String]           // backup references if primary unavailable
    
    enum CodingKeys: String, CodingKey {
        case verseReference = "verse_reference"
        case book, chapter, verse
        case endVerse = "end_verse"
        case theme
        case themeDisplayName = "theme_display_name"
        case rationale, alternates
    }
}

// MARK: - Client

actor GlooAIClient {
    private let apiKey: String
    private let baseURL = URL(string: "https://api.gloo.ai/v1")!
    private let session: URLSession
    
    init(apiKey: String) {
        self.apiKey = apiKey
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }
    
    func selectVerse(for context: BiometricContext) async throws -> GlooVerseResponse {
        let endpoint = baseURL.appendingPathComponent("scripture/contextual-verse")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Pulse/1.0 iOS", forHTTPHeaderField: "User-Agent")
        
        let body = GlooVerseRequest(
            physicalState: context.state.rawValue,
            stateDisplayName: context.state.displayName,
            timeOfDay: context.timeOfDay.rawValue,
            stateConfidence: context.confidence,
            recentStates: context.recentStateHistory.map(\.rawValue),
            preferredTranslation: context.preferredTranslation.abbreviation,
            preferredThemes: context.preferredThemes,
            avoidRepeats: context.recentlyDeliveredReferences
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GlooError.invalidResponse
        }
        
        return try JSONDecoder().decode(GlooVerseResponse.self, from: data)
    }
}

// MARK: - Fallback: Local Verse Mapping
// Used when Gloo API is unavailable (offline, rate limit, etc.)
extension GlooAIClient {
    static func fallbackReference(for state: BiometricState) -> String {
        switch state {
        case .energizedPostWorkout:   return "Philippians 4:13"
        case .stressedAnxious:        return "John 14:27"
        case .exhaustedDepleted:      return "Matthew 11:28-30"
        case .deepRestRecovered:      return "Lamentations 3:22-23"
        case .peacefulSteady:         return "Psalm 23:2-3"
        case .morningAwakening:       return "Psalm 118:24"
        case .eveningWindingDown:     return "Psalm 4:8"
        case .activeEngaged:          return "Colossians 3:23-24"
        case .sadWithdrawn:           return "Psalm 34:18"
        case .sickUnwell:             return "Psalm 103:2-3"
        case .peakPerformance:        return "Isaiah 40:31"
        case .spiritualAlert:         return "Isaiah 26:3"
        }
    }
}
```

### AI Prompt Design (Gloo Studio System Prompt)

The system prompt sent to Gloo AI Studio is structured to ensure scripture is matched with pastoral sensitivity:

```
You are a pastoral scripture guide for a health and wellness app called Pulse. 
Your role is to select a single Bible verse (or short passage of 2–3 verses) that is 
most relevant and meaningful to a person currently experiencing the described physical 
and emotional state.

Guidelines:
- Select verses that DIRECTLY address the stated condition
- Prefer well-known, beloved verses that resonate emotionally
- Never select verses that could feel judgmental or shame-inducing
- For physical states (post-workout, sick), select verses that honor the body as God's temple
- For emotional states (stressed, sad), select verses that offer genuine comfort
- Vary selections over time — do not repeat verses frequently
- Consider the time of day (morning verses are energizing; evening verses are peaceful)
- The translation is a preference — always select the reference, not translation-specific text

Return JSON only. No explanation outside the JSON structure.
```

---

## YouVersion Platform API Integration

### What is YouVersion Platform API?
The YouVersion Platform API (provided by YouVersion/Life.Church) gives programmatic access to Bible content, verse of the day, reading plans, and more — the same content that powers the Bible App with 500+ million users.

### YouVersionClient

File: `Pulse/Core/Scripture/YouVersionClient.swift`

```swift
import Foundation

// MARK: - Models

struct BibleVerse: Decodable, Identifiable {
    let id: String                   // e.g. "JHN.3.16"
    let reference: String            // e.g. "John 3:16"
    let text: String                 // cleaned verse text
    let html: String?                // HTML formatted version
    let translation: BibleTranslation
    let copyright: String
    let chapterURL: URL?             // link to full chapter on Bible.com
    
    enum CodingKeys: String, CodingKey {
        case id, reference, text, html, translation, copyright
        case chapterURL = "chapter_url"
    }
}

struct BibleTranslation: Decodable {
    let id: Int
    let abbreviation: String         // NIV, ESV, NLT, etc.
    let name: String                 // New International Version
    let language: String             // en, es, fr, etc.
}

struct VerseOfTheDayResponse: Decodable {
    let day: Int
    let verse: BibleVerse
    let image: VOTDImage?
    
    struct VOTDImage: Decodable {
        let url: URL
        let attribution: String
    }
}

// MARK: - Translation IDs (YouVersion internal IDs)

enum BibleTranslationID: Int {
    case NIV = 111
    case ESV = 59
    case NLT = 116
    case KJV = 1
    case CSB = 1713
    case NASB = 2016   // NASB 2020
    case MSG = 97
    case AMP = 1588
    case NKJ = 114
    case NCV = 105
    
    var abbreviation: String {
        switch self {
        case .NIV: return "NIV"
        case .ESV: return "ESV"
        case .NLT: return "NLT"
        case .KJV: return "KJV"
        case .CSB: return "CSB"
        case .NASB: return "NASB"
        case .MSG: return "MSG"
        case .AMP: return "AMP"
        case .NKJ: return "NKJV"
        case .NCV: return "NCV"
        }
    }
}

// MARK: - Client

actor YouVersionClient {
    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession
    
    init(apiKey: String, baseURL: URL) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }
    
    // Fetch a specific verse by reference string
    // reference: "Matthew 11:28" or "Matthew 11:28-30"
    func fetchVerse(
        reference: String,
        translation: BibleTranslationID
    ) async throws -> BibleVerse {
        
        var components = URLComponents(
            url: baseURL.appendingPathComponent("bible/verse"),
            resolvingAgainstBaseURL: true
        )!
        components.queryItems = [
            URLQueryItem(name: "q", value: reference),
            URLQueryItem(name: "version_id", value: String(translation.rawValue)),
        ]
        
        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "X-YouVersion-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw YouVersionError.requestFailed
        }
        
        return try JSONDecoder().decode(BibleVerse.self, from: data)
    }
    
    // Verse of the Day (used as fallback or daily devotional feature)
    func fetchVerseOfTheDay(
        translation: BibleTranslationID
    ) async throws -> VerseOfTheDayResponse {
        
        var components = URLComponents(
            url: baseURL.appendingPathComponent("bible/votd"),
            resolvingAgainstBaseURL: true
        )!
        components.queryItems = [
            URLQueryItem(name: "version_id", value: String(translation.rawValue)),
        ]
        
        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "X-YouVersion-Token")
        
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(VerseOfTheDayResponse.self, from: data)
    }
}
```

---

## ScriptureEngine — Orchestrator

File: `Pulse/Core/Scripture/ScriptureEngine.swift`

```swift
@MainActor
class ScriptureEngine: ObservableObject {
    @Published var currentDelivery: VerseDelivery?
    @Published var isLoading: Bool = false
    @Published var error: ScriptureError?
    
    private let glooClient: GlooAIClient
    private let youVersionClient: YouVersionClient
    private let deliveryScheduler: DeliveryScheduler
    private let cache: VerseCache
    
    // Main pipeline — called by HealthEngine when state changes
    func processStateChange(_ result: ClassificationResult) async {
        guard await deliveryScheduler.shouldDeliver(for: result) else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let context = buildContext(from: result)
            
            // Step 1: Get verse reference from Gloo AI
            let glooResponse: GlooVerseResponse
            if NetworkMonitor.shared.isConnected {
                glooResponse = try await glooClient.selectVerse(for: context)
            } else {
                // Offline fallback
                let fallback = GlooAIClient.fallbackReference(for: result.state)
                glooResponse = GlooVerseResponse.from(fallbackReference: fallback)
            }
            
            // Step 2: Check cache first
            if let cached = await cache.verse(reference: glooResponse.verseReference,
                                               translation: context.preferredTranslation) {
                await deliver(cached, state: result, theme: glooResponse.theme)
                return
            }
            
            // Step 3: Fetch from YouVersion
            let verse = try await youVersionClient.fetchVerse(
                reference: glooResponse.verseReference,
                translation: context.preferredTranslation
            )
            
            // Step 4: Cache it
            await cache.store(verse)
            
            // Step 5: Create delivery and persist
            await deliver(verse, state: result, theme: glooResponse.theme)
            
        } catch {
            // Try alternate references if primary fails
            await tryAlternateDelivery(for: result)
        }
    }
    
    private func deliver(
        _ verse: BibleVerse,
        state: ClassificationResult,
        theme: String
    ) async {
        let delivery = VerseDelivery(
            id: UUID(),
            verse: verse,
            biometricState: state.state,
            healthSnapshot: state.snapshot,
            theme: theme,
            deliveredAt: .now
        )
        
        // Persist to SwiftData
        await cache.saveDelivery(delivery)
        
        // Update UI
        currentDelivery = delivery
        
        // Send to Watch
        WatchSessionManager.shared.sendVerse(delivery)
        
        // Local notification
        await NotificationService.shared.scheduleVerseNotification(delivery)
        
        // Update complication
        WidgetCenter.shared.reloadAllTimelines()
    }
}
```

---

## VerseCache

File: `Pulse/Core/Scripture/VerseCache.swift`

Stores verses in SwiftData for offline access and history. Implements a 500-verse LRU cache.

```swift
@Model
final class CachedVerse {
    @Attribute(.unique) var reference: String  // "Matthew 11:28"
    var translationAbbreviation: String        // "NIV"
    var text: String
    var copyright: String
    var cachedAt: Date
    var accessCount: Int = 0
    var lastAccessedAt: Date
}

@Model  
final class VerseDelivery {
    var id: UUID
    var verseReference: String
    var verseText: String
    var translation: String
    var biometricStateRaw: String
    var theme: String
    var heartRateAtDelivery: Double?
    var hrvAtDelivery: Double?
    var sleepQualityAtDelivery: Double?
    var deliveredAt: Date
    var userReaction: String?  // "loved" | "saved" | "dismissed" | nil
    var sharedAt: Date?
}
```

---

## DeliveryScheduler

File: `Pulse/Core/Scripture/DeliveryScheduler.swift`

Determines whether a verse should be delivered given the current state, history, and user preferences.

```swift
actor DeliveryScheduler {
    
    func shouldDeliver(for result: ClassificationResult) async -> Bool {
        let now = Date()
        let currentHour = Calendar.current.component(.hour, from: now)
        
        // 1. Silence window check (except watchman state)
        if (0...5).contains(currentHour) && result.state != .spiritualAlert {
            return false
        }
        
        // 2. Data completeness check
        guard result.snapshot.dataCompleteness >= DeliveryRules.minimumDataCompleteness else {
            return false
        }
        
        // 3. Confidence threshold
        guard result.confidence >= 0.65 else { return false }
        
        // 4. Daily limit check
        let todayCount = await fetchTodayDeliveryCount()
        let maxDaily = UserDefaults.standard.integer(forKey: "maxDailyVerses")
        let limit = maxDaily > 0 ? maxDaily : 5
        guard todayCount < limit else { return false }
        
        // 5. Recent delivery cooldown
        if let lastDelivery = await fetchLastDelivery() {
            let elapsed = now.timeIntervalSince(lastDelivery.deliveredAt)
            guard elapsed >= DeliveryRules.minimumTimeBetweenDeliveries else { return false }
        }
        
        // 6. Same-state cooldown
        if let lastSameState = await fetchLastDelivery(for: result.state) {
            let elapsed = now.timeIntervalSince(lastSameState.deliveredAt)
            guard elapsed >= DeliveryRules.minimumSameStateDelay else { return false }
        }
        
        // 7. High-urgency override (stressed/exhausted/sick bypass cooldowns)
        if [.stressedAnxious, .exhaustedDepleted, .sickUnwell, .sadWithdrawn].contains(result.state),
           result.confidence > 0.85 {
            return true // override cooldown for urgent pastoral care states
        }
        
        return true
    }
}
```

---

## Error Handling & Fallback Chain

```
1. Gloo AI available → YouVersion fetch → deliver
2. Gloo AI unavailable → local fallback reference → YouVersion fetch → deliver
3. YouVersion unavailable → local fallback reference → cached verse → deliver
4. Cache empty → hardcoded verse (bundled in app, 12 verses, one per state)
5. No delivery possible → schedule retry in 30 min
```

### Bundled Emergency Verses (Always Available)
All 12 state-specific verses are bundled as JSON in the app bundle:
File: `Resources/emergency_verses.json`

```json
{
  "energized_post_workout": {
    "reference": "Philippians 4:13",
    "text": "I can do all this through him who gives me strength.",
    "translation": "NIV"
  },
  "stressed_anxious": {
    "reference": "John 14:27",
    "text": "Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid.",
    "translation": "NIV"
  },
  "exhausted_depleted": {
    "reference": "Matthew 11:28",
    "text": "Come to me, all you who are weary and burdened, and I will give you rest.",
    "translation": "NIV"
  },
  "deep_rest_recovered": {
    "reference": "Lamentations 3:22-23",
    "text": "Because of the Lord's great love we are not consumed, for his compassions never fail. They are new every morning; great is your faithfulness.",
    "translation": "NIV"
  },
  "peaceful_steady": {
    "reference": "Psalm 23:2-3",
    "text": "He makes me lie down in green pastures, he leads me beside quiet waters, he refreshes my soul.",
    "translation": "NIV"
  },
  "morning_awakening": {
    "reference": "Psalm 118:24",
    "text": "This is the day the Lord has made; let us rejoice and be glad in it.",
    "translation": "NIV"
  },
  "evening_winding_down": {
    "reference": "Psalm 4:8",
    "text": "In peace I will lie down and sleep, for you alone, Lord, make me dwell in safety.",
    "translation": "NIV"
  },
  "active_engaged": {
    "reference": "Colossians 3:23",
    "text": "Whatever you do, work at it with all your heart, as working for the Lord, not for human masters.",
    "translation": "NIV"
  },
  "sad_withdrawn": {
    "reference": "Psalm 34:18",
    "text": "The Lord is close to the brokenhearted and saves those who are crushed in spirit.",
    "translation": "NIV"
  },
  "sick_unwell": {
    "reference": "Psalm 103:2-3",
    "text": "Praise the Lord, my soul, and forget not all his benefits — who forgives all your sins and heals all your diseases.",
    "translation": "NIV"
  },
  "peak_performance": {
    "reference": "Isaiah 40:31",
    "text": "But those who hope in the Lord will renew their strength. They will soar on wings like eagles; they will run and not grow weary, they will walk and not be faint.",
    "translation": "NIV"
  },
  "spiritual_alert": {
    "reference": "Isaiah 26:3",
    "text": "You will keep in perfect peace those whose minds are steadfast, because they trust in you.",
    "translation": "NIV"
  }
}
```
