import Testing
import Foundation
@testable import Alertivity

private final class StubMetricsProvider: SystemMetricsProviding {
    var highActivityDuration: TimeInterval = 60
    var highActivityCPUThreshold: Double = 0.8
    var highActivityMemoryThreshold: Double = 0.25
    var ignoredProcessPaths: Set<String> = []
    var processSamplingAvailable: Bool = true
    var queue: [ActivityMetrics] = []

    func enqueue(_ metrics: ActivityMetrics) {
        queue.append(metrics)
    }

    func fetchMetrics() -> ActivityMetrics {
        guard !queue.isEmpty else { return .placeholder }
        return queue.removeFirst()
    }
}

@Suite struct ActivityMonitorIntegrationTests {
    @Test
    func statusTransitionRequiresConsecutiveSamples() {
        let provider = StubMetricsProvider()
        let monitor = ActivityMonitor(autoStart: false, provider: provider)

        let criticalMetrics = makeMetrics(cpu: 0.9, memory: 0.7)
        monitor.ingest(metrics: criticalMetrics)
        expectEqual(monitor.status.level, .normal)

        monitor.ingest(metrics: criticalMetrics)
        expectEqual(monitor.status.level, .critical)
        expectEqual(monitor.status.trigger, .cpu)
    }

    @Test
    func updatesProviderThresholdsViaProxy() {
        let provider = StubMetricsProvider()
        let monitor = ActivityMonitor(autoStart: false, provider: provider)

        monitor.highActivityCPUThreshold = 0.5
        monitor.highActivityMemoryThreshold = 0.25
        monitor.highActivityDuration = 30

        expectEqual(provider.highActivityCPUThreshold, 0.5)
        expectEqual(provider.highActivityMemoryThreshold, 0.25)
        expectEqual(provider.highActivityDuration, 30)
    }

    @Test
    func statusDropRequiresConsecutiveSamples() {
        let provider = StubMetricsProvider()
        let monitor = ActivityMonitor(autoStart: false, provider: provider)

        let critical = makeMetrics(cpu: 0.9, memory: 0.7)
        monitor.ingest(metrics: critical)
        monitor.ingest(metrics: critical)
        expectEqual(monitor.status.level, .critical)

        let normal = makeMetrics(cpu: 0.1, memory: 0.1)
        monitor.ingest(metrics: normal)
        expectEqual(monitor.status.level, .critical, "single sample should not drop status")

        monitor.ingest(metrics: normal)
        expectEqual(monitor.status.level, .normal)
    }

    @Test
    func thresholdChangesReevaluateCurrentMetricsWithoutResettingStabilization() {
        let monitor = ActivityMonitor(autoStart: false, provider: StubMetricsProvider())
        let sample = makeMetrics(cpu: 0.45, memory: 0.2)
        monitor.ingest(metrics: sample)
        expectEqual(monitor.metrics.cpuSeverity, .normal)

        guard let thresholds = ActivityThresholds(
            cpuElevatedPercent: 20,
            cpuCriticalPercent: 40,
            memoryElevatedPercent: 70,
            memoryCriticalPercent: 85,
            diskElevatedMegabytesPerSecond: 30,
            diskCriticalMegabytesPerSecond: 120,
            networkElevatedMegabytesPerSecond: 5,
            networkCriticalMegabytesPerSecond: 20
        ) else {
            Issue.record("Expected valid custom thresholds")
            return
        }

        monitor.activityThresholds = thresholds
        expectEqual(monitor.metrics.cpuSeverity, .critical)
        expectEqual(monitor.status.level, .normal, "first reevaluation should preserve stabilization")

        monitor.ingest(metrics: sample)
        expectEqual(monitor.status.level, .critical)
    }
}
