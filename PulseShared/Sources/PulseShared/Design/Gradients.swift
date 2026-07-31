import SwiftUI

extension BiometricState {
    public var gradient: LinearGradient {
        switch self {
        case .energizedPostWorkout:
            // Victory orange-gold — triumph, energy
            return LinearGradient(
                colors: [Color(hex: "#B45309"), Color(hex: "#D97706"), Color(hex: "#F59E0B")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

        case .stressedAnxious:
            // Cool blue-teal — calming, still waters
            return LinearGradient(
                colors: [Color(hex: "#1E3A5F"), Color(hex: "#1E40AF"), Color(hex: "#3B82F6")],
                startPoint: .top, endPoint: .bottom
            )

        case .exhaustedDepleted:
            // Deep slate-purple — quiet, night sky rest
            return LinearGradient(
                colors: [Color(hex: "#1E1B4B"), Color(hex: "#312E81"), Color(hex: "#4338CA")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

        case .deepRestRecovered:
            // Warm sunrise gold-rose — new mercies, morning light
            return LinearGradient(
                colors: [Color(hex: "#7C2D12"), Color(hex: "#C2410C"), Color(hex: "#FB923C")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

        case .peacefulSteady:
            // Sage green — still waters, green pastures
            return LinearGradient(
                colors: [Color(hex: "#064E3B"), Color(hex: "#065F46"), Color(hex: "#059669")],
                startPoint: .top, endPoint: .bottom
            )

        case .morningAwakening:
            // Sky blue to dawn — new day, new mercies
            return LinearGradient(
                colors: [Color(hex: "#0C4A6E"), Color(hex: "#0369A1"), Color(hex: "#38BDF8")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

        case .eveningWindingDown:
            // Dusk purple-indigo — peaceful night, Psalm 4
            return LinearGradient(
                colors: [Color(hex: "#2D1B69"), Color(hex: "#4C1D95"), Color(hex: "#7C3AED")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

        case .activeEngaged:
            // Bright teal-cyan — purposeful energy
            return LinearGradient(
                colors: [Color(hex: "#134E4A"), Color(hex: "#0F766E"), Color(hex: "#14B8A6")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

        case .sadWithdrawn:
            // Deep gray-blue — honest grief, tender comfort
            return LinearGradient(
                colors: [Color(hex: "#1F2937"), Color(hex: "#374151"), Color(hex: "#4B5563")],
                startPoint: .top, endPoint: .bottom
            )

        case .sickUnwell:
            // Warm olive — healing warmth, gentle hope
            return LinearGradient(
                colors: [Color(hex: "#3B2F0C"), Color(hex: "#713F12"), Color(hex: "#A16207")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

        case .peakPerformance:
            // Royal purple-violet — excellence, mountain top
            return LinearGradient(
                colors: [Color(hex: "#4A044E"), Color(hex: "#7E22CE"), Color(hex: "#A855F7")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

        case .spiritualAlert:
            // Deep midnight blue with subtle silver — watchman hour
            return LinearGradient(
                colors: [Color(hex: "#0A0E1A"), Color(hex: "#0F1729"), Color(hex: "#1E2D4A")],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    public var primaryColor: Color {
        // Returns the most vibrant color from the gradient for accents
        // Used in complication tints, notification banners, etc.
        switch self {
        case .energizedPostWorkout:  return Color(hex: "#F59E0B")
        case .stressedAnxious:       return Color(hex: "#3B82F6")
        case .exhaustedDepleted:     return Color(hex: "#6366F1")
        case .deepRestRecovered:     return Color(hex: "#FB923C")
        case .peacefulSteady:        return Color(hex: "#34D399")
        case .morningAwakening:      return Color(hex: "#38BDF8")
        case .eveningWindingDown:    return Color(hex: "#8B5CF6")
        case .activeEngaged:         return Color(hex: "#14B8A6")
        case .sadWithdrawn:          return Color(hex: "#9CA3AF")
        case .sickUnwell:            return Color(hex: "#CA8A04")
        case .peakPerformance:       return Color(hex: "#A855F7")
        case .spiritualAlert:        return Color(hex: "#C7D2FE")
        }
    }

    public var primaryColorHex: String {
        // Returns the hex string for the primary color
        // Used by WatchMessage payloads
        switch self {
        case .energizedPostWorkout:  return "#F59E0B"
        case .stressedAnxious:       return "#3B82F6"
        case .exhaustedDepleted:     return "#6366F1"
        case .deepRestRecovered:     return "#FB923C"
        case .peacefulSteady:        return "#34D399"
        case .morningAwakening:      return "#38BDF8"
        case .eveningWindingDown:    return "#8B5CF6"
        case .activeEngaged:         return "#14B8A6"
        case .sadWithdrawn:          return "#9CA3AF"
        case .sickUnwell:            return "#CA8A04"
        case .peakPerformance:       return "#A855F7"
        case .spiritualAlert:        return "#C7D2FE"
        }
    }
}
