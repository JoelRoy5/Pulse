import Foundation
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse.watch", category: "WatchAnalytics")

// MARK: - WatchAnalytics

/// Lightweight analytics forwarder for the Apple Watch target.
/// Uses the same PostHog batch endpoint and AnalyticsQueue as the iOS app.
/// All public methods are `@MainActor`; network is dispatched onto background Tasks.
@MainActor
final class WatchAnalytics {

    // MARK: - Shared

    static let shared = WatchAnalytics()

    // MARK: - Constants

    private enum Keys {
        static let installID = "pulse.analytics.installID"
    }

    private static let queueCapacity = 200
    private static let queueBatchSize = 10

    // MARK: - State

    private let distinctID: String
    private let queue: AnalyticsQueue
    private let queueURL: URL
    private let appVersion: String

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: Keys.installID), !stored.isEmpty {
            distinctID = stored
        } else {
            let new = UUID().uuidString
            defaults.set(new, forKey: Keys.installID)
            distinctID = new
        }

        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory

        queueURL = appSupport.appendingPathComponent("watch-analytics-queue.json")
        queue = AnalyticsQueue.load(
            from: queueURL,
            capacity: WatchAnalytics.queueCapacity,
            batchSize: WatchAnalytics.queueBatchSize
        )

        appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    // MARK: - Public API

    func track(_ event: AnalyticsEvent) {
        let postHogKey = Bundle.main.object(forInfoDictionaryKey: "PostHogKey") as? String ?? ""
        guard !postHogKey.isEmpty, !postHogKey.contains("your_") else { return }

        let payload = event.payload(
            distinctID: distinctID,
            appVersion: appVersion,
            platform: "watchos",
            timestamp: Date().timeIntervalSince1970
        )

        guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
            logger.debug("WatchAnalytics: failed to encode event '\(event.name, privacy: .public)'")
            return
        }

        queue.enqueue(data)
        queue.persist(to: queueURL)

        Task { await flush() }
    }

    // MARK: - Flush

    func flush() async {
        let postHogKey = Bundle.main.object(forInfoDictionaryKey: "PostHogKey") as? String ?? ""
        guard !postHogKey.isEmpty, !postHogKey.contains("your_") else { return }

        let postHogHost: String = {
            let h = Bundle.main.object(forInfoDictionaryKey: "PostHogHost") as? String ?? ""
            return h.isEmpty ? "https://us.i.posthog.com" : h
        }()

        let batch = queue.makeBatch()
        guard !batch.isEmpty else { return }

        let payloads: [[String: Any]] = batch.compactMap { data in
            (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
        guard !payloads.isEmpty else {
            queue.removeBatch(count: batch.count)
            queue.persist(to: queueURL)
            return
        }

        let body: [String: Any] = ["api_key": postHogKey, "batch": payloads]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
              let url = URL(string: "\(postHogHost)/batch/") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                queue.removeBatch(count: batch.count)
                queue.persist(to: queueURL)
            }
        } catch {
            logger.debug("WatchAnalytics: flush error — \(error.localizedDescription, privacy: .public)")
        }
    }
}
