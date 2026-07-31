import Foundation
import PulseShared

/// Abstraction over real HealthKit queries and the mock provider used in
/// simulators or when a `-PulseMockState` launch argument is supplied.
protocol HealthDataProviding: Sendable {

    /// Whether the underlying data source is available on this device/environment.
    var isAvailable: Bool { get }

    /// Request user authorisation for the required HealthKit read types.
    /// Should be a no-op (or instantly resolve) for mock providers.
    func requestAuthorization() async throws

    /// Fetch the latest biometric snapshot.
    func fetchSnapshot() async throws -> HealthSnapshot
}
