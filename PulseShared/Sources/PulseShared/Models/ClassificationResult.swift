import Foundation

public struct ClassificationResult: Codable, Sendable {
    public let state: BiometricState
    public let emotion: Emotion
    public let confidence: Double
    public let snapshot: HealthSnapshot
    public let classifiedAt: Date
    public let subScores: BiometricSubScores

    public var isHighConfidence: Bool { confidence >= 0.80 }
    public var isMarginal: Bool { confidence < 0.65 }

    public init(
        state: BiometricState,
        emotion: Emotion,
        confidence: Double,
        snapshot: HealthSnapshot,
        classifiedAt: Date = .now,
        subScores: BiometricSubScores
    ) {
        self.state = state
        self.emotion = emotion
        self.confidence = confidence
        self.snapshot = snapshot
        self.classifiedAt = classifiedAt
        self.subScores = subScores
    }
}
