public enum HealthQuality: Sendable {
    case good
    case fair
    case poor
    case unavailable

    public var label: String {
        switch self {
        case .good:        return "Good"
        case .fair:        return "Fair"
        case .poor:        return "Low"
        case .unavailable: return "N/A"
        }
    }

    // Factory for HR quality
    public static func forHeartRate(_ bpm: Double, restingBPM: Double?) -> HealthQuality {
        guard let resting = restingBPM else { return .unavailable }
        let ratio = bpm / resting
        switch ratio {
        case ..<1.3: return .good
        case 1.3..<1.6: return .fair
        default: return .poor
        }
    }

    // Factory for HRV quality
    public static func forHRV(_ ms: Double) -> HealthQuality {
        switch ms {
        case 50...: return .good
        case 30..<50: return .fair
        default: return .poor
        }
    }

    // Factory for SpO2
    public static func forOxygen(_ fraction: Double) -> HealthQuality {
        switch fraction {
        case 0.97...: return .good
        case 0.94..<0.97: return .fair
        default: return .poor
        }
    }

    // Factory for sleep efficiency
    public static func forSleepEfficiency(_ efficiency: Double) -> HealthQuality {
        switch efficiency {
        case 0.85...: return .good
        case 0.70..<0.85: return .fair
        default: return .poor
        }
    }
}

extension HealthQuality: Equatable {}
