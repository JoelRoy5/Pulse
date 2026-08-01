import Foundation
import SwiftData
import UserNotifications
import UIKit
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "SettingsViewModel")

// MARK: - SettingsViewModel

@Observable
@MainActor
final class SettingsViewModel {

    // MARK: - Preferences (mirrored from UserPreferences for @Observable binding)

    var displayName: String = ""
    var preferredBibleID: Int = DefaultBible.id
    var preferredBibleAbbreviation: String = DefaultBible.abbreviation

    // Notifications
    var notificationsAuthorized: Bool = false
    var maxDailyVerses: Int = 5
    var quietHoursStart: Int = 22
    var quietHoursEnd: Int = 6
    var enableEmergencyOverride: Bool = true
    var notificationStyle: String = "full"

    // Scripture
    var includeVerseOfDay: Bool = true
    var preferredThemes: [String] = []

    // Health Metrics
    var useHeartRate: Bool = true
    var useHRV: Bool = true
    var useSleep: Bool = true
    var useOxygen: Bool = true
    var useRespiration: Bool = true
    var useBodyTemp: Bool = false
    var useActivity: Bool = true
    var useVO2Max: Bool = true
    var useMindfulness: Bool = true

    // MARK: - UI State

    var isLoadingTranslations: Bool = false
    var availableTranslations: [BibleVersion] = []
    var showClearHistoryAlert: Bool = false
    var clearHistorySuccess: Bool = false
    var isSaving: Bool = false

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let scriptureEngine: ScriptureEngine
    private let phoneSessionManager: PhoneSessionManager
    private let healthEngine: HealthEngine

    // MARK: - Init

    init(
        modelContext: ModelContext,
        scriptureEngine: ScriptureEngine,
        healthEngine: HealthEngine,
        phoneSessionManager: PhoneSessionManager = .shared
    ) {
        self.modelContext = modelContext
        self.scriptureEngine = scriptureEngine
        self.healthEngine = healthEngine
        self.phoneSessionManager = phoneSessionManager
    }

    // MARK: - Load

    func load() async {
        let prefs = UserPreferences.current(in: modelContext)

        displayName = prefs.displayName
        preferredBibleID = prefs.preferredBibleID
        preferredBibleAbbreviation = prefs.preferredBibleAbbreviation
        maxDailyVerses = prefs.maxDailyVerses
        quietHoursStart = prefs.quietHoursStart
        quietHoursEnd = prefs.quietHoursEnd
        enableEmergencyOverride = prefs.enableEmergencyOverride
        notificationStyle = prefs.notificationStyle
        includeVerseOfDay = prefs.includeVerseOfDay
        preferredThemes = prefs.preferredThemes
        useHeartRate = prefs.useHeartRate
        useHRV = prefs.useHRV
        useSleep = prefs.useSleep
        useOxygen = prefs.useOxygen
        useRespiration = prefs.useRespiration
        useBodyTemp = prefs.useBodyTemp
        useActivity = prefs.useActivity
        useVO2Max = prefs.useVO2Max
        useMindfulness = prefs.useMindfulness

        // Check system notification authorization
        await refreshNotificationStatus()

        // Load translations for the picker
        await loadTranslations()
    }

    // MARK: - Save

    /// Persists all current settings to SwiftData. Called on each change.
    func save() {
        let prefs = UserPreferences.current(in: modelContext)

        prefs.displayName = displayName
        prefs.preferredBibleID = preferredBibleID
        prefs.preferredBibleAbbreviation = preferredBibleAbbreviation
        prefs.maxDailyVerses = maxDailyVerses
        prefs.quietHoursStart = quietHoursStart
        prefs.quietHoursEnd = quietHoursEnd
        prefs.enableEmergencyOverride = enableEmergencyOverride
        prefs.notificationStyle = notificationStyle
        prefs.includeVerseOfDay = includeVerseOfDay
        prefs.preferredThemes = preferredThemes
        prefs.useHeartRate = useHeartRate
        prefs.useHRV = useHRV
        prefs.useSleep = useSleep
        prefs.useOxygen = useOxygen
        prefs.useRespiration = useRespiration
        prefs.useBodyTemp = useBodyTemp
        prefs.useActivity = useActivity
        prefs.useVO2Max = useVO2Max
        prefs.useMindfulness = useMindfulness

        do {
            try modelContext.save()
            logger.info("Settings saved")
        } catch {
            logger.error("Settings save failed: \(error.localizedDescription, privacy: .public)")
        }

        // Push metric toggles to MetricCollector immediately
        pushMetricTogglesToHealthEngine()
    }

    private func pushMetricTogglesToHealthEngine() {
        var toggles = MetricToggles()
        toggles.useHeartRate = useHeartRate
        toggles.useHRV = useHRV
        toggles.useSleep = useSleep
        toggles.useOxygen = useOxygen
        toggles.useRespiration = useRespiration
        toggles.useBodyTemp = useBodyTemp
        toggles.useActivity = useActivity
        toggles.useVO2Max = useVO2Max
        toggles.useMindfulness = useMindfulness
        healthEngine.updateMetricToggles(toggles)
    }

    // MARK: - Translation

    func loadTranslations() async {
        isLoadingTranslations = true
        let client = YouVersionClient(appKey: AppConfig.youVersionAppKey)
        do {
            let bibles = try await client.listBibles()
            availableTranslations = bibles.isEmpty ? fallbackTranslations() : bibles
        } catch {
            availableTranslations = fallbackTranslations()
        }
        isLoadingTranslations = false
    }

    func selectTranslation(_ version: BibleVersion) {
        preferredBibleID = version.id
        preferredBibleAbbreviation = version.abbreviation
        save()

        // Reconfigure ScriptureEngine in-session so next delivery honors the new translation
        scriptureEngine.reconfigure(bibleID: version.id, abbreviation: version.abbreviation)

        // Notify watch about settings update
        sendSettingsUpdateToWatch()

        logger.info("Translation changed to \(version.abbreviation, privacy: .public) (id=\(version.id, privacy: .public))")
    }

    // MARK: - Notification Authorization

    func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsAuthorized = settings.authorizationStatus == .authorized
    }

    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Theme Toggle

    func toggleTheme(_ theme: String) {
        if preferredThemes.contains(theme) {
            preferredThemes.removeAll { $0 == theme }
        } else {
            preferredThemes.append(theme)
        }
        save()
    }

    // MARK: - Clear Verse History

    func clearVerseHistory() {
        do {
            try modelContext.delete(model: VerseDelivery.self)
            try modelContext.delete(model: CachedVerse.self)
            try modelContext.save()
            clearHistorySuccess = true
            logger.info("Verse history cleared")
        } catch {
            logger.error("Clear history failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Watch Settings Update

    func sendSettingsUpdateToWatch() {
        let payload: [String: Any] = [
            "type": WatchMessage.MessageType.settingsUpdate.rawValue,
            "bibleID": preferredBibleID,
            "bibleAbbreviation": preferredBibleAbbreviation,
            "notificationStyle": notificationStyle,
            "maxDailyVerses": maxDailyVerses
        ]
        // PhoneSessionManager sends via transferUserInfo (guaranteed delivery)
        // The watch currently ignores this payload; wired for future use.
        phoneSessionManager.sendSettingsUpdate(payload)
    }

    // MARK: - Helpers

    var selectedTranslationDisplay: String {
        preferredBibleAbbreviation.isEmpty ? DefaultBible.abbreviation : preferredBibleAbbreviation
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    static let allThemes: [String] = [
        "Peace", "Strength", "Hope", "Guidance",
        "Praise", "Rest", "Love", "Purpose"
    ]

    static let maxVersesOptions: [(label: String, value: Int)] = [
        ("1", 1),
        ("2", 2),
        ("3", 3),
        ("5", 5),
        ("Unlimited", 999)
    ]

    static let notificationStyleOptions: [(label: String, value: String)] = [
        ("Title Only", "title_only"),
        ("With Reference", "with_reference"),
        ("Full", "full")
    ]

    private func fallbackTranslations() -> [BibleVersion] {
        [BibleVersion(id: DefaultBible.id, abbreviation: DefaultBible.abbreviation, title: DefaultBible.title)]
    }
}
