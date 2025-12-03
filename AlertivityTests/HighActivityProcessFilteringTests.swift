import Testing
import Foundation
@testable import Alertivity

@Suite struct HighActivityProcessFilteringTests {
    @Test
    func requiresDwellBeforeReportingHighActivityProcesses() {
        let provider = SystemMetricsProvider()
        provider.highActivityDuration = 2

        let process = ProcessUsage(
            pid: 1111,
            command: "/usr/bin/vim",
            cpuPercent: 0.5,
            memoryPercent: 0.2,
            triggers: [.cpu]
        )

        let first = provider.simulateFilterHighActivity(processes: [process], at: Date())
        expectTrue(first.isEmpty)

        let afterDwell = provider.simulateFilterHighActivity(processes: [process], at: Date().addingTimeInterval(2.1))
        expectEqual(afterDwell.map { $0.pid }, [process.pid])
    }

    @Test
    func resetsTrackingWhenProcessStopsAndReturns() {
        let provider = SystemMetricsProvider()
        provider.highActivityDuration = 2

        let process = ProcessUsage(
            pid: 2222,
            command: "/usr/bin/python3",
            cpuPercent: 0.7,
            memoryPercent: 0.1,
            triggers: [.cpu]
        )

        let start = Date()
        let initial = provider.simulateFilterHighActivity(processes: [process], at: start)
        expectTrue(initial.isEmpty)
        expectEqual(provider.trackedProcessIDsForTesting, Set([process.pid]))

        let afterStop = provider.simulateFilterHighActivity(processes: [], at: start.addingTimeInterval(3))
        expectTrue(afterStop.isEmpty)
        expectTrue(provider.trackedProcessIDsForTesting.isEmpty)

        let restarted = provider.simulateFilterHighActivity(processes: [process], at: start.addingTimeInterval(3.1))
        expectTrue(restarted.isEmpty)
        expectEqual(provider.trackedProcessIDsForTesting, Set([process.pid]))

        let afterRediscoveryDwell = provider.simulateFilterHighActivity(processes: [process], at: start.addingTimeInterval(5.2))
        expectEqual(afterRediscoveryDwell.map { $0.pid }, [process.pid])
    }

    @Test
    func tracksProcessesIndependently() {
        let provider = SystemMetricsProvider()
        provider.highActivityDuration = 2

        let processOne = ProcessUsage(
            pid: 3333,
            command: "/usr/bin/ruby",
            cpuPercent: 0.65,
            memoryPercent: 0.18,
            triggers: [.cpu]
        )
        let processTwo = ProcessUsage(
            pid: 4444,
            command: "/usr/bin/ffmpeg",
            cpuPercent: 0.25,
            memoryPercent: 0.3,
            triggers: [.cpu, .memory]
        )

        let start = Date()
        let initial = provider.simulateFilterHighActivity(processes: [processOne, processTwo], at: start)
        expectTrue(initial.isEmpty)
        expectEqual(provider.trackedProcessIDsForTesting, Set([processOne.pid, processTwo.pid]))

        let afterOneSecond = provider.simulateFilterHighActivity(processes: [processOne], at: start.addingTimeInterval(1))
        expectTrue(afterOneSecond.isEmpty)
        expectEqual(provider.trackedProcessIDsForTesting, Set([processOne.pid]))

        let afterDwell = provider.simulateFilterHighActivity(processes: [processOne], at: start.addingTimeInterval(2.2))
        expectEqual(Set(afterDwell.map { $0.pid }), Set([processOne.pid]))
        expectEqual(provider.trackedProcessIDsForTesting, Set([processOne.pid]))
    }
}
