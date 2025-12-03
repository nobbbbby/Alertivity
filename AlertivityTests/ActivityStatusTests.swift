import Testing
@testable import Alertivity

@Suite struct ActivityStatusTests {
    @Test
    func titleForMixedCriticalAndElevatedMetrics() {
        let metrics = makeMetrics(cpu: 0.9, memory: 0.75)
        let title = ActivityStatus(metrics: metrics).title(for: metrics)
        expectEqual(title, "Critical CPU; Memory elevated")
    }

    @Test
    func titleForMultipleCriticalMetrics() {
        let metrics = makeMetrics(cpu: 0.92, memory: 0.9)
        let title = ActivityStatus(metrics: metrics).title(for: metrics)
        expectEqual(title, "Multiple metrics critical")
    }

    @Test
    func menuSummaryOmitsNumericDetails() {
        let metrics = makeMetrics(cpu: 0.91, memory: 0.78)
        let summary = ActivityStatus(metrics: metrics).menuSummary(for: metrics)
        expectTrue(summary.contains("CPU exceeded critical threshold"))
        expectTrue(summary.contains("Memory above elevated threshold"))
        expectFalse(summary.contains("%"))
    }

    @Test
    func notificationMessageIncludesValuesAndSeverityTags() {
        let metrics = makeMetrics(cpu: 0.88, memory: 0.8, diskBytesPerSecond: 120_000_000)
        let message = ActivityStatus(metrics: metrics).message(for: metrics)
        expectTrue(message.contains("CPU 88% (crit)"))
        expectTrue(message.contains("Memory 80% (elev)"))
        expectTrue(message.contains("Disk"))
        expectTrue(message.contains("(crit)"))
    }

    @Test
    func normalMetricsReturnStableTitleAndSummary() {
        let metrics = makeMetrics(cpu: 0.1, memory: 0.1)
        let status = ActivityStatus(metrics: metrics)
        expectEqual(status.title(for: metrics), "System is stable")
        expectEqual(status.menuSummary(for: metrics), "Everything looks healthy.")
        expectEqual(status.message(for: ActivityMetrics.placeholder), "Collecting live metrics…")
    }

    @Test
    func elevatedSingleMetricTitleUsesMetricName() {
        let metrics = makeMetrics(cpu: 0.6, memory: 0.1)
        let title = ActivityStatus(metrics: metrics).title(for: metrics)
        expectEqual(title, "Elevated CPU")
    }

    @Test
    func menuSummaryDistinguishesCriticalAndElevatedGroups() {
        let metrics = makeMetrics(cpu: 0.9, memory: 0.82)
        let summary = ActivityStatus(metrics: metrics).menuSummary(for: metrics)
        expectTrue(summary.contains("CPU exceeded critical threshold"))
        expectTrue(summary.contains("Memory above elevated threshold"))
    }
}
