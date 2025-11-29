import Combine
import Foundation

final class SettingsStore: ObservableObject {
    private enum Keys {
        static let hideDockIcon = "app.hideDockIcon"
        static let launchAtLogin = "app.launchAtLogin"
        static let menuIconEnabled = "notice.menu.enabled"
        static let menuIconOnlyWhenHigh = "notice.menu.onlyHigh"
        static let notificationsEnabled = "notice.notifications.enabled"
        static let menuIconType = "notice.menu.iconType"
        static let showMetricIcon = "notice.menu.showMetricIcon"
        static let autoSwitch = "notice.menu.autoSwitch"
        static let highActivityDuration = "monitor.topProcesses.duration"
        static let highActivityCPUThreshold = "monitor.topProcesses.cpuThresholdPercent"
        static let highActivityMemoryThreshold = "monitor.topProcesses.memoryThresholdPercent"
    }

    private let defaults: UserDefaults

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

    @Published var menuIconType: MenuIconType {
        didSet { defaults.set(menuIconType.rawValue, forKey: Keys.menuIconType) }
    }

    @Published var showMetricIcon: Bool {
        didSet { defaults.set(showMetricIcon, forKey: Keys.showMetricIcon) }
    }

    @Published var isMenuIconAutoSwitchEnabled: Bool {
        didSet { defaults.set(isMenuIconAutoSwitchEnabled, forKey: Keys.autoSwitch) }
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

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults

        hideDockIcon = defaults.object(forKey: Keys.hideDockIcon) as? Bool ?? false
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        isMenuIconEnabled = defaults.object(forKey: Keys.menuIconEnabled) as? Bool ?? true
        menuIconOnlyWhenHigh = defaults.object(forKey: Keys.menuIconOnlyWhenHigh) as? Bool ?? false
        notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? false

        if
            let storedMenuIconType = defaults.string(forKey: Keys.menuIconType),
            let resolved = MenuIconType(rawValue: storedMenuIconType)
        {
            menuIconType = resolved
        } else {
            menuIconType = .status
        }

        showMetricIcon = defaults.object(forKey: Keys.showMetricIcon) as? Bool ?? false
        isMenuIconAutoSwitchEnabled = defaults.object(forKey: Keys.autoSwitch) as? Bool ?? false
        highActivityDurationSeconds = defaults.object(forKey: Keys.highActivityDuration) as? Int ?? 120
        highActivityCPUThresholdPercent = defaults.object(forKey: Keys.highActivityCPUThreshold) as? Int ?? 20
        highActivityMemoryThresholdPercent = defaults.object(forKey: Keys.highActivityMemoryThreshold) as? Int ?? 15
    }
}
