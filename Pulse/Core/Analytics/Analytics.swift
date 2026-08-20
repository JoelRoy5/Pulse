import Foundation
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "Analytics")

// MARK: - Analytics

/// PostHog batch transport. All public methods are `@MainActor`; network is
/// dispatched onto background Tasks so the main thread is never blocked.
@MainActor
final class Analytics {

    // MARK: - Shared

    static let shared = Analytics()

    // MARK: - Constants

    private enum Keys {
        static let installID = "pulse.analytics.installID"
    }

    private static let queueCapacity = 500
    private static let queueBatchSize = 20
    private static let autoFlushThreshold = 20
    private static let timerInterval: TimeInterval = 30

    // MARK: - State

    /// Whether analytics tracking is active. Set to `false` by the opt-out
    /// setting (wired in a later task). `track(_:)` is a no-op when false.
    var isEnabled: Bool = true

    private let distinctID: String
    private let queue: AnalyticsQueue
    private let queueURL: URL
    private let appVersion: String
    private var flushTimer: Timer?

    // MARK: - Init

    private init() {
        // Resolve (or generate) a stable install identifier
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: Keys.installID), !stored.isEmpty {
            distinctID = stored
        } else {
            let new = UUID().uuidString
            defaults.set(new, forKey: Keys.installID)
            distinctID = new
        }

        // Resolve Application Support directory
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory

        queueURL = appSupport.appendingPathComponent("analytics-queue.json")

        // Load persisted queue
        queue = AnalyticsQueue.load(
            from: queueURL,
            capacity: Analytics.queueCapacity,
            batchSize: Analytics.queueBatchSize
        )

        // Read app version from bundle
        appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"

        // Start periodic flush timer
        startFlushTimer()
    }

    // MARK: - Timer

    private func startFlushTimer() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: Analytics.timerInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.flush()
            }
        }
    }

    // MARK: - Public API

    /// Enable or disable analytics tracking.
    ///
    /// When turning **OFF**: emits `analyticsOptOut`, flushes the queue so
    /// the opt-out event is delivered, then sets `isEnabled = false` and
    /// clears any remaining queued events.
    ///
    /// When turning **ON**: sets `isEnabled = true` (future events are tracked).
    func setEnabled(_ on: Bool) {
        if on {
            isEnabled = true
        } else {
            // 1. Emit the opt-out event while still enabled.
            track(.analyticsOptOut)
            // 2. Flush so the event is sent before we go dark.
            let url = queueURL
            Task { [weak self] in
                await self?.flush()
                // 3. Disable and clear any remaining events.
                await MainActor.run { [weak self] in
                    self?.isEnabled = false
                    self?.queue.clear()
                    self?.queue.persist(to: url)
                }
            }
        }
    }

    /// Record a discrete analytics event. No-ops when analytics is disabled or
    /// PostHog is not configured (no key set).
    func track(_ event: AnalyticsEvent) {
        guard isEnabled, AnalyticsConfig.isConfigured else { return }

        let payload = event.payload(
            distinctID: distinctID,
            appVersion: appVersion,
            platform: "ios",
            timestamp: Date().timeIntervalSince1970
        )

        guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
            logger.debug("Analytics: failed to JSON-encode event '\(event.name, privacy: .public)'")
            return
        }

        queue.enqueue(data)
        queue.persist(to: queueURL)

        if queue.count >= Analytics.autoFlushThreshold {
            Task { await flush() }
        }
    }

    /// Send all queued events to PostHog in a single batch request.
    /// On 2xx response the sent events are removed; on failure they remain
    /// queued for the next attempt. Never throws or crashes.
    func flush() async {
        guard AnalyticsConfig.isConfigured else { return }

        let batch = queue.makeBatch()
        guard !batch.isEmpty else { return }

        let key = AnalyticsConfig.postHogKey
        let host = AnalyticsConfig.postHogHost

        // Decode each Data blob back to a dictionary for the batch body
        let payloads: [[String: Any]] = batch.compactMap { data in
            (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }

        guard !payloads.isEmpty else {
            // All items were corrupt — discard them
            queue.removeBatch(count: batch.count)
            queue.persist(to: queueURL)
            return
        }

        let body: [String: Any] = [
            "api_key": key,
            "batch": payloads
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            logger.debug("Analytics: failed to encode batch body")
            return
        }

        guard let url = URL(string: "\(host)/batch/") else {
            logger.debug("Analytics: invalid PostHog host '\(host, privacy: .public)'")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                queue.removeBatch(count: batch.count)
                queue.persist(to: queueURL)
                logger.debug("Analytics: flushed \(batch.count) event(s)")
            } else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                logger.debug("Analytics: flush failed with HTTP \(code) — events remain queued")
            }
        } catch {
            logger.debug("Analytics: flush error — \(error.localizedDescription, privacy: .public)")
        }
    }
}
