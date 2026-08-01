import SwiftUI
import SwiftData
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "PulseApp")

@main
struct PulseApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let container: ModelContainer
    @State private var healthEngine = HealthEngine()
    @State private var scriptureEngine: ScriptureEngine
    @State private var hasCompletedOnboarding: Bool
    @State private var onboardingStartStep: OnboardingViewModel.Step?

    init() {
        do {
            container = try ModelContainer.makePulseContainer()
        } catch {
            logger.error("ModelContainer init failed: \(error.localizedDescription, privacy: .public). Using in-memory fallback.")
            let schema = Schema([VerseDelivery.self, CachedVerse.self, UserPreferences.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = (try? ModelContainer(for: schema, configurations: [config]))
                ?? { fatalError("Cannot create even an in-memory ModelContainer") }()
        }

        // Build the scripture pipeline using the container's main context
        let context = container.mainContext
        let verseCache = VerseCache(context: context)
        let scheduler = DeliveryScheduler(cache: verseCache)

        // Prefer live API clients when keys are configured and offline mode is off
        let selector: any VerseSelecting
        let fetcher: any VerseFetching
        if AppConfig.isConfigured && !AppConfig.forceOffline {
            selector = GlooAIClient(clientID: AppConfig.glooClientID, clientSecret: AppConfig.glooClientSecret)
            fetcher = YouVersionClient(appKey: AppConfig.youVersionAppKey)
        } else {
            selector = OfflineFallbackSelector()
            fetcher = OfflineFallbackFetcher()
        }

        // Read UserPreferences for bible ID (use defaults if no row yet)
        var bibleID = DefaultBible.id
        var bibleAbbreviation = DefaultBible.abbreviation
        let prefDescriptor = FetchDescriptor<UserPreferences>()
        if let prefs = try? context.fetch(prefDescriptor).first {
            bibleID = prefs.preferredBibleID
            bibleAbbreviation = prefs.preferredBibleAbbreviation
        }

        _scriptureEngine = State(initialValue: ScriptureEngine(
            cache: verseCache,
            scheduler: scheduler,
            verseSelector: selector,
            verseFetcher: fetcher,
            preferredBibleID: bibleID,
            preferredBibleAbbreviation: bibleAbbreviation
        ))

        // Read onboarding completion flag
        let args = ProcessInfo.processInfo.arguments
        var completed = false
        if let prefs = try? context.fetch(prefDescriptor).first {
            completed = prefs.hasCompletedOnboarding
        }

        // -PulseResetOnboarding YES — clear flag at launch for testing
        if let idx = args.firstIndex(of: "-PulseResetOnboarding"),
           idx + 1 < args.count,
           args[idx + 1].uppercased() == "YES" {
            completed = false
            if let prefs = try? context.fetch(prefDescriptor).first {
                prefs.hasCompletedOnboarding = false
                try? context.save()
            }
        }

        // -PulseSkipOnboarding YES — bypass onboarding for UI testing / task verification
        if let idx = args.firstIndex(of: "-PulseSkipOnboarding"),
           idx + 1 < args.count,
           args[idx + 1].uppercased() == "YES" {
            completed = true
        }

        _hasCompletedOnboarding = State(initialValue: completed)

        // -PulseOnboardingStep <welcome|permissions|translation|complete>
        var startStep: OnboardingViewModel.Step? = nil
        if let idx = args.firstIndex(of: "-PulseOnboardingStep"),
           idx + 1 < args.count {
            let stepRaw = args[idx + 1]
            startStep = OnboardingViewModel.Step(rawValue: stepRaw)
        }
        _onboardingStartStep = State(initialValue: startStep)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding && onboardingStartStep == nil {
                    MainTabView()
                } else {
                    OnboardingFlow(
                        startStep: onboardingStartStep ?? .welcome,
                        onComplete: {
                            hasCompletedOnboarding = true
                            onboardingStartStep = nil
                        }
                    )
                }
            }
            .preferredColorScheme(.dark)
            .environment(healthEngine)
            .environment(scriptureEngine)
            .task {
                // Wire onClassification hook ONCE
                healthEngine.onClassification = { [se = scriptureEngine] result in
                    await se.processStateChange(result)
                }
                // Wire onDelivery so PhoneSessionManager relays verses to the watch
                scriptureEngine.onDelivery = { delivery in
                    PhoneSessionManager.shared.sendVerse(delivery)
                }
                // Register AppBridge so AppDelegate can trigger refresh
                AppBridge.shared.healthEngine = healthEngine
                AppBridge.shared.modelContainer = container
                // Activate WatchConnectivity
                PhoneSessionManager.shared.activate()
                // Schedule background task
                AppDelegate.scheduleHealthCheckTask()
                // Auto-deliver when launched with -PulseAutoDeliver YES
                // (run before notification permission prompt so it is not blocked)
                let args = ProcessInfo.processInfo.arguments
                if let idx = args.firstIndex(of: "-PulseAutoDeliver"),
                   idx + 1 < args.count,
                   args[idx + 1] == "YES" {
                    logger.info("PulseAutoDeliver: triggering deliverFirstVerse()")
                    _ = await scriptureEngine.deliverFirstVerse()
                }
                // NOTE: Notification authorization is requested by OnboardingViewModel.grantPermissions()
                // during onboarding. Do NOT add a top-level call here — it causes a double-prompt.
            }
        }
        .modelContainer(container)
    }
}

// MARK: - Offline Stub Conformances

/// Used when `AppConfig.isConfigured == false` or `AppConfig.forceOffline == true`.
/// Always throws so ScriptureEngine falls back to its fallback chain.
private struct OfflineFallbackSelector: VerseSelecting {
    func selectVerse(for context: VerseSelectionContext) async throws -> VerseSelection {
        throw ScriptureAPIError.notConfigured
    }
}

private struct OfflineFallbackFetcher: VerseFetching {
    func fetchVerse(reference: String, bibleID: Int, abbreviation: String) async throws -> BibleVerse {
        throw ScriptureAPIError.notConfigured
    }
}
