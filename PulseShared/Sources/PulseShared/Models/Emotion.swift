import Foundation

public enum EnergyLevel: String, Codable, Sendable {
    case low
    case medium
    case high
}

public enum MoodTone: String, Codable, Sendable {
    case negative
    case neutral
    case positive
}

public enum Emotion: String, Codable, CaseIterable, Identifiable, Sendable {
    case drained
    case restful
    case content
    case weighedDown = "weighed_down"
    case steady
    case grateful
    case stressed
    case driven
    case energized
    case unwell

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .drained:
            return "Drained"
        case .restful:
            return "Restful"
        case .content:
            return "Content"
        case .weighedDown:
            return "Weighed Down"
        case .steady:
            return "Steady"
        case .grateful:
            return "Grateful"
        case .stressed:
            return "Stressed"
        case .driven:
            return "Driven"
        case .energized:
            return "Energized"
        case .unwell:
            return "Unwell"
        }
    }

    public var energy: EnergyLevel {
        switch self {
        case .drained, .restful, .content:
            return .low
        case .weighedDown, .steady, .grateful:
            return .medium
        case .stressed, .driven, .energized:
            return .high
        case .unwell:
            return .medium
        }
    }

    public var mood: MoodTone {
        switch self {
        case .drained, .weighedDown, .stressed:
            return .negative
        case .restful, .steady, .driven:
            return .neutral
        case .content, .grateful, .energized:
            return .positive
        case .unwell:
            return .neutral
        }
    }

    public var biometricState: BiometricState {
        switch self {
        case .drained:
            return .exhaustedDepleted
        case .restful:
            return .eveningWindingDown
        case .content:
            return .morningAwakening
        case .weighedDown:
            return .sadWithdrawn
        case .steady:
            return .peacefulSteady
        case .grateful:
            return .deepRestRecovered
        case .stressed:
            return .stressedAnxious
        case .driven:
            return .activeEngaged
        case .energized:
            return .energizedPostWorkout
        case .unwell:
            return .sickUnwell
        }
    }

    public static func grid(energy: EnergyLevel, mood: MoodTone) -> Emotion {
        switch (energy, mood) {
        case (.low, .negative):
            return .drained
        case (.low, .neutral):
            return .restful
        case (.low, .positive):
            return .content
        case (.medium, .negative):
            return .weighedDown
        case (.medium, .neutral):
            return .steady
        case (.medium, .positive):
            return .grateful
        case (.high, .negative):
            return .stressed
        case (.high, .neutral):
            return .driven
        case (.high, .positive):
            return .energized
        }
    }
}

extension BiometricState {
    public var defaultEmotion: Emotion {
        switch self {
        case .energizedPostWorkout:
            return .energized
        case .stressedAnxious:
            return .stressed
        case .exhaustedDepleted:
            return .drained
        case .deepRestRecovered:
            return .grateful
        case .peacefulSteady:
            return .steady
        case .morningAwakening:
            return .content
        case .eveningWindingDown:
            return .restful
        case .activeEngaged:
            return .driven
        case .sadWithdrawn:
            return .weighedDown
        case .sickUnwell:
            return .unwell
        case .peakPerformance:
            return .energized
        case .spiritualAlert:
            return .steady
        }
    }
}
