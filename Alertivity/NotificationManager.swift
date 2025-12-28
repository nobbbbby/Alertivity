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
    var processSamplingAvailable: Bool = true
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

    func postNotificationIfNeeded(for _: ActivityStatus, metrics: ActivityMetrics) {
        let isAuthorized: Bool
        switch authorizationStatus {
        case .authorized, .provisional:
            isAuthorized = true
        default:
            isAuthorized = false
        }
        guard isAuthorized else { return }
        let hasHighActivityProcess = processSamplingAvailable && !metrics.highActivityProcesses.isEmpty

        let criticalTrigger = notificationTrigger(for: metrics)
        let hasCriticalDwell = evaluateCriticalDwell(trigger: criticalTrigger, metrics: metrics)
        let shouldNotifyForCritical = criticalTrigger != nil && hasCriticalDwell

        guard shouldNotifyForCritical || hasHighActivityProcess else { return }

        let currentDate = now()
        if let last = lastNotificationDate, currentDate.timeIntervalSince(last) < throttleInterval {
            return
        }

        let content = UNMutableNotificationContent()
        if let criticalTrigger {
            content.title = L10n.format("status.title.critical.single", metricDisplayName(for: criticalTrigger))
        } else {
            content.title = L10n.string("notifications.process.title")
        }
        content.body = hasHighActivityProcess ? "" : ActivityStatus(metrics: metrics).message(for: metrics)
        content.sound = .default

        var userInfo: [String: Any] = [:]

        if let trigger = criticalTrigger {
            userInfo["triggerMetric"] = trigger.rawValue
            userInfo["triggerValue"] = triggerValue(for: trigger, metrics: metrics)
        }

        if hasHighActivityProcess, let culprit = metrics.highActivityProcesses.first {
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

    private func evaluateCriticalDwell(trigger: ActivityStatus.TriggerMetric?, metrics: ActivityMetrics) -> Bool {
        guard metrics.hasLiveData, let trigger else {
            resetCriticalDwell()
            return false
        }

        if highActivityDuration <= 0 {
            return true
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

    private func notificationTrigger(for metrics: ActivityMetrics) -> ActivityStatus.TriggerMetric? {
        let criticalMetrics = criticalTriggerCandidates(for: metrics)
        guard !criticalMetrics.isEmpty else { return nil }
        return criticalMetrics.max { lhs, rhs in
            priority(for: lhs) < priority(for: rhs)
        }
    }

    private func criticalTriggerCandidates(for metrics: ActivityMetrics) -> [ActivityStatus.TriggerMetric] {
        var candidates: [ActivityStatus.TriggerMetric] = []
        if metrics.cpuSeverity == .critical { candidates.append(.cpu) }
        if metrics.memorySeverity == .critical { candidates.append(.memory) }
        if metrics.diskSeverity == .critical { candidates.append(.disk) }
        if metrics.networkSeverity == .critical { candidates.append(.network) }
        return candidates
    }

    private func priority(for metric: ActivityStatus.TriggerMetric) -> Int {
        switch metric {
        case .cpu:
            return 4
        case .memory:
            return 3
        case .disk:
            return 2
        case .network:
            return 1
        }
    }

    private func metricDisplayName(for trigger: ActivityStatus.TriggerMetric) -> String {
        switch trigger {
        case .cpu:
            return L10n.string("status.metric.cpu")
        case .memory:
            return L10n.string("status.metric.memory")
        case .disk:
            return L10n.string("status.metric.disk")
        case .network:
            return L10n.string("status.metric.network")
        }
    }

    private func triggerValue(for trigger: ActivityStatus.TriggerMetric, metrics: ActivityMetrics) -> Double {
        switch trigger {
        case .cpu:
            return metrics.cpuUsagePercentage
        case .memory:
            return metrics.memoryUsage
        case .disk:
            return metrics.disk.totalBytesPerSecond
        case .network:
            return metrics.network.totalBytesPerSecond
        }
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
