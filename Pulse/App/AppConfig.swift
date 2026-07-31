import Foundation

// MARK: - AppConfig

/// Reads API credentials from the app's `Info.plist` (injected at build time
/// via xcconfig variables).  Used by Tasks 10+ — defined here so the keys are
/// available from day one.
enum AppConfig {

    // MARK: - Credential Keys

    static var glooClientID: String {
        Bundle.main.object(forInfoDictionaryKey: "GlooClientID") as? String ?? ""
    }

    static var glooClientSecret: String {
        Bundle.main.object(forInfoDictionaryKey: "GlooClientSecret") as? String ?? ""
    }

    static var youVersionAppKey: String {
        Bundle.main.object(forInfoDictionaryKey: "YouVersionAppKey") as? String ?? ""
    }

    // MARK: - Configuration State

    /// `true` when all three credentials are present and don't contain a
    /// `your_…_here` placeholder (indicating the developer hasn't wired up
    /// their API keys yet).
    static var isConfigured: Bool {
        let values = [glooClientID, glooClientSecret, youVersionAppKey]
        return values.allSatisfy { value in
            !value.isEmpty && !value.contains("your_")
        }
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
