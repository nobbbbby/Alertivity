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
    func autoSwitchPriorityPersistsAndRepairsInvalidValues() {
        let defaults = makeIsolatedDefaults()
        expectEqual(SettingsStore(userDefaults: defaults).menuIconAutoSwitchPriority, [.cpu, .memory, .disk, .network])
        defaults.set(["network", "invalid", "network", "memory"], forKey: "notice.menu.autoSwitchPriority")
        let store = SettingsStore(userDefaults: defaults)
        expectEqual(store.menuIconAutoSwitchPriority, [.network, .memory, .cpu, .disk])
        store.menuIconAutoSwitchPriority = [.disk, .network, .memory, .cpu]
        expectEqual(SettingsStore(userDefaults: defaults).menuIconAutoSwitchPriority, [.disk, .network, .memory, .cpu])
        store.menuIconAutoSwitchPriority = [.memory, .memory]
        expectEqual(store.menuIconAutoSwitchPriority, [.memory, .cpu, .disk, .network])
        expectEqual(SettingsStore(userDefaults: defaults).menuIconAutoSwitchPriority, store.menuIconAutoSwitchPriority)
        store.menuIconAutoSwitchPriority = MetricMenuSelection.autoSwitchPriority
        expectEqual(SettingsStore(userDefaults: defaults).menuIconAutoSwitchPriority, MetricMenuSelection.autoSwitchPriority)
    }

    @Test
    func initializesWithDefaults() {
        let store = SettingsStore(userDefaults: makeIsolatedDefaults("defaults"))
        expectFalse(store.hideDockIcon)
        expectFalse(store.launchAtLogin)
        expectTrue(store.isMenuIconEnabled)
        expectFalse(store.menuIconOnlyWhenHigh)
        expectTrue(store.notificationsEnabled)
        expectEqual(store.notificationCooldownMinutes, 10)
        expectEqual(store.menuIconType, .status)
        expectTrue(store.showMetricIcon)
        expectTrue(store.isMenuIconAutoSwitchEnabled)
        expectEqual(store.highActivityDurationSeconds, 60)
        expectEqual(store.highActivityCPUThresholdPercent, 80)
        expectEqual(store.highActivityMemoryThresholdPercent, 25)
        expectTrue(store.ignoredProcessPaths.isEmpty)
        expectEqual(store.activityThresholds, .default)
    }

    @Test
    func persistsChangesToDefaults() {
        let suiteName = "persist-\(UUID().uuidString)"
        let defaults = makeIsolatedDefaults(suiteName)
        let store = SettingsStore(userDefaults: defaults)

        store.hideDockIcon = true
        store.notificationsEnabled = true
        store.notificationCooldownMinutes = 30
        store.menuIconType = .network
        store.highActivityDurationSeconds = 90
        store.ignoreProcess(at: " /Applications/Safari.app/Contents/MacOS/Safari ")
        store.ignoreProcess(at: "/Applications/Safari.app/Contents/MacOS/Safari")

        let reloaded = SettingsStore(userDefaults: UserDefaults(suiteName: "alertivity-settings-tests-\(suiteName)")!)
        expectTrue(reloaded.hideDockIcon)
        expectTrue(reloaded.notificationsEnabled)
        expectEqual(reloaded.notificationCooldownMinutes, 30)
        expectEqual(reloaded.menuIconType, .network)
        expectEqual(reloaded.highActivityDurationSeconds, 90)
        expectEqual(reloaded.ignoredProcessPaths, ["/Applications/Safari.app/Contents/MacOS/Safari"])
        expectTrue(reloaded.isProcessIgnored(at: "/Applications/Safari.app/Contents/MacOS/Safari"))

        reloaded.removeIgnoredProcess(at: "/Applications/Safari.app/Contents/MacOS/Safari")
        expectTrue(reloaded.ignoredProcessPaths.isEmpty)
    }

    @Test
    func onboardingOutcomesPersistWithoutResettingPreferences() {
        for outcome in [OnboardingOutcome.completed, .skipped] {
            let defaults = makeIsolatedDefaults()
            let store = SettingsStore(userDefaults: defaults)
            expectEqual(store.onboardingOutcome, .pending)
            store.notificationsEnabled = false
            store.menuIconType = .network
            store.highActivityDurationSeconds = 90
            store.finishOnboarding(outcome)
            store.isOnboardingRequested = true
            let reloaded = SettingsStore(userDefaults: defaults)
            expectEqual(reloaded.onboardingOutcome, outcome)
            expectFalse(reloaded.isOnboardingRequested)
            expectFalse(reloaded.notificationsEnabled)
            expectEqual(reloaded.menuIconType, .network)
            expectEqual(reloaded.highActivityDurationSeconds, 90)
        }
    }

    @Test
    func unknownOnboardingStateOffersGuidanceAgain() {
        let defaults = makeIsolatedDefaults()
        defaults.set("invalid", forKey: "app.onboarding.outcome")
        expectEqual(SettingsStore(userDefaults: defaults).onboardingOutcome, .pending)
    }

    @Test(arguments: [-1, 0, 7, 61, Int.max])
    func invalidCooldownFallsBackToDefault(value: Int) {
        let defaults = makeIsolatedDefaults()
        defaults.set(value, forKey: "notice.notifications.cooldownMinutes")
        let store = SettingsStore(userDefaults: defaults)
        expectEqual(store.notificationCooldownMinutes, 10)
        store.notificationCooldownMinutes = 30
        store.notificationCooldownMinutes = value
        expectEqual(store.notificationCooldownMinutes, 10)
        expectEqual(SettingsStore(userDefaults: defaults).notificationCooldownMinutes, 10)
    }

    @Test
    func monitoringPreferencesClampValuesToRuntimeLimits() {
        expectEqual(MonitoringPreferences.normalizedDuration(0), 10)
        expectEqual(MonitoringPreferences.normalizedDuration(900), 600)
        expectEqual(MonitoringPreferences.normalizedCPUThreshold(0), 1)
        expectEqual(MonitoringPreferences.normalizedCPUThreshold(101), 100)
        expectEqual(MonitoringPreferences.normalizedMemoryThreshold(0), 5)
        expectEqual(MonitoringPreferences.normalizedMemoryThreshold(51), 50)
    }

    @Test
    func persistsAndResetsCustomActivityThresholds() {
        let suiteName = "thresholds-\(UUID().uuidString)"
        let defaults = makeIsolatedDefaults(suiteName)
        let store = SettingsStore(userDefaults: defaults)

        let error = store.updateActivityThresholds(
            cpuElevatedPercent: 45,
            cpuCriticalPercent: 75,
            memoryElevatedPercent: 65,
            memoryCriticalPercent: 82,
            diskElevatedMegabytesPerSecond: 25,
            diskCriticalMegabytesPerSecond: 90,
            networkElevatedMegabytesPerSecond: 4,
            networkCriticalMegabytesPerSecond: 18
        )
        expectEqual(error, nil)

        let reloaded = SettingsStore(userDefaults: UserDefaults(suiteName: "alertivity-settings-tests-\(suiteName)")!)
        expectEqual(reloaded.activityThresholds.cpuElevatedPercent, 45)
        expectEqual(reloaded.activityThresholds.diskCriticalMegabytesPerSecond, 90)

        reloaded.resetActivityThresholds()
        expectEqual(reloaded.activityThresholds, .default)
    }

    @Test
    func invalidSavedActivityThresholdsFallBackToDefaults() {
        let defaults = makeIsolatedDefaults("invalid-thresholds")
        let invalidJSON = """
        {"cpuElevatedPercent":90,"cpuCriticalPercent":50,"memoryElevatedPercent":70,"memoryCriticalPercent":85,"diskElevatedMegabytesPerSecond":30,"diskCriticalMegabytesPerSecond":120,"networkElevatedMegabytesPerSecond":5,"networkCriticalMegabytesPerSecond":20}
        """
        defaults.set(Data(invalidJSON.utf8), forKey: "monitor.system.activityThresholds")

        let store = SettingsStore(userDefaults: defaults)
        expectEqual(store.activityThresholds, .default)
    }
}

@Suite struct ProBoundaryTests {
    @Test
    func savedCustomizationSurvivesFreeProAndRelaunch() throws {
        let defaults = makeIsolatedDefaults()
        let source = SettingsStore(userDefaults: defaults, distribution: .openSource)
        source.notificationCooldownMinutes = 30
        source.highActivityDurationSeconds = 240
        #expect(source.updateActivityThresholds(
            cpuElevatedPercent: 40, cpuCriticalPercent: 60,
            memoryElevatedPercent: 50, memoryCriticalPercent: 70,
            diskElevatedMegabytesPerSecond: 10, diskCriticalMegabytesPerSecond: 20,
            networkElevatedMegabytesPerSecond: 1, networkCriticalMegabytesPerSecond: 2
        ) == nil)
        let custom = source.monitoringConfiguration
        let store = SettingsStore(userDefaults: defaults, distribution: .appStore)
        #expect(!store.canCustomizeMonitoring)
        #expect(store.monitoringConfiguration == MonitoringConfiguration(thresholds: .default, cooldownMinutes: 10, durationSeconds: 60))
        #expect(store.activityThresholds == custom.thresholds)
        #expect(store.notificationCooldownMinutes == 30)
        #expect(store.highActivityDurationSeconds == 240)
        store.setProAccess(true)
        #expect(store.monitoringConfiguration == custom)
        store.setProAccess(false)
        #expect(store.monitoringConfiguration.thresholds == .default)
        // Relaunch trusts StoreKit again, rather than a saved Boolean entitlement.
        let reloaded = SettingsStore(userDefaults: defaults, distribution: .appStore)
        #expect(!reloaded.hasProAccess)
        reloaded.setProAccess(true)
        #expect(reloaded.monitoringConfiguration == custom)
    }

    @Test
    func freeRuntimeCannotBeBypassedByWritingPreferences() {
        let store = SettingsStore(userDefaults: makeIsolatedDefaults(), distribution: .appStore)
        store.notificationCooldownMinutes = 1
        store.highActivityDurationSeconds = 600
        #expect(store.monitoringConfiguration.cooldownMinutes == 10)
        #expect(store.monitoringConfiguration.durationSeconds == 60)
        store.notificationsEnabled = false
        store.menuIconType = .network
        store.isMenuIconAutoSwitchEnabled = false
        #expect(!store.notificationsEnabled)
        #expect(store.menuIconType == .network)
        #expect(!store.isMenuIconAutoSwitchEnabled)
    }

    @Test
    func openSourceCustomizationAndProcessFeaturesNeedNoPurchase() {
        let store = SettingsStore(userDefaults: makeIsolatedDefaults(), distribution: .openSource)
        store.notificationCooldownMinutes = 1
        store.highActivityDurationSeconds = 120
        store.highActivityCPUThresholdPercent = 95
        store.highActivityMemoryThresholdPercent = 40
        store.ignoreProcess(at: "/usr/bin/test")
        store.setProAccess(false)
        #expect(store.canCustomizeMonitoring)
        #expect(store.monitoringConfiguration.cooldownMinutes == 1)
        #expect(store.monitoringConfiguration.durationSeconds == 120)
        #expect(store.highActivityCPUThresholdPercent == 95)
        #expect(store.highActivityMemoryThresholdPercent == 40)
        #expect(store.isProcessIgnored(at: "/usr/bin/test"))
    }
}
