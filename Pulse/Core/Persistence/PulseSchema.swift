import Foundation
import SwiftData
import PulseShared

// MARK: - EmotionFeedback

@Model
final class EmotionFeedback {
    var id: UUID
    var createdAt: Date
    var shownEmotionRaw: String
    var wasAccurate: Bool
    var correctedEmotionRaw: String?
    var verseReference: String
    var verseID: String
    var wasHelpful: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        shownEmotionRaw: String,
        wasAccurate: Bool,
        correctedEmotionRaw: String? = nil,
        verseReference: String,
        verseID: String,
        wasHelpful: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.shownEmotionRaw = shownEmotionRaw
        self.wasAccurate = wasAccurate
        self.correctedEmotionRaw = correctedEmotionRaw
        self.verseReference = verseReference
        self.verseID = verseID
        self.wasHelpful = wasHelpful
    }
}

// MARK: - VerseDelivery

@Model
final class VerseDelivery {
    @Attribute(.unique)
    var id: UUID

    // Verse content
    var verseID: String
    var verseReference: String
    var verseText: String
    var translationAbbreviation: String
    var verseTheme: String
    var themeDisplayName: String

    // State at delivery
    var biometricStateRaw: String
    var stateConfidence: Double
    var stateBodyText: String

    // Health metrics at delivery (stored for history context)
    var heartRateAtDelivery: Double?         // bpm
    var hrvAtDelivery: Double?               // ms (SDNN)
    var restingHRAtDelivery: Double?         // bpm
    var oxygenAtDelivery: Double?            // fraction 0–1
    var sleepEfficiencyAtDelivery: Double?   // fraction 0–1
    var deepSleepAtDelivery: Double?         // minutes
    var stepCountAtDelivery: Int?
    var wasPostWorkout: Bool
    var workoutTypeAtDelivery: String?

    // Delivery metadata
    var deliveredAt: Date
    var deliveryMethod: String

    // User engagement
    // Love and Save are independent toggles, tracked by their own timestamps so
    // a verse can be both loved and saved at once. `userReactionRaw` remains for
    // the transient reactions (shared / prayed / dismissed).
    var userReactionRaw: String?
    var engagedAt: Date?
    var sharedAt: Date?
    var savedAt: Date?
    var lovedAt: Date?

    // Emotion (derived from classification; stored for history / analytics)
    var emotionRaw: String?

    // AI metadata
    var glooRationale: String?
    var isOfflineFallback: Bool

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

    var emotion: Emotion {
        emotionRaw.flatMap(Emotion.init(rawValue:)) ?? biometricState?.defaultEmotion ?? .steady
    }

    var userReaction: VerseReaction? {
        get { userReactionRaw.flatMap(VerseReaction.init(rawValue:)) }
        set { userReactionRaw = newValue?.rawValue }
    }

    /// Independent Love / Save state (both can be true at once).
    var isLoved: Bool { lovedAt != nil }
    var isSaved: Bool { savedAt != nil }
}

// MARK: - CachedVerse

@Model
final class CachedVerse {
    @Attribute(.unique)
    var cacheKey: String
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

// MARK: - UserPreferences

@Model
final class UserPreferences {
    @Attribute(.unique)
    var id: Int = 1

    // Translation — dynamic YouVersion IDs (coordinator amendment: replaces preferredTranslationRaw + BibleTranslationID bridge)
    var preferredBibleID: Int = 3034             // BSB by default
    var preferredBibleAbbreviation: String = "BSB"

    var displayName: String = ""
    var hasCompletedOnboarding: Bool = false
    var maxDailyVerses: Int = 5
    var quietHoursStart: Int = 22
    var quietHoursEnd: Int = 6
    var enableEmergencyOverride: Bool = true
    var notificationStyle: String = "full"
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

    init() {}

    // MARK: - Fetch-or-Create Helper

    /// Returns the single `UserPreferences` singleton row (id == 1), creating and
    /// inserting it if it does not yet exist.  Always call on the main context.
    static func current(in context: ModelContext) -> UserPreferences {
        let descriptor = FetchDescriptor<UserPreferences>(
            predicate: #Predicate { $0.id == 1 }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let prefs = UserPreferences()
        context.insert(prefs)
        try? context.save()
        return prefs
    }
}
