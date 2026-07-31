import UIKit
import BackgroundTasks
import UserNotifications
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse", category: "AppDelegate")

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register BGProcessingTask for the health-check pipeline
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.joelroy.pulse.health-check",
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self.handleHealthCheckTask(processingTask)
        }

        // Wire UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = NotificationService.shared

        logger.info("AppDelegate: BGTask registered, notification delegate wired")
        return true
    }

    // MARK: - BGProcessingTask Handler

    private func handleHealthCheckTask(_ task: BGProcessingTask) {
        // Schedule the next run immediately so it survives this invocation
        scheduleHealthCheckTask()

        // Expiration handler — mark incomplete if system reclaims time
        task.expirationHandler = {
            logger.warning("BGProcessingTask expired before completion")
            task.setTaskCompleted(success: false)
        }

        Task { @MainActor in
            // AppBridge.healthEngine is nil on a cold background launch (the SwiftUI
            // .task that sets it has not yet run). In that case report failure so the
            // system can retry; we still reschedule above so the next window is set.
            guard let engine = AppBridge.shared.healthEngine else {
                logger.warning("BGProcessingTask: healthEngine nil (cold-launch) — reporting failure")
                task.setTaskCompleted(success: false)
                return
            }
            // Refresh health data → triggers onClassification → ScriptureEngine pipeline
            await engine.refresh()
            task.setTaskCompleted(success: true)
            logger.info("BGProcessingTask completed")
        }
    }

    // MARK: - BGTask Scheduling

    /// Submits the next `com.joelroy.pulse.health-check` BGProcessingTask.
    /// Call this at launch and after each handler completes.
    static func scheduleHealthCheckTask() {
        let request = BGProcessingTaskRequest(identifier: "com.joelroy.pulse.health-check")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        request.requiresNetworkConnectivity = true

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.debug("BGProcessingTask scheduled for 15 min from now")
        } catch {
            logger.warning("Failed to schedule BGProcessingTask: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func scheduleHealthCheckTask() {
        Self.scheduleHealthCheckTask()
    }
}

// MARK: - AppBridge

/// Lightweight bridge that lets AppDelegate reference the engine instances
/// created in `PulseApp` without circular imports.
@MainActor
final class AppBridge {
    static let shared = AppBridge()
    private init() {}

    weak var healthEngine: HealthEngine?
}
