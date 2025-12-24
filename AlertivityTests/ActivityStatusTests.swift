import Testing
@testable import Alertivity

@Suite struct ActivityStatusTests {
    @Test
    func titleForMixedCriticalAndElevatedMetrics() {
        let metrics = makeMetrics(cpu: 0.9, memory: 0.75)
        let title = ActivityStatus(metrics: metrics).notificationTitle(for: metrics)
        expectEqual(title, "Critical CPU; Memory elevated")
    }

    @Test
    func titleForMultipleCriticalMetrics() {
        let metrics = makeMetrics(cpu: 0.92, memory: 0.9)
        let title = ActivityStatus(metrics: metrics).notificationTitle(for: metrics)
        expectEqual(title, "Multiple metrics critical")
    }

    @Test
    func menuSummaryUsesThresholdBasedPhrasing() {
        let metrics = makeMetrics(cpu: 0.91, memory: 0.78)
        let summary = ActivityStatus(metrics: metrics).menuSummary(for: metrics)
        expectTrue(summary.contains("CPU usage over 80% (critical)"))
        expectTrue(summary.contains("Memory usage over 70% (elevated)"))
    }

    @Test
    func menuSummarySingleMetricUsesFullSentence() {
        let metrics = makeMetrics(cpu: 0.1, memory: 0.1, diskBytesPerSecond: 150_000_000)
        let summary = ActivityStatus(metrics: metrics).menuSummary(for: metrics)
        expectEqual(summary, "Disk activity exceeded the critical threshold, reaching an aggregated rate of ≥120 MB/s.")
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
        expectEqual(status.notificationTitle(for: metrics), "System is stable")
        expectEqual(status.menuTitle(for: metrics), "System Is Stable")
        expectEqual(status.menuSummary(for: metrics), "Everything looks healthy.")
        expectEqual(status.message(for: ActivityMetrics.placeholder), "Collecting live metrics…")
    }

    @Test
    func elevatedSingleMetricTitleUsesMetricName() {
        let metrics = makeMetrics(cpu: 0.6, memory: 0.1)
        let title = ActivityStatus(metrics: metrics).menuTitle(for: metrics)
        expectEqual(title, "Elevated CPU")
    }

    @Test
    func menuTitleUsesMultipleMetricsLabelForElevated() {
        let metrics = makeMetrics(cpu: 0.6, memory: 0.75)
        let title = ActivityStatus(metrics: metrics).menuTitle(for: metrics)
        expectEqual(title, "Multiple Metrics Elevated")
    }

    @Test
    func notificationTitleCollapsesMultipleElevatedInMixedState() {
        let metrics = makeMetrics(cpu: 0.9, memory: 0.75, diskBytesPerSecond: 60_000_000)
        let title = ActivityStatus(metrics: metrics).notificationTitle(for: metrics)
        expectEqual(title, "Critical CPU; Multiple metrics elevated")
    }

    @Test
    func menuSummaryDistinguishesCriticalAndElevatedGroups() {
        let metrics = makeMetrics(cpu: 0.9, memory: 0.82)
        let summary = ActivityStatus(metrics: metrics).menuSummary(for: metrics)
        expectTrue(summary.contains("CPU usage over 80% (critical)"))
        expectTrue(summary.contains("Memory usage over 70% (elevated)"))
    }
}
