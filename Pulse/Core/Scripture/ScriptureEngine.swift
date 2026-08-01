import Foundation
import SwiftData
import WidgetKit
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "ScriptureEngine")

// MARK: - ScriptureEngine

/// Coordinates the full verse-delivery pipeline: Gloo AI selection → YouVersion fetch
/// → SwiftData persistence → Notification → Widget reload.
///
/// Full fallback chain on any live failure:
///   1. Gloo fails → `FallbackVerseProvider.fallbackReference(for:)`
///   2. Try cache for that reference
///   3. Try YouVersion fetch
///   4. Emergency verse (bundled JSON / hardcoded Matthew 11:28)
///
/// Every path produces a `VerseDelivery`; nothing is swallowed silently.
@Observable
@MainActor
final class ScriptureEngine {

    // MARK: - Published State

    var currentDelivery: VerseDelivery?
    var isLoading = false

    // MARK: - Hooks

    /// Set by Task 11 (PhoneSessionManager) to relay deliveries to the Watch.
    var onDelivery: ((VerseDelivery) -> Void)?

    // MARK: - Dependencies

    private let cache: VerseCache
    private let scheduler: DeliveryScheduler
    private let verseSelector: any VerseSelecting
    private let verseFetcher: any VerseFetching
    private let fallback: FallbackVerseProvider
    private let notificationService: NotificationService

    /// Preferred bible ID (YouVersion numeric) — sourced from `UserPreferences`.
    /// Updated in-session via `reconfigure(bibleID:abbreviation:)` after onboarding.
    private var preferredBibleID: Int
    private var preferredBibleAbbreviation: String

    // MARK: - Init

    init(
        cache: VerseCache,
        scheduler: DeliveryScheduler,
        verseSelector: any VerseSelecting,
        verseFetcher: any VerseFetching,
        fallback: FallbackVerseProvider = FallbackVerseProvider(),
        notificationService: NotificationService = .shared,
        preferredBibleID: Int = DefaultBible.id,
        preferredBibleAbbreviation: String = DefaultBible.abbreviation
    ) {
        self.cache = cache
        self.scheduler = scheduler
        self.verseSelector = verseSelector
        self.verseFetcher = verseFetcher
        self.fallback = fallback
        self.notificationService = notificationService
        self.preferredBibleID = preferredBibleID
        self.preferredBibleAbbreviation = preferredBibleAbbreviation
    }

    // MARK: - Pipeline Entry Points

    /// Called by `HealthEngine.onClassification`. Checks scheduler rules before delivering.
    func processStateChange(_ result: ClassificationResult) async {
        guard scheduler.shouldDeliver(for: result) else {
            logger.info("Delivery skipped by scheduler for state: \(result.state.rawValue, privacy: .public)")
            return
        }
        await runPipeline(result: result)
    }

    /// Onboarding / debug path — bypasses scheduler rules. Always yields a verse.
    /// Pass `mockState` to override the biometric state used for verse selection (used by -PulseMockState).
    @discardableResult
    func deliverFirstVerse(mockState: BiometricState? = nil) async -> VerseDelivery {
        let result = makeSyntheticResult(state: mockState)
        return await runPipeline(result: result)
    }

    /// Updates the active bible translation used for all subsequent fetch calls.
    /// Called by `OnboardingViewModel.finish()` after the user picks a translation,
    /// so the first verse delivered in-session uses the chosen bible.
    func reconfigure(bibleID: Int, abbreviation: String) {
        preferredBibleID = bibleID
        preferredBibleAbbreviation = abbreviation
        logger.info("ScriptureEngine reconfigured: \(abbreviation, privacy: .public) (id=\(bibleID, privacy: .public))")
    }

    // MARK: - Core Pipeline

    /// Runs the full pipeline. Returns the persisted `VerseDelivery`.
    @discardableResult
    private func runPipeline(result: ClassificationResult) async -> VerseDelivery {
        isLoading = true
        defer { isLoading = false }

        let isOffline = AppConfig.forceOffline || !AppConfig.isConfigured

        if isOffline {
            logger.info("Offline mode — using fallback for state: \(result.state.rawValue, privacy: .public)")
            let delivery = await offlineDelivery(result: result)
            await persistDelivery(delivery)
            return delivery
        }

        // --- Live path ---
        do {
            let selection = try await fetchGlooSelection(for: result)
            let verse = try await fetchVerse(reference: selection.reference)
            let delivery = makeDelivery(
                verse: verse,
                result: result,
                theme: selection.theme,
                themeDisplayName: selection.themeDisplayName,
                rationale: selection.rationale,
                isOfflineFallback: selection.isFallback
            )
            await persistDelivery(delivery)
            return delivery
        } catch {
            logger.warning("Live pipeline failed (\(error.localizedDescription, privacy: .public)) — entering fallback chain")
            let delivery = await fallbackChain(result: result)
            await persistDelivery(delivery)
            return delivery
        }
    }

    // MARK: - Gloo Selection

    private func fetchGlooSelection(for result: ClassificationResult) async throws -> VerseSelection {
        let recentRefs = cache.recentReferences(limit: 10)
        let context = VerseSelectionContext(
            state: result.state,
            timeOfDay: TimeOfDay(date: .now),
            confidence: result.confidence,
            recentStates: [],
            translationAbbreviation: preferredBibleAbbreviation,
            preferredThemes: [],
            avoidRepeats: recentRefs
        )
        return try await verseSelector.selectVerse(for: context)
    }

    // MARK: - Verse Fetching

    private func fetchVerse(reference: String) async throws -> BibleVerse {
        // Cache first
        if let cached = cache.verse(reference: reference, translationAbbreviation: preferredBibleAbbreviation) {
            return cached
        }
        // Fetch from YouVersion
        let verse = try await verseFetcher.fetchVerse(
            reference: reference,
            bibleID: preferredBibleID,
            abbreviation: preferredBibleAbbreviation
        )
        cache.store(verse)
        return verse
    }

    // MARK: - Fallback Chain

    /// Full fallback chain: fallbackReference → cache → YouVersion → emergency verse.
    private func fallbackChain(result: ClassificationResult) async -> VerseDelivery {
        let fallbackRef = FallbackVerseProvider.fallbackReference(for: result.state)

        // Try cache for fallback ref
        if let cached = cache.verse(reference: fallbackRef, translationAbbreviation: preferredBibleAbbreviation) {
            return makeDelivery(
                verse: cached,
                result: result,
                theme: result.state.verseTheme,
                themeDisplayName: result.state.displayName,
                rationale: "Fallback (cache hit)",
                isOfflineFallback: true
            )
        }

        // Try YouVersion for fallback ref
        if let fetched = try? await verseFetcher.fetchVerse(
            reference: fallbackRef,
            bibleID: preferredBibleID,
            abbreviation: preferredBibleAbbreviation
        ) {
            cache.store(fetched)
            return makeDelivery(
                verse: fetched,
                result: result,
                theme: result.state.verseTheme,
                themeDisplayName: result.state.displayName,
                rationale: "Fallback (YouVersion)",
                isOfflineFallback: true
            )
        }

        // Emergency verse
        logger.warning("All live/cache paths failed — using emergency verse")
        return await offlineDelivery(result: result)
    }

    /// Returns a delivery using the bundled emergency verse (no network needed).
    private func offlineDelivery(result: ClassificationResult) async -> VerseDelivery {
        let verse = fallback.emergencyVerse(for: result.state)
        return makeDelivery(
            verse: verse,
            result: result,
            theme: result.state.verseTheme,
            themeDisplayName: result.state.displayName,
            rationale: "Emergency offline fallback",
            isOfflineFallback: true
        )
    }

    // MARK: - Delivery Construction

    private func makeDelivery(
        verse: BibleVerse,
        result: ClassificationResult,
        theme: String,
        themeDisplayName: String,
        rationale: String?,
        isOfflineFallback: Bool
    ) -> VerseDelivery {
        let snapshot = result.snapshot
        let delivery = VerseDelivery(
            id: UUID(),
            verseID: verse.id,
            verseReference: verse.reference,
            verseText: verse.text,
            translationAbbreviation: verse.translationAbbreviation,
            verseTheme: theme,
            themeDisplayName: themeDisplayName,
            biometricStateRaw: result.state.rawValue,
            stateConfidence: result.confidence,
            stateBodyText: result.state.bodyInterpretation,
            deliveredAt: .now,
            deliveryMethod: "notification",
            wasPostWorkout: result.state == .energizedPostWorkout,
            isOfflineFallback: isOfflineFallback
        )
        delivery.heartRateAtDelivery = snapshot.heartRate
        delivery.hrvAtDelivery = snapshot.heartRateVariability
        delivery.restingHRAtDelivery = snapshot.restingHeartRate
        delivery.oxygenAtDelivery = snapshot.oxygenSaturation
        delivery.sleepEfficiencyAtDelivery = snapshot.sleepEfficiency
        delivery.deepSleepAtDelivery = snapshot.deepSleepMinutes // minutes; see PulseSchema.swift
        delivery.stepCountAtDelivery = snapshot.stepCount
        delivery.glooRationale = rationale
        delivery.workoutTypeAtDelivery = snapshot.lastWorkoutType
        return delivery
    }

    // MARK: - Persistence & Side-Effects

    private func persistDelivery(_ delivery: VerseDelivery) async {
        cache.saveDelivery(delivery)
        currentDelivery = delivery

        // Notify Watch (Task 11 hook)
        onDelivery?(delivery)

        // Local notification
        await notificationService.scheduleVerseNotification(delivery)

        // Widget / complication update
        WidgetKit.WidgetCenter.shared.reloadAllTimelines()

        logger.info(
            "Delivered: \(delivery.verseReference, privacy: .public) [\(delivery.isOfflineFallback ? "offline" : "live", privacy: .public)]"
        )
    }

    // MARK: - Synthetic ClassificationResult (for deliverFirstVerse)

    private func makeSyntheticResult(state: BiometricState? = nil) -> ClassificationResult {
        // Construct a minimal stub when no real HealthEngine state is available.
        let snapshot = HealthSnapshot(
            dataCompleteness: 1.0
        )
        let hour = Calendar.current.component(.hour, from: .now)
        return ClassificationResult(
            state: state ?? .peacefulSteady,
            confidence: 1.0,
            snapshot: snapshot,
            subScores: BiometricSubScores(
                hrStress: 0.5,
                hrvRecovery: 0.5,
                sleepQuality: 0.5,
                oxygenLevel: 0.5,
                activityLevel: 0.5,
                respiratoryStress: 0.5,
                timeOfDay: TimeOfDay(hour: hour)
            )
        )
    }
}
