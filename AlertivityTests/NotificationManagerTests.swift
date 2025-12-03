import Testing
import Foundation
import UserNotifications
@testable import Alertivity

private final class CapturingNotificationCenter: UserNotificationCentering {
    var delegate: UNUserNotificationCenterDelegate?
    var requests: [UNNotificationRequest] = []
    var categories: Set<UNNotificationCategory> = []
    var authorizationRequested = false

    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void) {
        authorizationRequested = true
        completionHandler(true, nil)
    }

    func notificationSettings() async -> UNNotificationSettings {
        fatalError("notificationSettings should not be called in tests using a custom authorizationStatusProvider")
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        self.categories = categories
    }

    func add(_ request: UNNotificationRequest, withCompletionHandler: ((Error?) -> Void)?) {
        requests.append(request)
        withCompletionHandler?(nil)
    }
}

@Suite struct NotificationManagerTests {
    @Test
    func criticalNotificationsRespectDwell() {
        let center = CapturingNotificationCenter()
        var now = Date()
        let manager = NotificationManager(
            notificationCenter: center,
            now: { now },
            authorizationStatusProvider: { .authorized },
            initialAuthorizationStatus: .authorized
        )
        manager.highActivityDuration = 2

        let metrics = makeMetrics(cpu: 0.9, memory: 0.4)
        let status = ActivityStatus(metrics: metrics)

        manager.postNotificationIfNeeded(for: status, metrics: metrics)
        expectTrue(center.requests.isEmpty)

        now = now.addingTimeInterval(1)
        manager.postNotificationIfNeeded(for: status, metrics: metrics)
        expectTrue(center.requests.isEmpty)

        now = now.addingTimeInterval(1.2)
        manager.postNotificationIfNeeded(for: status, metrics: metrics)
        expectEqual(center.requests.count, 1)
    }

    @Test
    func highActivityProcessNotificationsIncludeMetadata() {
        let center = CapturingNotificationCenter()
        let now = Date()
        let manager = NotificationManager(
            notificationCenter: center,
            now: { now },
            authorizationStatusProvider: { .authorized },
            initialAuthorizationStatus: .authorized
        )
        manager.highActivityDuration = 30

        let process = ProcessUsage(
            pid: 4242,
            command: "/Applications/Safari.app/Contents/MacOS/Safari",
            cpuPercent: 0.72,
            memoryPercent: 0.12,
            triggers: [.cpu]
        )

        let metrics = ActivityMetrics(
            cpuUsage: 0.4,
            memoryUsed: Measurement(value: 6, unit: .gigabytes),
            memoryTotal: Measurement(value: 16, unit: .gigabytes),
            runningProcesses: 80,
            network: .zero,
            disk: .zero,
            highActivityProcesses: [process]
        )

        let status = ActivityStatus(metrics: metrics)
        manager.postNotificationIfNeeded(for: status, metrics: metrics)

        expectEqual(center.requests.count, 1)
        let content = center.requests.first?.content
        expectEqual(content?.subtitle, process.displayName)
        expectTrue(content?.body.contains("CPU") ?? false)
        expectEqual(content?.userInfo["pid"] as? NSNumber, NSNumber(value: process.pid))
    }

    @Test
    func unauthorizedStatusPreventsNotifications() {
        let center = CapturingNotificationCenter()
        let manager = NotificationManager(
            notificationCenter: center,
            now: Date.init,
            authorizationStatusProvider: { .denied },
            initialAuthorizationStatus: .denied
        )

        let metrics = makeMetrics(cpu: 0.95, memory: 0.2)
        let status = ActivityStatus(metrics: metrics)
        manager.highActivityDuration = 0

        manager.postNotificationIfNeeded(for: status, metrics: metrics)
        expectTrue(center.requests.isEmpty)
    }
}
