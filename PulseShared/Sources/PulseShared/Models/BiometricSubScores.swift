import Foundation

public struct BiometricSubScores: Codable, Sendable {
    public var hrStress: Double
    public var hrvRecovery: Double
    public var sleepQuality: Double
    public var oxygenLevel: Double
    public var activityLevel: Double
    public var respiratoryStress: Double
    public var timeOfDay: TimeOfDay

    public init(
        hrStress: Double,
        hrvRecovery: Double,
        sleepQuality: Double,
        oxygenLevel: Double,
        activityLevel: Double,
        respiratoryStress: Double,
        timeOfDay: TimeOfDay
    ) {
        self.hrStress = hrStress
        self.hrvRecovery = hrvRecovery
        self.sleepQuality = sleepQuality
        self.oxygenLevel = oxygenLevel
        self.activityLevel = activityLevel
        self.respiratoryStress = respiratoryStress
        self.timeOfDay = timeOfDay
    }
}
