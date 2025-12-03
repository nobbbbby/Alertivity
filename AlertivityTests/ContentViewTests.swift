import Foundation
import Testing
@testable import Alertivity

@Suite struct ContentViewTests {
    @Test
    func menuStatusViewRendersLiveMetricsWithProcesses() {
        let process = ProcessUsage(
            pid: 42,
            command: "/Applications/Safari.app/Contents/MacOS/Safari",
            cpuPercent: 0.72,
            memoryPercent: 0.1,
            triggers: [.cpu]
        )

        let metrics = ActivityMetrics(
            cpuUsage: 0.91,
            memoryUsed: Measurement(value: 10, unit: .gigabytes),
            memoryTotal: Measurement(value: 16, unit: .gigabytes),
            runningProcesses: 120,
            network: NetworkMetrics(receivedBytesPerSecond: 2_400_000, sentBytesPerSecond: 1_900_000),
            disk: DiskMetrics(readBytesPerSecond: 1_000_000, writeBytesPerSecond: 1_200_000),
            highActivityProcesses: [process]
        )

        let view = MenuStatusView(metrics: metrics)
        _ = view.body
        expectTrue(metrics.hasLiveData)
        expectEqual(ActivityStatus(metrics: metrics).trigger, .cpu)
    }

    @Test
    func menuStatusViewHandlesPlaceholderState() {
        let placeholderView = MenuStatusView(metrics: .placeholder)
        _ = placeholderView.body
        expectFalse(ActivityMetrics.placeholder.hasLiveData)
    }
}
