import Foundation
import UserNotifications

protocol UserNotificationCentering: AnyObject {
    var delegate: UNUserNotificationCenterDelegate? { get set }
    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping @Sendable (Bool, Error?) -> Void)
    func notificationSettings() async -> UNNotificationSettings
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    func add(_ request: UNNotificationRequest, withCompletionHandler: (@Sendable (Error?) -> Void)?)
}

extension UNUserNotificationCenter: UserNotificationCentering {}

final class NotificationManager: NSObject, ObservableObject {
    private let notificationCenter: UserNotificationCentering
    private var lastNotificationDate: Date?
    private let throttleInterval: TimeInterval = 60 * 10
    private var authorizationStatus: UNAuthorizationStatus
    var highActivityDuration: TimeInterval = 60
    private var criticalConditionStartDate: Date?
    private var criticalConditionSignature: CriticalSignature?
    private let now: () -> Date
    private let authorizationStatusProvider: (() async -> UNAuthorizationStatus)?

    private enum Category {
        static let criticalProcess = "enhancedActivityMonitor.criticalProcess"
    }

    private enum Action {
        static let focusProcess = "enhancedActivityMonitor.focusProcess"
        static let killProcess = "enhancedActivityMonitor.killProcess"
    }

    private struct CriticalSignature: Equatable {
        let trigger: ActivityStatus.TriggerMetric
    }

    init(
        notificationCenter: UserNotificationCentering = UNUserNotificationCenter.current(),
        now: @escaping () -> Date = Date.init,
        authorizationStatusProvider: (() async -> UNAuthorizationStatus)? = nil,
        initialAuthorizationStatus: UNAuthorizationStatus? = nil
    ) {
        self.notificationCenter = notificationCenter
        self.now = now
        self.authorizationStatusProvider = authorizationStatusProvider
        self.authorizationStatus = initialAuthorizationStatus ?? .notDetermined
        super.init()
        self.notificationCenter.delegate = self
        configureCategories()
        Task { await refreshAuthorizationStatus() }
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
        // Align status/title/content to the metrics snapshot we are notifying about to avoid mismatched summaries.
        let metricsStatus = ActivityStatus(metrics: metrics)
        let resolvedStatus = metricsStatus == status ? status : metricsStatus

        let isAuthorized: Bool
        switch authorizationStatus {
        case .authorized, .provisional:
            isAuthorized = true
        default:
            isAuthorized = false
        }
        guard isAuthorized else { return }
        let hasHighActivityProcess = !metrics.highActivityProcesses.isEmpty

        let hasCriticalDwell: Bool
        if resolvedStatus.level == .critical {
            hasCriticalDwell = evaluateCriticalDwell(for: resolvedStatus, metrics: metrics)
        } else {
            resetCriticalDwell()
            hasCriticalDwell = false
        }

        let shouldNotifyForCriticalState: Bool
        if resolvedStatus.level == .critical, let trigger = resolvedStatus.trigger {
            shouldNotifyForCriticalState = hasCriticalDwell && (trigger == .cpu || trigger == .memory || trigger == .disk)
        } else {
            shouldNotifyForCriticalState = false
        }

        guard shouldNotifyForCriticalState || hasHighActivityProcess else { return }
        let trigger = resolvedStatus.trigger

        let currentDate = now()
        if let last = lastNotificationDate, currentDate.timeIntervalSince(last) < throttleInterval {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = resolvedStatus.notificationTitle(for: metrics)
        content.body = hasHighActivityProcess ? "" : resolvedStatus.message(for: metrics)
        content.sound = .default

        var userInfo: [String: Any] = [:]

        if let trigger {
            userInfo["triggerMetric"] = trigger.rawValue
        }
        if let value = resolvedStatus.triggerValue(for: metrics) {
            userInfo["triggerValue"] = value
        }

        if let culprit = metrics.highActivityProcesses.first {
            content.subtitle = culprit.displayName
            content.body = metricDescription(for: culprit)
            userInfo.merge([
                "pid": NSNumber(value: culprit.pid),
                "command": culprit.command,
                "cpu": culprit.cpuPercent,
                "memory": culprit.memoryPercent,
                "triggers": Array(culprit.triggers.map(\.rawValue))
            ]) { _, new in new }
            content.categoryIdentifier = Category.criticalProcess
        }

        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        notificationCenter.add(request, withCompletionHandler: nil)
        lastNotificationDate = currentDate
    }

    @MainActor
    private func refreshAuthorizationStatus() async {
        if let authorizationStatusProvider {
            authorizationStatus = await authorizationStatusProvider()
            return
        }

        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    private func configureCategories() {
        let focus = UNNotificationAction(
            identifier: Action.focusProcess,
            title: L10n.string("notifications.action.showInActivityMonitor"),
            options: [.foreground]
        )
        let kill = UNNotificationAction(
            identifier: Action.killProcess,
            title: L10n.string("notifications.action.forceQuitProcess"),
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

    private func evaluateCriticalDwell(for status: ActivityStatus, metrics: ActivityMetrics) -> Bool {
        guard metrics.hasLiveData, status.level == .critical, let trigger = status.trigger else {
            resetCriticalDwell()
            return false
        }

        let signature = CriticalSignature(trigger: trigger)
        if criticalConditionSignature != signature {
            criticalConditionSignature = signature
            criticalConditionStartDate = now()
            return false
        }

        guard let start = criticalConditionStartDate else {
            criticalConditionStartDate = now()
            return false
        }

        return now().timeIntervalSince(start) >= highActivityDuration
    }

    private func resetCriticalDwell() {
        criticalConditionSignature = nil
        criticalConditionStartDate = nil
    }

    private func metricDescription(for process: ProcessUsage) -> String {
        let durationText = L10n.format("notifications.duration.seconds", Int(highActivityDuration.rounded()))
        let components: [String] = [
            process.triggeredByCPU ? L10n.format("notifications.metric.cpu.format", process.cpuDescription) : nil,
            process.triggeredByMemory ? L10n.format("notifications.metric.memory.format", process.memoryDescription) : nil
        ].compactMap { $0 }

        if components.isEmpty {
            return L10n.format("notifications.highActivity.none", durationText)
        }

        let joined = L10n.list(components)
        return L10n.format("notifications.highActivity.using", joined, durationText)
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
        let triggersRaw = info["triggers"] as? [String] ?? []
        let triggers = Set(triggersRaw.compactMap(ProcessUsage.Trigger.init(rawValue:)))
        let process = ProcessUsage(
            pid: pidValue,
            command: command,
            cpuPercent: cpu,
            memoryPercent: memory,
            triggers: triggers.isEmpty ? [.cpu] : triggers
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
