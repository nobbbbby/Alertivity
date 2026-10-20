import Foundation
import Testing
@testable import Alertivity

@Suite struct MetricMenuViewsTests {
    @Test
    func resolveMenuIconTypePrefersAutoSwitchSelection() {
        let resolved = resolveMenuIconType(
            autoSwitchEnabled: true,
            defaultIconType: .status,
            autoSwitchSelection: .memory
        )
        expectEqual(resolved, .memory)

        let fallback = resolveMenuIconType(
            autoSwitchEnabled: false,
            defaultIconType: .cpu,
            autoSwitchSelection: .memory
        )
        expectEqual(fallback, .cpu)
    }

    @Test
    func highestPriorityHighActivityFavorsCriticalMetric() {
        let memoryOnly = makeMetrics(cpu: 0.4, memory: 0.9)
        expectEqual(MetricMenuSelection.highestPriorityHighActivity(in: memoryOnly), .memory)

        let cpuAndMemory = makeMetrics(cpu: 0.92, memory: 0.92)
        expectEqual(MetricMenuSelection.highestPriorityHighActivity(in: cpuAndMemory), .cpu)
    }

    @Test
    func customPriorityBreaksSeverityTiesWithoutPromotingNormalMetrics() {
        var metrics = makeMetrics(cpu: 0.95, memory: 0.95)
        metrics.disk = DiskMetrics(readBytesPerSecond: 200_000_000, writeBytesPerSecond: 0)
        metrics.network = NetworkMetrics(receivedBytesPerSecond: 100_000_000, sentBytesPerSecond: 0)
        for metric in MetricMenuSelection.allCases {
            expectEqual(metrics.highestSeverityMetric(allowedSeverities: [.critical], priority: [metric])?.0, metric)
        }
        let memoryOnly = makeMetrics(cpu: 0.2, memory: 0.95)
        expectEqual(memoryOnly.highestSeverityMetric(allowedSeverities: [.critical], priority: [.cpu])?.0, .memory)
        let normal = makeMetrics(cpu: 0.2, memory: 0.2)
        expectEqual(normal.highestSeverityMetric(allowedSeverities: [.critical], priority: [.network])?.0, nil)
        // Custom menu order does not affect the default severity ranking used elsewhere.
        expectEqual(metrics.highestSeverityMetric()?.0, .cpu)
    }

    @Test
    func formattedValuesAreMetricSpecific() {
        let metrics = ActivityMetrics(
            cpuUsage: 0.42,
            memoryUsed: Measurement(value: 8, unit: .gigabytes),
            memoryTotal: Measurement(value: 16, unit: .gigabytes),
            runningProcesses: 5,
            network: NetworkMetrics(receivedBytesPerSecond: 1_200_000, sentBytesPerSecond: 800_000),
            disk: DiskMetrics(readBytesPerSecond: 2_000_000, writeBytesPerSecond: 3_000_000),
            highActivityProcesses: []
        )

        expectEqual(MetricMenuSelection.cpu.formattedValue(for: metrics), "42%")
        expectEqual(MetricMenuSelection.memory.formattedValue(for: metrics), "50%")

        let diskValue = MetricMenuSelection.disk.formattedValue(for: metrics)
        expectTrue(diskValue.contains("/s"))
        expectTrue(diskValue.lowercased().contains("b"))

        let networkValue = MetricMenuSelection.network.formattedValue(for: metrics)
        expectTrue(networkValue.contains("/s"))
    }

    @Test
    func detailAndAccessibilitySummariesAreReadable() {
        let metrics = ActivityMetrics(
            cpuUsage: 0.57,
            memoryUsed: Measurement(value: 9, unit: .gigabytes),
            memoryTotal: Measurement(value: 16, unit: .gigabytes),
            runningProcesses: 12,
            network: NetworkMetrics(receivedBytesPerSecond: 1_600_000, sentBytesPerSecond: 1_200_000),
            disk: DiskMetrics(readBytesPerSecond: 4_000_000, writeBytesPerSecond: 5_000_000),
            highActivityProcesses: []
        )

        let memorySummary = MetricMenuSelection.memory.detailSummary(for: metrics)
        expectTrue(memorySummary.contains("Using"))
        expectTrue(memorySummary.contains("of"))

        let diskSummary = MetricMenuSelection.disk.detailSummary(for: metrics)
        expectTrue(diskSummary.contains("↑"))
        expectTrue(diskSummary.contains("total"))

        let networkSummary = MetricMenuSelection.network.detailSummary(for: metrics)
        expectTrue(networkSummary.contains("↓"))
        expectTrue(networkSummary.contains("↑"))

        let memoryAX = MetricMenuSelection.memory.accessibilityValue(for: metrics)
        expectTrue(memoryAX.lowercased().contains("memory usage"))
        expectTrue(memoryAX.contains("%"))
    }

    @Test
    func menuIconTypeMappingReflectsMetricSelection() {
        expectEqual(MenuIconType.status.metricSelection, nil)
        expectEqual(MenuIconType.cpu.metricSelection, .cpu)
        expectEqual(MenuIconType.network.metricSelection, .network)
    }

    @Test
    func autoSwitchUsesConfiguredThresholds() {
        guard let thresholds = ActivityThresholds(
            cpuElevatedPercent: 20,
            cpuCriticalPercent: 30,
            memoryElevatedPercent: 70,
            memoryCriticalPercent: 90,
            diskElevatedMegabytesPerSecond: 30,
            diskCriticalMegabytesPerSecond: 120,
            networkElevatedMegabytesPerSecond: 5,
            networkCriticalMegabytesPerSecond: 20
        ) else {
            Issue.record("Expected valid custom thresholds")
            return
        }
        var metrics = makeMetrics(cpu: 0.35, memory: 0.4)
        metrics.thresholds = thresholds
        expectEqual(MetricMenuSelection.highestPriorityHighActivity(in: metrics), .cpu)
    }
}
