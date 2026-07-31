public enum BiometricState: String, Codable, CaseIterable, Identifiable, Sendable {
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

    public var id: String { rawValue }

    public var displayName: String {
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

    public var abbreviation: String {
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

    public var bodyInterpretation: String {
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

    public var verseTheme: String {
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

    public var emoji: String {
        switch self {
        case .energizedPostWorkout:  return "🏆"
        case .stressedAnxious:       return "🌊"
        case .exhaustedDepleted:     return "🌙"
        case .deepRestRecovered:     return "☀️"
        case .peacefulSteady:        return "🕊️"
        case .morningAwakening:      return "🌅"
        case .eveningWindingDown:    return "🌆"
        case .activeEngaged:         return "⚡️"
        case .sadWithdrawn:          return "🫂"
        case .sickUnwell:            return "🌿"
        case .peakPerformance:       return "🔥"
        case .spiritualAlert:        return "🌌"
        }
    }

    public var deliveryUrgency: DeliveryUrgency {
        switch self {
        case .stressedAnxious, .sadWithdrawn, .exhaustedDepleted, .sickUnwell:
            return .high    // bypass standard cooldowns if confidence > 0.85
        case .energizedPostWorkout, .spiritualAlert:
            return .timeSensitive  // deliver within a short window or miss it
        default:
            return .standard
        }
    }

    public enum DeliveryUrgency: Sendable {
        case high
        case timeSensitive
        case standard
    }
}
