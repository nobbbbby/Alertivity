import Testing
@testable import Alertivity

@Suite struct ActivityMetricsTests {
    @Test
    func cpuSeverityThresholds() {
        expectEqual(makeMetrics(cpu: 0.49, memory: 0).cpuSeverity, .normal)
        expectEqual(makeMetrics(cpu: 0.5, memory: 0).cpuSeverity, .elevated)
        expectEqual(makeMetrics(cpu: 0.8, memory: 0).cpuSeverity, .critical)
    }

    @Test
    func memorySeverityThresholds() {
        expectEqual(makeMetrics(cpu: 0, memory: 0.69).memorySeverity, .normal)
        expectEqual(makeMetrics(cpu: 0, memory: 0.7).memorySeverity, .elevated)
        expectEqual(makeMetrics(cpu: 0, memory: 0.85).memorySeverity, .critical)
    }

    @Test
    func diskAndNetworkSeverityThresholds() {
        let normal = makeMetrics(cpu: 0, memory: 0, diskBytesPerSecond: 19_000_000, networkBytesPerSecond: 4_000_000)
        expectEqual(normal.diskSeverity, .normal)
        expectEqual(normal.networkSeverity, .normal)

        let elevated = makeMetrics(cpu: 0, memory: 0, diskBytesPerSecond: 50_000_000, networkBytesPerSecond: 10_000_000)
        expectEqual(elevated.diskSeverity, .elevated)
        expectEqual(elevated.networkSeverity, .elevated)

        let critical = makeMetrics(cpu: 0, memory: 0, diskBytesPerSecond: 120_000_000, networkBytesPerSecond: 25_000_000)
        expectEqual(critical.diskSeverity, .critical)
        expectEqual(critical.networkSeverity, .critical)
    }

    @Test
    func highestSeverityMetricRespectsPriority() {
        let metrics = makeMetrics(cpu: 0.85, memory: 0.9) // both critical; CPU should win tie
        let highest = metrics.highestSeverityMetric()
        expectEqual(highest?.0, .cpu)
        expectEqual(highest?.1, .critical)
    }

    @Test
    func hasLiveDataDetectsRealSamples() {
        expectFalse(ActivityMetrics.placeholder.hasLiveData)
        let metrics = makeMetrics(cpu: 0.1, memory: 0.1, networkBytesPerSecond: 1)
        expectTrue(metrics.hasLiveData)
    }

    @Test
    func highestSeverityMetricHonorsAllowedSeverities() {
        let metrics = makeMetrics(cpu: 0.85, memory: 0.6)
        let filtered = metrics.highestSeverityMetric(allowedSeverities: [.critical])
        expectEqual(filtered?.0, .cpu)
        expectEqual(filtered?.1, .critical)

        let none = makeMetrics(cpu: 0.6, memory: 0.65)
        expectEqual(none.highestSeverityMetric(allowedSeverities: [.critical])?.0, nil)
    }
}
