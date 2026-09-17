import Testing
import Foundation
@testable import Alertivity

@Suite struct SystemMetricsProviderTests {
    @Test
    func changingCPUThresholdClearsTrackedProcesses() {
        let provider = SystemMetricsProvider()
        provider.highActivityDuration = 1

        let process = ProcessUsage(
            pid: 4242,
            command: "/Applications/Safari.app/Contents/MacOS/Safari",
            cpuPercent: 0.5,
            memoryPercent: 0.1,
            triggers: [.cpu]
        )

        let initialTimestamp = Date()
        let initialResult = provider.simulateFilterHighActivity(processes: [process], at: initialTimestamp)
        expectTrue(initialResult.isEmpty, "High-activity dwell should block first sample")
        expectEqual(provider.trackedProcessIDsForTesting, Set([process.pid]))

        let maturedTimestamp = initialTimestamp.addingTimeInterval(1.1)
        let maturedResult = provider.simulateFilterHighActivity(processes: [process], at: maturedTimestamp)
        expectEqual(maturedResult.map { $0.pid }, [process.pid])

        provider.highActivityCPUThreshold = 0.9
        expectTrue(provider.trackedProcessIDsForTesting.isEmpty, "Threshold change should clear cached tracking")

        let afterChangeTimestamp = maturedTimestamp.addingTimeInterval(0.5)
        let resultAfterChange = provider.simulateFilterHighActivity(processes: [], at: afterChangeTimestamp)
        expectTrue(resultAfterChange.isEmpty, "No stale processes should remain after threshold change")
        expectTrue(provider.trackedProcessIDsForTesting.isEmpty)
    }

    @Test
    func clampsThresholdsToValidRange() {
        let provider = SystemMetricsProvider()
        provider.highActivityCPUThreshold = -1
        provider.highActivityMemoryThreshold = 2
        expectEqual(provider.highActivityCPUThreshold, 0)
        expectEqual(provider.highActivityMemoryThreshold, 1)
    }

    @Test
    func ignoredProcessesNeverEnterDwellTracking() {
        let provider = SystemMetricsProvider()
        provider.highActivityDuration = 1
        provider.ignoredProcessPaths = ["/Applications/Safari.app/Contents/MacOS/Safari"]

        let ignoredProcess = ProcessUsage(
            pid: 4242,
            command: "/Applications/Safari.app/Contents/MacOS/Safari",
            cpuPercent: 0.9,
            memoryPercent: 0.3,
            triggers: [.cpu, .memory]
        )
        let monitoredProcess = ProcessUsage(
            pid: 5252,
            command: "/Applications/Xcode.app/Contents/MacOS/Xcode",
            cpuPercent: 0.9,
            memoryPercent: 0.1,
            triggers: [.cpu]
        )

        let start = Date()
        let initial = provider.simulateFilterHighActivity(
            processes: [ignoredProcess, monitoredProcess],
            at: start
        )
        expectTrue(initial.isEmpty)
        expectEqual(provider.trackedProcessIDsForTesting, Set([monitoredProcess.pid]))

        let matured = provider.simulateFilterHighActivity(
            processes: [ignoredProcess, monitoredProcess],
            at: start.addingTimeInterval(1.1)
        )
        expectEqual(matured.map(\.pid), [monitoredProcess.pid])

        provider.ignoredProcessPaths = []
        expectTrue(provider.trackedProcessIDsForTesting.isEmpty)
    }
}
