import Foundation

public enum WatchMessage {
    public enum MessageType: String, Codable, Sendable {
        case verseDelivery = "verse_delivery"
        case healthSummary = "health_summary"
        case verseReaction = "verse_reaction"
        case settingsUpdate = "settings_update"
        case requestLatestVerse = "request_latest_verse"
    }

    public protocol WatchPayload: Codable {
        func dictionary(type: MessageType) -> [String: Any]
        static func from(_ dict: [String: Any]) -> Self?
    }

    public struct VerseDeliveryPayload: WatchPayload, Sendable, Identifiable {
        public var id: String { deliveryID }
        public let deliveryID: String
        public let verseText: String
        public let verseReference: String
        public let translationAbbreviation: String
        public let stateRaw: String
        public let stateDisplayName: String
        public let stateEmoji: String
        public let stateBodyText: String
        public let primaryColor: String
        public let timestamp: Double

        // Optional vitals captured at delivery time — nil when unavailable.
        // These fields are optional so that old JSON (without them) decodes cleanly.
        public let heartRate: Double?       // bpm
        public let hrv: Double?             // ms SDNN
        public let sleepEfficiency: Double? // fraction 0-1

        public init(
            deliveryID: String,
            verseText: String,
            verseReference: String,
            translationAbbreviation: String,
            stateRaw: String,
            stateDisplayName: String,
            stateEmoji: String,
            stateBodyText: String,
            primaryColor: String,
            timestamp: Double,
            heartRate: Double? = nil,
            hrv: Double? = nil,
            sleepEfficiency: Double? = nil
        ) {
            self.deliveryID = deliveryID
            self.verseText = verseText
            self.verseReference = verseReference
            self.translationAbbreviation = translationAbbreviation
            self.stateRaw = stateRaw
            self.stateDisplayName = stateDisplayName
            self.stateEmoji = stateEmoji
            self.stateBodyText = stateBodyText
            self.primaryColor = primaryColor
            self.timestamp = timestamp
            self.heartRate = heartRate
            self.hrv = hrv
            self.sleepEfficiency = sleepEfficiency
        }
    }

    public struct HealthSummaryPayload: WatchPayload, Sendable {
        public let heartRate: Double?
        public let hrv: Double?
        public let oxygenSaturation: Double?
        public let sleepEfficiency: Double?
        public let stepCount: Int?
        public let stateRaw: String
        public let lastUpdated: Double

        public init(
            heartRate: Double? = nil,
            hrv: Double? = nil,
            oxygenSaturation: Double? = nil,
            sleepEfficiency: Double? = nil,
            stepCount: Int? = nil,
            stateRaw: String,
            lastUpdated: Double
        ) {
            self.heartRate = heartRate
            self.hrv = hrv
            self.oxygenSaturation = oxygenSaturation
            self.sleepEfficiency = sleepEfficiency
            self.stepCount = stepCount
            self.stateRaw = stateRaw
            self.lastUpdated = lastUpdated
        }
    }

    public struct ReactionPayload: WatchPayload, Sendable {
        public let deliveryID: String
        public let reactionRaw: String
        public let timestamp: Double

        public init(
            deliveryID: String,
            reactionRaw: String,
            timestamp: Double
        ) {
            self.deliveryID = deliveryID
            self.reactionRaw = reactionRaw
            self.timestamp = timestamp
        }
    }
}

extension WatchMessage.WatchPayload {
    public func dictionary(type: WatchMessage.MessageType) -> [String: Any] {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self),
              var dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        dict["type"] = type.rawValue
        return dict
    }

    public static func from(_ dict: [String: Any]) -> Self? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(Self.self, from: data)
    }
}
