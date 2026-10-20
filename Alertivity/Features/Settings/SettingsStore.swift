import Combine
import Foundation

/// A terminal onboarding outcome suppresses automatic presentation; replay never resets preferences.
enum OnboardingOutcome: String {
    case pending, completed, skipped
}

final class SettingsStore: ObservableObject {
    private enum Keys {
        static let onboardingOutcome = "app.onboarding.outcome"
        static let hideDockIcon = "app.hideDockIcon"
        static let launchAtLogin = "app.launchAtLogin"
        static let menuIconEnabled = "notice.menu.enabled"
        static let menuIconOnlyWhenHigh = "notice.menu.onlyHigh"
        static let notificationCooldown = "notice.notifications.cooldownMinutes"
        static let notificationsEnabled = "notice.notifications.enabled"
        static let menuIconType = "notice.menu.iconType"
        static let showMetricIcon = "notice.menu.showMetricIcon"
        static let autoSwitchPriority = "notice.menu.autoSwitchPriority"
        static let autoSwitch = "notice.menu.autoSwitch"
        static let highActivityDuration = "monitor.topProcesses.duration"
        static let highActivityCPUThreshold = "monitor.topProcesses.cpuThresholdPercent"
        static let highActivityMemoryThreshold = "monitor.topProcesses.memoryThresholdPercent"
        static let ignoredProcessPaths = "monitor.topProcesses.ignoredExecutablePaths"
        static let activityThresholds = "monitor.system.activityThresholds"
    }

    private let defaults: UserDefaults
    let distribution: AppDistribution
    @Published private(set) var hasProAccess = false

    var canCustomizeMonitoring: Bool { distribution == .openSource || hasProAccess }

    /// Only this configuration may drive monitoring and alerts; saved custom values remain untouched.
    var monitoringConfiguration: MonitoringConfiguration {
        MonitoringConfiguration(
            thresholds: canCustomizeMonitoring ? activityThresholds : .default,
            cooldownMinutes: canCustomizeMonitoring ? notificationCooldownMinutes : MonitoringPreferences.defaultNotificationCooldownMinutes,
            durationSeconds: canCustomizeMonitoring ? MonitoringPreferences.normalizedDuration(highActivityDurationSeconds) : 60
        )
    }

    func setProAccess(_ granted: Bool) {
        guard distribution == .appStore, hasProAccess != granted else { return }
        hasProAccess = granted
        AppLogger.purchases.info("Monitoring customization access changed; granted: \(granted, privacy: .public)")
    }

    /// An explicit replay request is transient; it must never reopen guidance after relaunch.
    @Published var isOnboardingRequested = false

    @Published private(set) var onboardingOutcome: OnboardingOutcome {
        didSet { defaults.set(onboardingOutcome.rawValue, forKey: Keys.onboardingOutcome) }
    }

    /// Closing the welcome window counts as skipping, so it never blocks subsequent launches.
    func finishOnboarding(_ outcome: OnboardingOutcome) {
        guard outcome != .pending else { return }
        onboardingOutcome = outcome
        AppLogger.lifecycle.info("Onboarding finished; outcome: \(outcome.rawValue, privacy: .public)")
    }

    @Published var hideDockIcon: Bool {
        didSet { defaults.set(hideDockIcon, forKey: Keys.hideDockIcon) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published var isMenuIconEnabled: Bool {
        didSet { defaults.set(isMenuIconEnabled, forKey: Keys.menuIconEnabled) }
    }

    @Published var menuIconOnlyWhenHigh: Bool {
        didSet { defaults.set(menuIconOnlyWhenHigh, forKey: Keys.menuIconOnlyWhenHigh) }
    }

    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    /// Shared by system and process alerts; changing it preserves the last alert timestamp.
    @Published var notificationCooldownMinutes: Int {
        didSet {
            let normalized = MonitoringPreferences.normalizedNotificationCooldown(notificationCooldownMinutes)
            if normalized != notificationCooldownMinutes {
                notificationCooldownMinutes = normalized
            }
            defaults.set(notificationCooldownMinutes, forKey: Keys.notificationCooldown)
            if notificationCooldownMinutes != oldValue {
                AppLogger.notifications.info("Notification cooldown updated; minutes: \(self.notificationCooldownMinutes, privacy: .public)")
            }
        }
    }

    @Published var menuIconType: MenuIconType {
        didSet { defaults.set(menuIconType.rawValue, forKey: Keys.menuIconType) }
    }

    @Published var showMetricIcon: Bool {
        didSet { defaults.set(showMetricIcon, forKey: Keys.showMetricIcon) }
    }

    @Published var isMenuIconAutoSwitchEnabled: Bool {
        didSet { defaults.set(isMenuIconAutoSwitchEnabled, forKey: Keys.autoSwitch) }
    }

    @Published var menuIconAutoSwitchPriority: [MetricMenuSelection] {
        didSet {
            let normalized = MetricMenuSelection.normalizedAutoSwitchPriority(menuIconAutoSwitchPriority)
            if normalized != menuIconAutoSwitchPriority {
                menuIconAutoSwitchPriority = normalized
            }
            defaults.set(menuIconAutoSwitchPriority.map(\.rawValue), forKey: Keys.autoSwitchPriority)
            if menuIconAutoSwitchPriority != oldValue {
                let order = menuIconAutoSwitchPriority.map(\.rawValue).joined(separator: ",")
                AppLogger.lifecycle.info("Auto switch priority updated; order: \(order, privacy: .public)")
            }
        }
    }

    @Published var highActivityDurationSeconds: Int {
        didSet { defaults.set(highActivityDurationSeconds, forKey: Keys.highActivityDuration) }
    }

    @Published var highActivityCPUThresholdPercent: Int {
        didSet { defaults.set(highActivityCPUThresholdPercent, forKey: Keys.highActivityCPUThreshold) }
    }

    @Published var highActivityMemoryThresholdPercent: Int {
        didSet { defaults.set(highActivityMemoryThresholdPercent, forKey: Keys.highActivityMemoryThreshold) }
    }

    @Published private(set) var ignoredProcessPaths: [String] {
        didSet { defaults.set(ignoredProcessPaths, forKey: Keys.ignoredProcessPaths) }
    }

    @Published private(set) var activityThresholds: ActivityThresholds {
        didSet {
            do {
                defaults.set(try JSONEncoder().encode(activityThresholds), forKey: Keys.activityThresholds)
            } catch {
                AppLogger.metrics.error("Failed to persist activity thresholds: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    init(userDefaults: UserDefaults = .standard, distribution: AppDistribution = .current) {
        self.distribution = distribution
        self.defaults = userDefaults
        onboardingOutcome = defaults.string(forKey: Keys.onboardingOutcome)
            .flatMap(OnboardingOutcome.init(rawValue:)) ?? .pending

        hideDockIcon = defaults.object(forKey: Keys.hideDockIcon) as? Bool ?? false
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        isMenuIconEnabled = defaults.object(forKey: Keys.menuIconEnabled) as? Bool ?? true
        menuIconOnlyWhenHigh = defaults.object(forKey: Keys.menuIconOnlyWhenHigh) as? Bool ?? false
        notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true

        notificationCooldownMinutes = MonitoringPreferences.normalizedNotificationCooldown(
            defaults.object(forKey: Keys.notificationCooldown) as? Int
                ?? MonitoringPreferences.defaultNotificationCooldownMinutes
        )

        if
            let storedMenuIconType = defaults.string(forKey: Keys.menuIconType),
            let resolved = MenuIconType(rawValue: storedMenuIconType)
        {
            menuIconType = resolved
        } else {
            menuIconType = .status
        }

        showMetricIcon = defaults.object(forKey: Keys.showMetricIcon) as? Bool ?? true
        isMenuIconAutoSwitchEnabled = defaults.object(forKey: Keys.autoSwitch) as? Bool ?? true
        menuIconAutoSwitchPriority = MetricMenuSelection.normalizedAutoSwitchPriority(
            (defaults.stringArray(forKey: Keys.autoSwitchPriority) ?? []).compactMap(MetricMenuSelection.init(rawValue:))
        )
        highActivityDurationSeconds = defaults.object(forKey: Keys.highActivityDuration) as? Int ?? 60
        highActivityCPUThresholdPercent = defaults.object(forKey: Keys.highActivityCPUThreshold) as? Int ?? 80
        highActivityMemoryThresholdPercent = defaults.object(forKey: Keys.highActivityMemoryThreshold) as? Int ?? 25
        ignoredProcessPaths = Array(Set(
            (defaults.stringArray(forKey: Keys.ignoredProcessPaths) ?? [])
                .map(Self.normalizedProcessPath)
                .filter { !$0.isEmpty }
        )).sorted()
        activityThresholds = Self.loadActivityThresholds(from: defaults)
    }

    @discardableResult
    func updateActivityThresholds(
        cpuElevatedPercent: Double,
        cpuCriticalPercent: Double,
        memoryElevatedPercent: Double,
        memoryCriticalPercent: Double,
        diskElevatedMegabytesPerSecond: Double,
        diskCriticalMegabytesPerSecond: Double,
        networkElevatedMegabytesPerSecond: Double,
        networkCriticalMegabytesPerSecond: Double
    ) -> ActivityThresholds.ValidationError? {
        let validationError = ActivityThresholds.validate(
            cpuElevatedPercent: cpuElevatedPercent,
            cpuCriticalPercent: cpuCriticalPercent,
            memoryElevatedPercent: memoryElevatedPercent,
            memoryCriticalPercent: memoryCriticalPercent,
            diskElevatedMegabytesPerSecond: diskElevatedMegabytesPerSecond,
            diskCriticalMegabytesPerSecond: diskCriticalMegabytesPerSecond,
            networkElevatedMegabytesPerSecond: networkElevatedMegabytesPerSecond,
            networkCriticalMegabytesPerSecond: networkCriticalMegabytesPerSecond
        )
        guard validationError == nil, let thresholds = ActivityThresholds(
            cpuElevatedPercent: cpuElevatedPercent,
            cpuCriticalPercent: cpuCriticalPercent,
            memoryElevatedPercent: memoryElevatedPercent,
            memoryCriticalPercent: memoryCriticalPercent,
            diskElevatedMegabytesPerSecond: diskElevatedMegabytesPerSecond,
            diskCriticalMegabytesPerSecond: diskCriticalMegabytesPerSecond,
            networkElevatedMegabytesPerSecond: networkElevatedMegabytesPerSecond,
            networkCriticalMegabytesPerSecond: networkCriticalMegabytesPerSecond
        ) else { return validationError }

        activityThresholds = thresholds
        AppLogger.metrics.info("Activity thresholds updated")
        return nil
    }

    func resetActivityThresholds() {
        activityThresholds = .default
        AppLogger.metrics.info("Activity thresholds reset to defaults")
    }

    func ignoreProcess(at path: String) {
        let normalizedPath = Self.normalizedProcessPath(path)
        guard !normalizedPath.isEmpty, !ignoredProcessPaths.contains(normalizedPath) else { return }
        ignoredProcessPaths.append(normalizedPath)
        ignoredProcessPaths.sort()
    }

    func removeIgnoredProcess(at path: String) {
        let normalizedPath = Self.normalizedProcessPath(path)
        ignoredProcessPaths.removeAll { $0 == normalizedPath }
    }

    func isProcessIgnored(at path: String) -> Bool {
        ignoredProcessPaths.contains(Self.normalizedProcessPath(path))
    }

    static func normalizedProcessPath(_ path: String) -> String {
        NSString(string: path.trimmingCharacters(in: .whitespacesAndNewlines)).standardizingPath
    }

    private static func loadActivityThresholds(from defaults: UserDefaults) -> ActivityThresholds {
        guard let data = defaults.data(forKey: Keys.activityThresholds) else { return .default }
        do {
            let decoded = try JSONDecoder().decode(ActivityThresholds.self, from: data)
            guard let validated = ActivityThresholds(
                cpuElevatedPercent: decoded.cpuElevatedPercent,
                cpuCriticalPercent: decoded.cpuCriticalPercent,
                memoryElevatedPercent: decoded.memoryElevatedPercent,
                memoryCriticalPercent: decoded.memoryCriticalPercent,
                diskElevatedMegabytesPerSecond: decoded.diskElevatedMegabytesPerSecond,
                diskCriticalMegabytesPerSecond: decoded.diskCriticalMegabytesPerSecond,
                networkElevatedMegabytesPerSecond: decoded.networkElevatedMegabytesPerSecond,
                networkCriticalMegabytesPerSecond: decoded.networkCriticalMegabytesPerSecond
            ) else {
                AppLogger.metrics.error("Invalid saved activity thresholds; using defaults")
                return .default
            }
            return validated
        } catch {
            AppLogger.metrics.error("Unreadable saved activity thresholds; using defaults: \(error.localizedDescription, privacy: .public)")
            return .default
        }
    }
}
