import Testing
import Foundation
import UserNotifications
@testable import Alertivity

private final class CapturingNotificationCenter: UserNotificationCentering {
    var delegate: UNUserNotificationCenterDelegate?
    var requests: [UNNotificationRequest] = []
    var categories: Set<UNNotificationCategory> = []
    var authorizationRequested = false
    var authorizationError: Error?
    var authorizationGranted = true

    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void) {
        authorizationRequested = true
        completionHandler(authorizationGranted, authorizationError)
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
    @Test @MainActor
    func authorizationIsExplicitAndUsesFreshStatus() async {
        let center = CapturingNotificationCenter()
        let manager = NotificationManager(
            notificationCenter: center,
            authorizationStatusProvider: { .denied },
            initialAuthorizationStatus: .notDetermined
        )
        expectFalse(center.authorizationRequested)
        await manager.requestAuthorization()
        expectFalse(center.authorizationRequested)
        expectEqual(manager.authorizationStatus, .denied)
        expectFalse(manager.isRequestingAuthorization)
    }

    @Test(arguments: [true, false]) @MainActor
    func undeterminedPermissionCanBeRequestedExplicitly(granted: Bool) async {
        let center = CapturingNotificationCenter()
        center.authorizationGranted = granted
        let manager = NotificationManager(
            notificationCenter: center,
            authorizationStatusProvider: { center.authorizationRequested ? (granted ? .authorized : .denied) : .notDetermined }
        )
        expectFalse(center.authorizationRequested)
        await manager.requestAuthorization()
        expectTrue(center.authorizationRequested)
        expectFalse(manager.authorizationFailed)
        expectEqual(manager.authorizationStatus, granted ? .authorized : .denied)
    }

    @Test @MainActor
    func authorizationFailureCanBeRetried() async {
        let center = CapturingNotificationCenter()
        center.authorizationError = NSError(domain: "NotificationTest", code: 1)
        let manager = NotificationManager(
            notificationCenter: center,
            authorizationStatusProvider: { .notDetermined }
        )
        await manager.requestAuthorization()
        expectTrue(manager.authorizationFailed)
        expectFalse(manager.isRequestingAuthorization)
        center.authorizationError = nil
        await manager.requestAuthorization()
        expectFalse(manager.authorizationFailed)
    }

    @Test @MainActor
    func permissionGrantedExternallyClearsRequestError() async {
        let center = CapturingNotificationCenter()
        center.authorizationError = NSError(domain: "NotificationTest", code: 1)
        let manager = NotificationManager(
            notificationCenter: center,
            authorizationStatusProvider: { center.authorizationError == nil ? .authorized : .notDetermined }
        )
        await manager.requestAuthorization()
        expectTrue(manager.authorizationFailed)
        center.authorizationError = nil
        await manager.refreshAuthorizationStatus()
        expectEqual(manager.authorizationStatus, .authorized)
        expectFalse(manager.authorizationFailed)
    }

    @Test
    func processNotificationCategoryIncludesIgnoreAction() {
        let center = CapturingNotificationCenter()
        _ = NotificationManager(
            notificationCenter: center,
            authorizationStatusProvider: { .authorized },
            initialAuthorizationStatus: .authorized
        )

        let actionIdentifiers = center.categories.flatMap(\.actions).map(\.identifier)
        expectTrue(actionIdentifiers.contains("enhancedActivityMonitor.ignoreProcess"))
    }

    @Test(arguments: [1, 5, 10, 15, 30, 60])
    func notificationCooldownUsesConfiguredInterval(minutes: Int) {
        let center = CapturingNotificationCenter()
        var now = Date()
        let manager = NotificationManager(
            notificationCenter: center,
            now: { now },
            authorizationStatusProvider: { .authorized },
            initialAuthorizationStatus: .authorized
        )
        expectEqual(manager.notificationCooldown, 600)
        manager.notificationCooldown = TimeInterval(minutes * 60)
        manager.highActivityDuration = 0
        let cpu = makeMetrics(cpu: 0.95, memory: 0.2)
        let memory = makeMetrics(cpu: 0.2, memory: 0.95)
        manager.postNotificationIfNeeded(for: ActivityStatus(metrics: cpu), metrics: cpu)
        expectEqual(center.requests.count, 1)
        now = now.addingTimeInterval(TimeInterval(minutes * 60) - 1)
        manager.postNotificationIfNeeded(for: ActivityStatus(metrics: memory), metrics: memory)
        expectEqual(center.requests.count, 1)
        now = now.addingTimeInterval(1)
        manager.postNotificationIfNeeded(for: ActivityStatus(metrics: memory), metrics: memory)
        expectEqual(center.requests.count, 2)
    }

    @Test
    func changingCooldownPreservesLastNotificationTime() {
        let center = CapturingNotificationCenter()
        var now = Date()
        let manager = NotificationManager(
            notificationCenter: center,
            now: { now },
            authorizationStatusProvider: { .authorized },
            initialAuthorizationStatus: .authorized
        )
        manager.highActivityDuration = 0
        let metrics = makeMetrics(cpu: 0.95, memory: 0.2)
        let status = ActivityStatus(metrics: metrics)
        manager.postNotificationIfNeeded(for: status, metrics: metrics)
        now = now.addingTimeInterval(300)
        manager.notificationCooldown = 1800
        manager.postNotificationIfNeeded(for: status, metrics: metrics)
        expectEqual(center.requests.count, 1)
        manager.notificationCooldown = 60
        manager.postNotificationIfNeeded(for: status, metrics: metrics)
        expectEqual(center.requests.count, 2)
        manager.postNotificationIfNeeded(for: status, metrics: metrics)
        expectEqual(center.requests.count, 2)
    }

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
    func diskCriticalNotificationsRespectDwell() {
        let center = CapturingNotificationCenter()
        var now = Date()
        let manager = NotificationManager(
            notificationCenter: center,
            now: { now },
            authorizationStatusProvider: { .authorized },
            initialAuthorizationStatus: .authorized
        )
        manager.highActivityDuration = 2

        let metrics = makeMetrics(cpu: 0.1, memory: 0.1, diskBytesPerSecond: 150_000_000)
        let status = ActivityStatus(metrics: metrics)

        manager.postNotificationIfNeeded(for: status, metrics: metrics)
        expectTrue(center.requests.isEmpty)

        now = now.addingTimeInterval(2.1)
        manager.postNotificationIfNeeded(for: status, metrics: metrics)
        expectEqual(center.requests.count, 1)
        expectEqual(center.requests.first?.content.userInfo["triggerMetric"] as? String, "disk")
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

    @Test
    func notificationEvaluationUsesConfiguredThresholds() {
        let center = CapturingNotificationCenter()
        let manager = NotificationManager(
            notificationCenter: center,
            authorizationStatusProvider: { .authorized },
            initialAuthorizationStatus: .authorized
        )
        manager.highActivityDuration = 0

        guard let thresholds = ActivityThresholds(
            cpuElevatedPercent: 20,
            cpuCriticalPercent: 35,
            memoryElevatedPercent: 70,
            memoryCriticalPercent: 85,
            diskElevatedMegabytesPerSecond: 30,
            diskCriticalMegabytesPerSecond: 120,
            networkElevatedMegabytesPerSecond: 5,
            networkCriticalMegabytesPerSecond: 20
        ) else {
            Issue.record("Expected valid custom thresholds")
            return
        }
        var metrics = makeMetrics(cpu: 0.4, memory: 0.2)
        metrics.thresholds = thresholds

        manager.postNotificationIfNeeded(for: ActivityStatus(metrics: metrics), metrics: metrics)
        expectEqual(center.requests.count, 1)
        expectEqual(center.requests.first?.content.userInfo["triggerMetric"] as? String, "cpu")
    }
}
