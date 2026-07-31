import Foundation

public enum TimeOfDay: String, Codable, Sendable {
    case earlyMorning   // 5–8am
    case morning        // 8am–12pm
    case afternoon      // 12–5pm
    case evening        // 5–9pm
    case night          // 9pm–5am

    public init(hour: Int) {
        switch hour {
        case 5..<8:
            self = .earlyMorning
        case 8..<12:
            self = .morning
        case 12..<17:
            self = .afternoon
        case 17..<21:
            self = .evening
        default:
            self = .night
        }
    }

    public init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour], from: date)
        let hour = components.hour ?? 0
        self.init(hour: hour)
    }
}
