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
        guard authorizationStatus == .authorized else { return }
        let hasHighActivityProcess = !metrics.highActivityProcesses.isEmpty
        guard status == .critical || hasHighActivityProcess else { return }

        let now = Date()
        if let last = lastNotificationDate, now.timeIntervalSince(last) < throttleInterval {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = status.title
        content.body = status.message(for: metrics)
        content.sound = .default
        if let culprit = metrics.highActivityProcesses.first {
            content.subtitle = "\(culprit.displayName) is using \(culprit.cpuDescription)"
            content.userInfo = [
                "pid": NSNumber(value: culprit.pid),
                "command": culprit.command,
                "cpu": culprit.cpuPercent,
                "memory": culprit.memoryPercent
            ]
            content.categoryIdentifier = Category.criticalProcess
        }

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
