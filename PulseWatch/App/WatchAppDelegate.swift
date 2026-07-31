import WatchKit
import WidgetKit
import PulseShared
import os.log

private let logger = Logger(subsystem: "com.joelroy.pulse.watchkitapp", category: "WatchAppDelegate")

// MARK: - WatchAppDelegate

final class WatchAppDelegate: NSObject, WKApplicationDelegate {

    // MARK: - Background Tasks

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {

            case let refreshTask as WKApplicationRefreshBackgroundTask:
                // Request latest verse from phone and reschedule.
                Task {
                    await WatchSessionManager.shared.requestLatestVerse()
                    self.scheduleNextRefresh()
                    refreshTask.setTaskCompletedWithSnapshot(false)
                }

            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Update complication / widget snapshot.
                WidgetCenter.shared.reloadAllTimelines()
                snapshotTask.setTaskCompleted(
                    restoredDefaultState: true,
                    estimatedSnapshotExpiration: Date(timeIntervalSinceNow: 3600),
                    userInfo: nil
                )

            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Process any pending WatchConnectivity transfers.
                WatchSessionManager.shared.handleBackgroundConnectivity()
                connectivityTask.setTaskCompletedWithSnapshot(false)

            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    // MARK: - Schedule Next Background Refresh

    private func scheduleNextRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date(timeIntervalSinceNow: 15 * 60),
            userInfo: nil
        ) { error in
            if let error {
                logger.warning("scheduleBackgroundRefresh failed: \(error.localizedDescription, privacy: .public)")
            } else {
                logger.debug("Background refresh scheduled for 15 min from now")
            }
        }
    }
}
