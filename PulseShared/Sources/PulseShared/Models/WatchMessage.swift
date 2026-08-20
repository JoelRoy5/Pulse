import Foundation

public enum WatchMessage {
    public enum MessageType: String, Codable, Sendable {
        case verseDelivery = "verse_delivery"
        case healthSummary = "health_summary"
        case verseReaction = "verse_reaction"
        case settingsUpdate = "settings_update"
        case requestLatestVerse = "request_latest_verse"
        case requestVerseForState = "request_verse_for_state"
        case analyticsEvent = "analytics_event"
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
        public let stateSymbol: String
        public let stateBodyText: String
        public let primaryColor: String
        public let timestamp: Double
        /// Plain human-readable emotion name (e.g. "Stressed", "Grateful").
        /// Added in v2; old payloads without this key derive it from `stateRaw`.
        public let emotionName: String

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
            stateSymbol: String,
            stateBodyText: String,
            primaryColor: String,
            timestamp: Double,
            emotionName: String,
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
            self.stateSymbol = stateSymbol
            self.stateBodyText = stateBodyText
            self.primaryColor = primaryColor
            self.timestamp = timestamp
            self.emotionName = emotionName
            self.heartRate = heartRate
            self.hrv = hrv
            self.sleepEfficiency = sleepEfficiency
        }

        private enum CodingKeys: String, CodingKey {
            case deliveryID, verseText, verseReference, translationAbbreviation
            case stateRaw, stateDisplayName, stateSymbol, stateBodyText, primaryColor
            case timestamp, emotionName, heartRate, hrv, sleepEfficiency
        }

        // Custom decode keeps backward compatibility with payloads written before the
        // `stateEmoji` → `stateSymbol` rename (App Group cache + in-flight WC messages):
        // older JSON has no `stateSymbol` key, so we derive a valid SF Symbol from
        // `stateRaw` rather than throwing `keyNotFound` and dropping the whole delivery.
        // Similarly, `emotionName` was added later; old payloads derive it from `stateRaw`.
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            deliveryID = try c.decode(String.self, forKey: .deliveryID)
            verseText = try c.decode(String.self, forKey: .verseText)
            verseReference = try c.decode(String.self, forKey: .verseReference)
            translationAbbreviation = try c.decode(String.self, forKey: .translationAbbreviation)
            stateRaw = try c.decode(String.self, forKey: .stateRaw)
            stateDisplayName = try c.decode(String.self, forKey: .stateDisplayName)
            stateBodyText = try c.decode(String.self, forKey: .stateBodyText)
            primaryColor = try c.decode(String.self, forKey: .primaryColor)
            timestamp = try c.decode(Double.self, forKey: .timestamp)
            heartRate = try c.decodeIfPresent(Double.self, forKey: .heartRate)
            hrv = try c.decodeIfPresent(Double.self, forKey: .hrv)
            sleepEfficiency = try c.decodeIfPresent(Double.self, forKey: .sleepEfficiency)
            if let symbol = try c.decodeIfPresent(String.self, forKey: .stateSymbol) {
                stateSymbol = symbol
            } else {
                stateSymbol = BiometricState(rawValue: stateRaw)?.systemImageName ?? "sparkles"
            }
            emotionName = try c.decodeIfPresent(String.self, forKey: .emotionName)
                ?? (BiometricState(rawValue: stateRaw)?.defaultEmotion.displayName ?? stateDisplayName)
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
