import Foundation
import UserNotifications

final class NotificationManager: NSObject, ObservableObject {
    private let notificationCenter = UNUserNotificationCenter.current()
    private var lastNotificationDate: Date?
    private let throttleInterval: TimeInterval = 60 * 10
    private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private enum Category {
        static let criticalProcess = "enhancedActivityMonitor.criticalProcess"
    }

    private enum Action {
        static let focusProcess = "enhancedActivityMonitor.focusProcess"
        static let killProcess = "enhancedActivityMonitor.killProcess"
    }

    override init() {
        super.init()
        notificationCenter.delegate = self
        configureCategories()
        Task {
            await refreshAuthorizationStatus()
        }
    }

    func requestAuthorizationIfNeeded() {
        guard authorizationStatus == .notDetermined else { return }
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            Task { await self?.refreshAuthorizationStatus() }
            if !granted {
                self?.lastNotificationDate = nil
            }
        }
    }

    func postNotificationIfNeeded(for status: ActivityStatus, metrics: ActivityMetrics) {
        let isAuthorized: Bool
        switch authorizationStatus {
        case .authorized, .provisional:
            isAuthorized = true
        default:
            isAuthorized = false
        }
        guard isAuthorized else { return }
        let hasHighActivityProcess = !metrics.highActivityProcesses.isEmpty

        let shouldNotifyForCriticalState: Bool
        if status.level == .critical, let trigger = status.trigger {
            shouldNotifyForCriticalState = trigger == .cpu || trigger == .memory
        } else {
            shouldNotifyForCriticalState = false
        }

        guard shouldNotifyForCriticalState || hasHighActivityProcess else { return }
        let trigger = status.trigger

        let now = Date()
        if let last = lastNotificationDate, now.timeIntervalSince(last) < throttleInterval {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = status.notificationTitle(for: metrics)
        content.body = status.message(for: metrics)
        content.sound = .default

        var userInfo: [String: Any] = [:]

        if let trigger {
            userInfo["triggerMetric"] = trigger.rawValue
        }
        if let value = status.triggerValue(for: metrics) {
            userInfo["triggerValue"] = value
        }

        if let culprit = metrics.highActivityProcesses.first, trigger != .disk {
            content.subtitle = "\(culprit.displayName) is using \(culprit.cpuDescription)"
            userInfo.merge([
                "pid": NSNumber(value: culprit.pid),
                "command": culprit.command,
                "cpu": culprit.cpuPercent,
                "memory": culprit.memoryPercent
            ]) { _, new in new }
            content.categoryIdentifier = Category.criticalProcess
        }

        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
        lastNotificationDate = now
    }

    @MainActor
    private func refreshAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    private func configureCategories() {
        let focus = UNNotificationAction(
            identifier: Action.focusProcess,
            title: "Show in Activity Monitor",
            options: [.foreground]
        )
        let kill = UNNotificationAction(
            identifier: Action.killProcess,
            title: "Force Quit Process",
            options: [.destructive]
        )

        let category = UNNotificationCategory(
            identifier: Category.criticalProcess,
            actions: [focus, kill],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([category])
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        let info = response.notification.request.content.userInfo
        guard
            let pidValue = (info["pid"] as? NSNumber)?.int32Value,
            let command = info["command"] as? String
        else { return }

        let cpu = (info["cpu"] as? NSNumber)?.doubleValue ?? 0
        let memory = (info["memory"] as? NSNumber)?.doubleValue ?? 0
        let process = ProcessUsage(
            pid: pidValue,
            command: command,
            cpuPercent: cpu,
            memoryPercent: memory
        )

        switch response.actionIdentifier {
        case Action.focusProcess, UNNotificationDefaultActionIdentifier:
            DispatchQueue.main.async {
                ProcessActions.revealInActivityMonitor(process)
            }
        case Action.killProcess:
            ProcessActions.terminate(process)
        default:
            break
        }
    }
}
