# 08 — Data Models

## Overview

All data models are defined in the `PulseShared` framework target so they can be used by both the iOS app and watchOS app without duplication.

---

## BiometricState Enum

```swift
// BiometricState.swift

import SwiftUI

enum BiometricState: String, Codable, CaseIterable, Identifiable {
    case energizedPostWorkout = "energized_post_workout"
    case stressedAnxious      = "stressed_anxious"
    case exhaustedDepleted    = "exhausted_depleted"
    case deepRestRecovered    = "deep_rest_recovered"
    case peacefulSteady       = "peaceful_steady"
    case morningAwakening     = "morning_awakening"
    case eveningWindingDown   = "evening_winding_down"
    case activeEngaged        = "active_engaged"
    case sadWithdrawn         = "sad_withdrawn"
    case sickUnwell           = "sick_unwell"
    case peakPerformance      = "peak_performance"
    case spiritualAlert       = "spiritual_alert"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .energizedPostWorkout: return "Victory Lap"
        case .stressedAnxious:      return "Still Waters"
        case .exhaustedDepleted:    return "Weary Soul"
        case .deepRestRecovered:    return "Sabbath Morning"
        case .peacefulSteady:       return "Still Small Voice"
        case .morningAwakening:     return "New Mercies"
        case .eveningWindingDown:   return "Evening Psalm"
        case .activeEngaged:        return "Purpose Walk"
        case .sadWithdrawn:         return "Broken Vessel"
        case .sickUnwell:           return "Healing Hands"
        case .peakPerformance:      return "Mountain Top"
        case .spiritualAlert:       return "Watchman Hour"
        }
    }
    
    var abbreviation: String {
        switch self {
        case .energizedPostWorkout: return "Victory"
        case .stressedAnxious:      return "Calm"
        case .exhaustedDepleted:    return "Rest"
        case .deepRestRecovered:    return "Restored"
        case .peacefulSteady:       return "Peace"
        case .morningAwakening:     return "Morning"
        case .eveningWindingDown:   return "Evening"
        case .activeEngaged:        return "Active"
        case .sadWithdrawn:         return "Comfort"
        case .sickUnwell:           return "Healing"
        case .peakPerformance:      return "Peak"
        case .spiritualAlert:       return "Watchman"
        }
    }
    
    var bodyInterpretation: String {
        switch self {
        case .energizedPostWorkout:
            return "Your body just did something amazing. You earned this."
        case .stressedAnxious:
            return "Your heart is carrying tension right now. You're not alone."
        case .exhaustedDepleted:
            return "Your body is asking for rest. Come and lay it down."
        case .deepRestRecovered:
            return "You slept well. Your body is renewed. New mercies are here."
        case .peacefulSteady:
            return "Your vitals are calm and steady. A moment of stillness."
        case .morningAwakening:
            return "A new day begins. Your body is waking with purpose."
        case .eveningWindingDown:
            return "The day is ending. Your body is preparing for rest."
        case .activeEngaged:
            return "You're moving with energy and purpose today."
        case .sadWithdrawn:
            return "Your body has been quiet. God is close to the heavy-hearted."
        case .sickUnwell:
            return "Your body is working hard to heal. He sees you."
        case .peakPerformance:
            return "You are in peak form today. Soar on wings like eagles."
        case .spiritualAlert:
            return "The night has opened space for quiet. God is awake with you."
        }
    }
    
    var verseTheme: String {
        switch self {
        case .energizedPostWorkout: return "strength_perseverance"
        case .stressedAnxious:      return "peace_calm"
        case .exhaustedDepleted:    return "rest_renewal"
        case .deepRestRecovered:    return "gratitude_praise"
        case .peacefulSteady:       return "abiding_presence"
        case .morningAwakening:     return "morning_newness"
        case .eveningWindingDown:   return "evening_rest"
        case .activeEngaged:        return "purpose_calling"
        case .sadWithdrawn:         return "comfort_hope"
        case .sickUnwell:           return "healing_trust"
        case .peakPerformance:      return "excellence_calling"
        case .spiritualAlert:       return "prayer_watchfulness"
        }
    }
    
    var deliveryUrgency: DeliveryUrgency {
        switch self {
        case .stressedAnxious, .sadWithdrawn, .exhaustedDepleted, .sickUnwell:
            return .high    // bypass standard cooldowns if confidence > 0.85
        case .energizedPostWorkout, .spiritualAlert:
            return .timeSensitive  // deliver within a short window or miss it
        default:
            return .standard
        }
    }
    
    enum DeliveryUrgency {
        case high
        case timeSensitive
        case standard
    }
}
```

---

## HealthSnapshot

```swift
// HealthSnapshot.swift

import HealthKit
import Foundation

struct HealthSnapshot: Codable {
    
    // MARK: - Vitals
    var heartRate: Double?              // BPM — 10-min average
    var heartRateVariability: Double?   // SDNN in ms — latest reading
    var restingHeartRate: Double?       // BPM — HealthKit computed daily
    var respiratoryRate: Double?        // breaths/min — 1hr average
    var oxygenSaturation: Double?       // 0.0–1.0 (e.g. 0.97)
    var bodyTemperature: Double?        // Celsius — latest reading
    var walkingHeartRateAverage: Double? // BPM — today's average
    var vo2Max: Double?                 // mL/kg/min — latest
    
    // MARK: - Sleep
    var sleepEfficiency: Double?        // 0.0–1.0
    var deepSleepMinutes: Double?
    var remSleepMinutes: Double?
    var lightSleepMinutes: Double?
    var totalSleepMinutes: Double?
    var lateNightWakeMinutes: Double?
    var sleepOnsetMinutes: Double?      // minutes to fall asleep
    var bedtime: Date?
    var wakeTime: Date?
    
    // MARK: - Activity
    var activeEnergyBurned: Double?     // kcal today
    var basalEnergyBurned: Double?      // kcal today
    var stepCount: Int?                 // steps today
    var exerciseMinutes: Double?        // minutes today
    var standHours: Int?                // hours today
    var distanceWalkingRunning: Double? // km today
    var flightsClimbed: Int?            // today
    
    // MARK: - Mindfulness
    var mindfulMinutes: Double?         // today
    
    // MARK: - Recent Workout
    var lastWorkoutType: String?        // HKWorkoutActivityType rawValue as String
    var lastWorkoutEndedMinutesAgo: Double?
    var lastWorkoutDurationMinutes: Double?
    var lastWorkoutCalories: Double?
    var lastWorkoutHRAvg: Double?
    
    // MARK: - Metadata
    var timestamp: Date = .now
    var dataCompleteness: Double = 0.0  // % of non-nil fields (0.0–1.0)
    
    // MARK: - Computed Properties
    
    var sleepQuality: SleepQuality {
        guard let efficiency = sleepEfficiency,
              let total = totalSleepMinutes else { return .unknown }
        
        switch (efficiency, total) {
        case (let e, let t) where e > 0.90 && t >= 420:  return .excellent
        case (let e, let t) where e > 0.80 && t >= 360:  return .good
        case (let e, let t) where e > 0.70 && t >= 300:  return .fair
        case (_, let t) where t < 240:                    return .veryPoor
        default:                                           return .poor
        }
    }
    
    var hrvCategory: HRVCategory {
        guard let hrv = heartRateVariability else { return .unknown }
        switch hrv {
        case ...20:   return .veryLow
        case 20...40: return .low
        case 40...60: return .moderate
        case 60...80: return .high
        default:      return .veryHigh
        }
    }
    
    var isPostWorkout: Bool {
        guard let minsAgo = lastWorkoutEndedMinutesAgo else { return false }
        return minsAgo >= 2 && minsAgo <= 60
    }
    
    // Compute dataCompleteness from actual populated fields
    mutating func computeCompleteness() {
        let vitalFields: [Any?] = [
            heartRate, heartRateVariability, restingHeartRate,
            respiratoryRate, oxygenSaturation
        ]
        let sleepFields: [Any?] = [sleepEfficiency, totalSleepMinutes]
        let activityFields: [Any?] = [stepCount, activeEnergyBurned]
        
        let allFields = vitalFields + sleepFields + activityFields
        let presentCount = allFields.compactMap { $0 }.count
        dataCompleteness = Double(presentCount) / Double(allFields.count)
    }
    
    enum SleepQuality: String {
        case excellent, good, fair, poor, veryPoor, unknown
    }
    
    enum HRVCategory: String {
        case veryLow, low, moderate, high, veryHigh, unknown
    }
}
```

---

## ClassificationResult

```swift
// ClassificationResult.swift

struct ClassificationResult {
    let state: BiometricState
    let confidence: Double          // 0.0–1.0
    let snapshot: HealthSnapshot
    let classifiedAt: Date = .now
    let subScores: BiometricSubScores
    
    var isHighConfidence: Bool { confidence >= 0.80 }
    var isMarginal: Bool { confidence < 0.65 }
}

struct BiometricSubScores: Codable {
    var hrStress: Double        // 0=elevated HR, 1=calm HR
    var hrvRecovery: Double     // 0=crashed, 1=excellent
    var sleepQuality: Double    // 0=poor, 1=excellent
    var oxygenLevel: Double     // 0=low, 1=excellent
    var activityLevel: Double   // 0=sedentary, 1=very active
    var respiratoryStress: Double // 0=elevated, 1=normal
    var timeOfDay: TimeOfDay
    
    enum TimeOfDay: String, Codable {
        case earlyMorning   // 5–8am
        case morning        // 8am–12pm
        case afternoon      // 12–5pm
        case evening        // 5–9pm
        case night          // 9pm–5am
    }
}
```

---

## BibleVerse (Shared)

```swift
// BibleVerse.swift

struct BibleVerse: Codable, Identifiable, Hashable {
    let id: String                   // canonical USFM ID e.g. "MAT.11.28"
    let reference: String            // "Matthew 11:28"
    let text: String                 // Plain text verse content
    let translationAbbreviation: String  // "NIV"
    let copyright: String
    let chapterURLString: String?    // https://bible.com/bible/111/MAT.11.28
    
    var chapterURL: URL? {
        chapterURLString.flatMap(URL.init(string:))
    }
    
    // Short excerpt for complications and notifications
    func excerpt(maxChars: Int = 60) -> String {
        if text.count <= maxChars { return text }
        let truncated = text.prefix(maxChars)
        let lastSpace = truncated.lastIndex(of: " ") ?? truncated.endIndex
        return String(truncated[..<lastSpace]) + "..."
    }
}
```

---

## VerseDelivery (SwiftData Model)

```swift
// PulseSchema.swift

import SwiftData
import Foundation

@Model
final class VerseDelivery {
    @Attribute(.unique)
    var id: UUID
    
    // Verse content
    var verseID: String              // USFM ID
    var verseReference: String       // "Matthew 11:28"
    var verseText: String
    var translationAbbreviation: String
    var verseTheme: String           // "rest_renewal"
    var themeDisplayName: String     // "Rest & Renewal"
    
    // State at delivery
    var biometricStateRaw: String    // BiometricState.rawValue
    var stateConfidence: Double
    var stateBodyText: String        // BiometricState.bodyInterpretation at time of delivery
    
    // Health metrics at delivery (stored for history context)
    var heartRateAtDelivery: Double?
    var hrvAtDelivery: Double?
    var restingHRAtDelivery: Double?
    var oxygenAtDelivery: Double?
    var sleepEfficiencyAtDelivery: Double?
    var deepSleepAtDelivery: Double?
    var stepCountAtDelivery: Int?
    var wasPostWorkout: Bool
    var workoutTypeAtDelivery: String?
    
    // Delivery metadata
    var deliveredAt: Date
    var deliveryMethod: String       // "notification" | "complication" | "in_app"
    
    // User engagement
    var userReactionRaw: String?     // VerseReaction.rawValue or nil
    var engagedAt: Date?             // when user tapped/opened
    var sharedAt: Date?
    var savedAt: Date?
    
    // AI metadata
    var glooRationale: String?       // AI explanation for the verse choice
    var isOfflineFallback: Bool      // was AI unavailable?
    
    init(
        id: UUID = UUID(),
        verseID: String,
        verseReference: String,
        verseText: String,
        translationAbbreviation: String,
        verseTheme: String,
        themeDisplayName: String,
        biometricStateRaw: String,
        stateConfidence: Double,
        stateBodyText: String,
        deliveredAt: Date = .now,
        deliveryMethod: String = "notification",
        wasPostWorkout: Bool = false,
        isOfflineFallback: Bool = false
    ) {
        self.id = id
        self.verseID = verseID
        self.verseReference = verseReference
        self.verseText = verseText
        self.translationAbbreviation = translationAbbreviation
        self.verseTheme = verseTheme
        self.themeDisplayName = themeDisplayName
        self.biometricStateRaw = biometricStateRaw
        self.stateConfidence = stateConfidence
        self.stateBodyText = stateBodyText
        self.deliveredAt = deliveredAt
        self.deliveryMethod = deliveryMethod
        self.wasPostWorkout = wasPostWorkout
        self.isOfflineFallback = isOfflineFallback
    }
    
    // Computed helpers
    var biometricState: BiometricState? {
        BiometricState(rawValue: biometricStateRaw)
    }
    
    var userReaction: VerseReaction? {
        get { userReactionRaw.flatMap(VerseReaction.init(rawValue:)) }
        set { userReactionRaw = newValue?.rawValue }
    }
}

// Cached verse (to avoid repeated API calls)
@Model
final class CachedVerse {
    @Attribute(.unique)
    var cacheKey: String             // "\(reference)_\(translation)"
    var verseID: String
    var reference: String
    var text: String
    var translationAbbreviation: String
    var copyright: String
    var chapterURLString: String?
    var cachedAt: Date
    var accessCount: Int
    var lastAccessedAt: Date
    
    init(verse: BibleVerse) {
        self.cacheKey = "\(verse.reference)_\(verse.translationAbbreviation)"
        self.verseID = verse.id
        self.reference = verse.reference
        self.text = verse.text
        self.translationAbbreviation = verse.translationAbbreviation
        self.copyright = verse.copyright
        self.chapterURLString = verse.chapterURLString
        self.cachedAt = .now
        self.accessCount = 0
        self.lastAccessedAt = .now
    }
}

// User preferences
@Model
final class UserPreferences {
    @Attribute(.unique)
    var id: Int = 1                  // singleton pattern
    
    var preferredTranslationRaw: Int = 111   // NIV by default
    var displayName: String = ""
    var hasCompletedOnboarding: Bool = false
    var maxDailyVerses: Int = 5
    var quietHoursStart: Int = 22    // 10pm (hour 0–23)
    var quietHoursEnd: Int = 6       // 6am
    var enableEmergencyOverride: Bool = true  // always notify for sad/stressed
    var notificationStyle: String = "full"   // "title_only" | "with_reference" | "full"
    var includeVerseOfDay: Bool = true
    var preferredThemes: [String] = []
    
    // Health metric toggles
    var useHeartRate: Bool = true
    var useHRV: Bool = true
    var useSleep: Bool = true
    var useOxygen: Bool = true
    var useRespiration: Bool = true
    var useBodyTemp: Bool = false
    var useActivity: Bool = true
    var useVO2Max: Bool = true
    var useMindfulness: Bool = true
    
    var preferredTranslation: BibleTranslationID {
        get { BibleTranslationID(rawValue: preferredTranslationRaw) ?? .NIV }
        set { preferredTranslationRaw = newValue.rawValue }
    }
}
```

---

## Supporting Enums

```swift
// VerseReaction.swift

enum VerseReaction: String, Codable {
    case loved     = "loved"
    case saved     = "saved"
    case dismissed = "dismissed"
    case prayed    = "prayed"    // user went to prayer view
    case shared    = "shared"
    
    var displayName: String {
        switch self {
        case .loved:     return "Loved"
        case .saved:     return "Saved"
        case .dismissed: return "Dismissed"
        case .prayed:    return "Prayed"
        case .shared:    return "Shared"
        }
    }
    
    var icon: String {
        switch self {
        case .loved:     return "heart.fill"
        case .saved:     return "bookmark.fill"
        case .dismissed: return "xmark"
        case .prayed:    return "hands.sparkles.fill"
        case .shared:    return "square.and.arrow.up"
        }
    }
}

// BibleTranslationID (already defined in 04_AI_SCRIPTURE_ENGINE.md — re-export here)
enum BibleTranslationID: Int, Codable, CaseIterable {
    case NIV  = 111
    case ESV  = 59
    case NLT  = 116
    case KJV  = 1
    case CSB  = 1713
    case NASB = 2016
    case MSG  = 97
    case AMP  = 1588
    case NKJV = 114
    case NCV  = 105
    
    var abbreviation: String { ... }   // as defined in 04
    
    var fullName: String {
        switch self {
        case .NIV:  return "New International Version"
        case .ESV:  return "English Standard Version"
        case .NLT:  return "New Living Translation"
        case .KJV:  return "King James Version"
        case .CSB:  return "Christian Standard Bible"
        case .NASB: return "New American Standard Bible 2020"
        case .MSG:  return "The Message"
        case .AMP:  return "Amplified Bible"
        case .NKJV: return "New King James Version"
        case .NCV:  return "New Century Version"
        }
    }
    
    var previewVerse: String {
        // John 3:16 in each translation — used in TranslationPickerView preview
        switch self {
        case .NIV:  return "For God so loved the world that he gave his one and only Son..."
        case .ESV:  return "For God so loved the world, that he gave his only Son..."
        case .NLT:  return "For this is how God loved the world: He gave his one and only Son..."
        case .KJV:  return "For God so loved the world, that he gave his only begotten Son..."
        case .CSB:  return "For God loved the world in this way: He gave his one and only Son..."
        case .NASB: return "For God so loved the world, that He gave His only Son..."
        case .MSG:  return "This is how much God loved the world: He gave his Son, his one and only Son..."
        case .AMP:  return "For God so [greatly] loved and dearly prized the world..."
        case .NKJV: return "For God so loved the world that He gave His only begotten Son..."
        case .NCV:  return "God loved the world so much that he gave his one and only Son..."
        }
    }
}
```

---

## WatchConnectivity Messages

```swift
// WatchMessage.swift — shared between iOS and watchOS

struct WatchMessage {
    enum MessageType: String {
        case verseDelivery    = "verse_delivery"
        case healthSummary    = "health_summary"
        case verseReaction    = "verse_reaction"
        case settingsUpdate   = "settings_update"
    }
    
    // Phone → Watch: deliver a verse
    struct VerseDeliveryPayload: Codable {
        let deliveryID: String
        let verseText: String
        let verseReference: String
        let translationAbbreviation: String
        let stateRaw: String
        let stateDisplayName: String
        let stateEmoji: String
        let stateBodyText: String
        let primaryColor: String     // hex string
        let timestamp: Double        // timeIntervalSince1970
    }
    
    // Phone → Watch: health summary
    struct HealthSummaryPayload: Codable {
        let heartRate: Double?
        let hrv: Double?
        let oxygenSaturation: Double?
        let sleepEfficiency: Double?
        let stepCount: Int?
        let stateRaw: String
        let lastUpdated: Double
    }
    
    // Watch → Phone: user reacted to a verse
    struct ReactionPayload: Codable {
        let deliveryID: String
        let reactionRaw: String
        let timestamp: Double
    }
}
```

---

## SwiftData Schema Registration

```swift
// ModelContainer+Setup.swift

import SwiftData

extension ModelContainer {
    static var pulse: ModelContainer = {
        let schema = Schema([
            VerseDelivery.self,
            CachedVerse.self,
            UserPreferences.self,
        ])
        let config = ModelConfiguration(
            "Pulse",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .automatic,      // App Group for Watch sharing
            cloudKitDatabase: .none          // No iCloud sync (privacy)
        )
        return try! ModelContainer(for: schema, configurations: [config])
    }()
}
```

---

## HealthQuality Enum

```swift
enum HealthQuality {
    case good
    case fair
    case poor
    case unavailable
    
    var color: Color {
        switch self {
        case .good:        return Color.psSuccess
        case .fair:        return Color.psWarning
        case .poor:        return Color.psAlert
        case .unavailable: return Color.psGrayMuted
        }
    }
    
    var label: String {
        switch self {
        case .good:        return "Good"
        case .fair:        return "Fair"
        case .poor:        return "Low"
        case .unavailable: return "N/A"
        }
    }
    
    // Factory for HR quality
    static func forHeartRate(_ bpm: Double, restingBPM: Double?) -> HealthQuality {
        guard let resting = restingBPM else { return .unavailable }
        let ratio = bpm / resting
        switch ratio {
        case ..<1.3: return .good
        case 1.3..<1.6: return .fair
        default: return .poor
        }
    }
    
    // Factory for HRV quality
    static func forHRV(_ ms: Double) -> HealthQuality {
        switch ms {
        case 50...: return .good
        case 30..<50: return .fair
        default: return .poor
        }
    }
    
    // Factory for SpO2
    static func forOxygen(_ fraction: Double) -> HealthQuality {
        switch fraction {
        case 0.97...: return .good
        case 0.94..<0.97: return .fair
        default: return .poor
        }
    }
    
    // Factory for sleep efficiency
    static func forSleepEfficiency(_ efficiency: Double) -> HealthQuality {
        switch efficiency {
        case 0.85...: return .good
        case 0.70..<0.85: return .fair
        default: return .poor
        }
    }
}
```
