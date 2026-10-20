import Foundation
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
        expectEqual(summary, "Alert thresholds reached: CPU 80% and Memory 70%.")
    }

    @Test
    func menuSummarySingleMetricUsesConciseThreshold() {
        let metrics = makeMetrics(cpu: 0.1, memory: 0.1, diskBytesPerSecond: 150_000_000)
        let summary = ActivityStatus(metrics: metrics).menuSummary(for: metrics)
        expectEqual(summary, "Alert threshold reached: Disk 120 MB/s.")
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
        expectEqual(status.menuSummary(for: metrics), "All metrics below alert thresholds.")
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
    func menuSummaryKeepsCriticalMetricsFirst() {
        let metrics = makeMetrics(cpu: 0.6, memory: 0.9)
        let summary = ActivityStatus(metrics: metrics).menuSummary(for: metrics)
        expectEqual(summary, "Alert thresholds reached: Memory 85% and CPU 50%.")
    }

    @Test
    func menuSummaryCoversEverySeverityCombinationAndLoading() {
        expectEqual(ActivityStatus.critical.menuSummary(for: .placeholder), "Checking system activity…")
        let names = ["CPU", "Memory", "Disk", "Network"]
        let thresholds = [["", "50%", "80%"], ["", "70%", "85%"],
                          ["", "30 MB/s", "120 MB/s"], ["", "5 MB/s", "20 MB/s"]]
        var summaries = Set<String>()
        for cpu in 0...2 {
            for memory in 0...2 {
                for disk in 0...2 {
                    for network in 0...2 {
                        let levels = [cpu, memory, disk, network]
                        let metrics = makeMetrics(
                            cpu: [0.1, 0.6, 0.9][cpu], memory: [0.1, 0.75, 0.9][memory],
                            diskBytesPerSecond: [0, 60_000_000, 150_000_000][disk],
                            networkBytesPerSecond: [0, 10_000_000, 25_000_000][network]
                        )
                        // Independent fixture: critical metrics first, then elevated, with metric-order ties.
                        let clauses = [2, 1].flatMap { severity in
                            names.indices.filter { levels[$0] == severity }.map {
                                "\(names[$0]) \(thresholds[$0][severity])"
                            }
                        }
                        let expected: String
                        if clauses.isEmpty {
                            expected = "All metrics below alert thresholds."
                        } else {
                            let prefix = clauses.count == 1 ? "Alert threshold reached" : "Alert thresholds reached"
                            expected = "\(prefix): \(ListFormatter.localizedString(byJoining: clauses))."
                        }
                        let summary = ActivityStatus(metrics: metrics).menuSummary(for: metrics)
                        expectEqual(summary, expected, "Severity combination: \(levels)")
                        summaries.insert(summary)
                    }
                }
            }
        }
        expectEqual(summaries.count, 81)
    }

    @Test
    func menuSummaryUsesFractionalCustomThresholdsAtEquality() throws {
        let thresholds = try #require(ActivityThresholds(
            cpuElevatedPercent: 37.5, cpuCriticalPercent: 62.5,
            memoryElevatedPercent: 62.5, memoryCriticalPercent: 87.5,
            diskElevatedMegabytesPerSecond: 12.5, diskCriticalMegabytesPerSecond: 25.5,
            networkElevatedMegabytesPerSecond: 1.25, networkCriticalMegabytesPerSecond: 2.5
        ))
        for critical in [false, true] {
            var metrics = makeMetrics(
                cpu: critical ? 0.625 : 0.375, memory: critical ? 0.875 : 0.625,
                diskBytesPerSecond: critical ? 25_500_000 : 12_500_000,
                networkBytesPerSecond: critical ? 2_500_000 : 1_250_000
            )
            metrics.thresholds = thresholds
            let expected = critical
                ? "Alert thresholds reached: CPU 62.5%, Memory 87.5%, Disk 25.5 MB/s, and Network 2.5 MB/s."
                : "Alert thresholds reached: CPU 37.5%, Memory 62.5%, Disk 12.5 MB/s, and Network 1.25 MB/s."
            expectEqual(ActivityStatus(metrics: metrics).menuSummary(for: metrics), expected)
        }
        var below = makeMetrics(cpu: 0.3749, memory: 0.6249,
                                diskBytesPerSecond: 12_499_999, networkBytesPerSecond: 1_249_999)
        below.thresholds = thresholds
        expectEqual(ActivityStatus(metrics: below).menuSummary(for: below), "All metrics below alert thresholds.")
    }
}
