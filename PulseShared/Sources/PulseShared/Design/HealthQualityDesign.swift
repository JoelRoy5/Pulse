import SwiftUI

extension HealthQuality {
    public var color: Color {
        switch self {
        case .good:        return Color.psSuccess
        case .fair:        return Color.psWarning
        case .poor:        return Color.psAlert
        case .unavailable: return Color.psGrayMuted
        }
    }
}
