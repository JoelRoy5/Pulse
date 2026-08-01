import Foundation
import SwiftData
import PulseShared

@Observable
@MainActor
final class OnboardingViewModel {

    // MARK: - Step

    enum Step: String {
        case welcome, permissions, translation, complete
    }

    // MARK: - State

    var step: Step
    var availableTranslations: [BibleVersion] = []
    var selectedTranslation: BibleVersion = BibleVersion(
        id: DefaultBible.id,
        abbreviation: DefaultBible.abbreviation,
        title: DefaultBible.title
    )
    var previewVerseCache: [Int: String] = [:]
    var previewVerseText: String?
    var isLoadingPreview: Bool = false
    var permissionsLimited: Bool = false
    var firstVerse: VerseDelivery?

    // MARK: - Init

    init(step: Step = .welcome) {
        self.step = step
    }

    // MARK: - Permissions

    func grantPermissions(healthEngine: HealthEngine) async {
        // HealthKit
        do {
            try await healthEngine.requestAuthorization()
        } catch {
            permissionsLimited = true
        }
        // Notifications
        let granted = await NotificationService.shared.requestAuthorization()
        if !granted {
            permissionsLimited = true
        }
        step = .translation
    }

    // MARK: - Translation Loading

    func loadTranslations() async {
        let client = YouVersionClient(appKey: AppConfig.youVersionAppKey)
        do {
            let bibles = try await client.listBibles()
            availableTranslations = bibles.isEmpty ? fallbackTranslations() : bibles
        } catch {
            availableTranslations = fallbackTranslations()
        }
        // Auto-select BSB if available, otherwise first
        if let bsb = availableTranslations.first(where: { $0.id == DefaultBible.id }) {
            selectedTranslation = bsb
        } else if let first = availableTranslations.first {
            selectedTranslation = first
        }
        // Preload preview for the selected translation
        await loadPreviewVerse(for: selectedTranslation)
    }

    func selectTranslation(_ version: BibleVersion) async {
        selectedTranslation = version
        await loadPreviewVerse(for: version)
    }

    func loadPreviewVerse(for version: BibleVersion) async {
        // Return cached result immediately
        if let cached = previewVerseCache[version.id] {
            previewVerseText = cached
            return
        }
        isLoadingPreview = true
        previewVerseText = nil
        let client = YouVersionClient(appKey: AppConfig.youVersionAppKey)
        do {
            let verse = try await client.fetchVerse(
                reference: "John 3:16",
                bibleID: version.id,
                abbreviation: version.abbreviation
            )
            let text = verse.text
            previewVerseCache[version.id] = text
            previewVerseText = text
        } catch {
            previewVerseText = "The Word, in this translation"
        }
        isLoadingPreview = false
    }

    // MARK: - Finish

    func finish(
        healthEngine: HealthEngine,
        scriptureEngine: ScriptureEngine,
        modelContext: ModelContext
    ) async {
        // Upsert UserPreferences
        let descriptor = FetchDescriptor<UserPreferences>()
        let prefs: UserPreferences
        if let existing = try? modelContext.fetch(descriptor).first {
            prefs = existing
        } else {
            prefs = UserPreferences()
            modelContext.insert(prefs)
        }
        prefs.preferredBibleID = selectedTranslation.id
        prefs.preferredBibleAbbreviation = selectedTranslation.abbreviation
        prefs.hasCompletedOnboarding = true
        try? modelContext.save()

        // Request first verse — always returns a delivery (fallback chain handles failures)
        let delivery = await scriptureEngine.deliverFirstVerse()
        firstVerse = delivery
        step = .complete
    }

    // MARK: - Private

    private func fallbackTranslations() -> [BibleVersion] {
        [BibleVersion(id: DefaultBible.id, abbreviation: DefaultBible.abbreviation, title: DefaultBible.title)]
    }
}
