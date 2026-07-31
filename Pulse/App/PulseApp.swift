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
    }

    var body: some Scene {
        WindowGroup {
            DebugHomeView()
                .environment(healthEngine)
                .environment(scriptureEngine)
                .task {
                    // Wire onClassification hook ONCE
                    healthEngine.onClassification = { [se = scriptureEngine] result in
                        await se.processStateChange(result)
                    }
                    // Register AppBridge so AppDelegate can trigger refresh
                    AppBridge.shared.healthEngine = healthEngine
                    // Schedule background task
                    AppDelegate.scheduleHealthCheckTask()
                    // Request notification permissions
                    _ = await NotificationService.shared.requestAuthorization()
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

// MARK: - Debug Home View (Task 9 + Task 10 extended)

private struct DebugHomeView: View {
    @Environment(HealthEngine.self) private var healthEngine
    @Environment(ScriptureEngine.self) private var scriptureEngine

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // --- Health State ---
                Group {
                    Text(healthEngine.currentClassification?.state.displayName ?? "—")
                        .font(.largeTitle)
                        .bold()

                    if let classification = healthEngine.currentClassification {
                        Text(String(format: "Confidence: %.0f%%", classification.confidence * 100))
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        if let snapshot = healthEngine.currentSnapshot {
                            Text(String(format: "Data completeness: %.0f%%", snapshot.dataCompleteness * 100))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No classification yet")
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // --- Verse Delivery ---
                Group {
                    if scriptureEngine.isLoading {
                        ProgressView("Delivering verse…")
                    } else if let delivery = scriptureEngine.currentDelivery {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(delivery.verseReference)
                                .font(.headline)
                                .bold()
                            Text(delivery.verseText)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                            HStack {
                                Text(delivery.translationAbbreviation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if delivery.isOfflineFallback {
                                    Text("Offline")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else {
                        Text("No verse delivered yet")
                            .foregroundStyle(.secondary)
                    }
                }

                // --- Actions ---
                VStack(spacing: 12) {
                    Button("Refresh Health") {
                        Task { await healthEngine.refresh() }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Deliver First Verse") {
                        Task { await scriptureEngine.deliverFirstVerse() }
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }
            }
            .padding()
        }
        .task {
            try? await healthEngine.requestAuthorization()
            await healthEngine.refresh()
        }
    }
}
