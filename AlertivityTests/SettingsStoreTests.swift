import Testing
import Foundation
@testable import Alertivity

private func makeIsolatedDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
    let suiteName = "alertivity-settings-tests-\(name)"
    let suite = UserDefaults(suiteName: suiteName)!
    suite.removePersistentDomain(forName: suiteName)
    return suite
}

@Suite struct SettingsStoreTests {
    @Test
    func initializesWithDefaults() {
        let store = SettingsStore(userDefaults: makeIsolatedDefaults("defaults"))
        expectFalse(store.hideDockIcon)
        expectFalse(store.launchAtLogin)
        expectTrue(store.isMenuIconEnabled)
        expectFalse(store.menuIconOnlyWhenHigh)
        expectTrue(store.notificationsEnabled)
        expectEqual(store.menuIconType, .status)
        expectTrue(store.showMetricIcon)
        expectTrue(store.isMenuIconAutoSwitchEnabled)
        expectEqual(store.highActivityDurationSeconds, 60)
        expectEqual(store.highActivityCPUThresholdPercent, 80)
        expectEqual(store.highActivityMemoryThresholdPercent, 25)
    }

    @Test
    func persistsChangesToDefaults() {
        let suiteName = "persist-\(UUID().uuidString)"
        let defaults = makeIsolatedDefaults(suiteName)
        let store = SettingsStore(userDefaults: defaults)

        store.hideDockIcon = true
        store.notificationsEnabled = true
        store.menuIconType = .network
        store.highActivityDurationSeconds = 90

        let reloaded = SettingsStore(userDefaults: UserDefaults(suiteName: "alertivity-settings-tests-\(suiteName)")!)
        expectTrue(reloaded.hideDockIcon)
        expectTrue(reloaded.notificationsEnabled)
        expectEqual(reloaded.menuIconType, .network)
        expectEqual(reloaded.highActivityDurationSeconds, 90)
    }
}
