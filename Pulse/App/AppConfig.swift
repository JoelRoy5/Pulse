import Foundation

// MARK: - AppConfig

/// Reads API credentials from the app's `Info.plist` (injected at build time
/// via xcconfig variables).  Used by Tasks 10+ — defined here so the keys are
/// available from day one.
enum AppConfig {

    // MARK: - Credential Keys

    static var youVersionAppKey: String {
        Bundle.main.object(forInfoDictionaryKey: "YouVersionAppKey") as? String ?? ""
    }

    // MARK: - Configuration State

    /// `true` when the YouVersion key is present and not a `your_…_here`
    /// placeholder. Verse *selection* is on-device (always available); only
    /// text fetching needs this key.
    static var isConfigured: Bool {
        !youVersionAppKey.isEmpty && !youVersionAppKey.contains("your_")
    }

    // MARK: - Debug / Testing Overrides

    /// `true` when `-PulseForceOffline YES` is supplied as a launch argument.
    /// Used by Task 10's ScriptureEngine to bypass network calls.
    static var forceOffline: Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-PulseForceOffline"),
              idx + 1 < args.count else { return false }
        return args[idx + 1].uppercased() == "YES"
    }
}
