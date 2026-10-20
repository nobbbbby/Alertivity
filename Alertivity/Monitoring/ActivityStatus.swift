import SwiftUI
import Foundation

struct StatusColorPalette {
    static let normal = Color.primary
    static let elevated = Color.yellow
    static let critical = Color.red

    static func color(for level: ActivityStatus.Level) -> Color {
        switch level {
        case .normal:
            return normal
        case .elevated:
            return elevated
        case .critical:
            return critical
        }
    }

    static func color(for severity: ActivityMetrics.MetricSeverity) -> Color? {
        switch severity {
        case .normal:
            return nil
        case .elevated:
            return elevated
        case .critical:
            return critical
        }
    }
}

struct ActivityStatus: Sendable, Equatable {
    enum Level: String, Sendable {
        case normal
        case elevated
        case critical
    }

    enum TriggerMetric: String, Sendable {
        case cpu
        case memory
        case disk
        case network
    }

    let level: Level
    let trigger: TriggerMetric?

    init(level: Level, trigger: TriggerMetric?) {
        self.level = level
        self.trigger = trigger
    }

    init(metrics: ActivityMetrics) {
        let cpuSeverity = metrics.cpuSeverity
        let memorySeverity = metrics.memorySeverity
        let diskSeverity = metrics.diskSeverity
        let networkSeverity = metrics.networkSeverity

        let ranked: [(TriggerMetric, ActivityMetrics.MetricSeverity, Double)] = [
            (.cpu, cpuSeverity, metrics.cpuUsagePercentage),
            (.memory, memorySeverity, metrics.memoryUsage),
            (.disk, diskSeverity, metrics.disk.totalBytesPerSecond),
            (.network, networkSeverity, metrics.network.totalBytesPerSecond)
        ]

        let highest = ranked.max { lhs, rhs in
            if lhs.1 == rhs.1 {
                return ActivityStatus.priority(for: lhs.0) < ActivityStatus.priority(for: rhs.0)
            }
            return lhs.1.rawValue < rhs.1.rawValue
        }

        if let highest, highest.1 != .normal {
            level = ActivityStatus.level(for: highest.1)
            trigger = highest.0
        } else {
            level = .normal
            trigger = nil
        }
    }

    private static func level(for severity: ActivityMetrics.MetricSeverity) -> Level {
        switch severity {
        case .critical:
            return .critical
        case .elevated:
            return .elevated
        case .normal:
            return .normal
        }
    }

    var accentColor: Color {
        StatusColorPalette.color(for: level)
    }

    var iconTint: Color? {
        switch level {
        case .normal:
            return nil
            
        case .elevated, .critical:
            return accentColor
        }
    }

    var symbolName: String {
        switch level {
        case .normal:
            return "waveform.path.ecg"
        case .elevated:
            return "waveform.path.ecg"
        case .critical:
            return "waveform.path"
        }
    }

    private enum TitleStyle {
        case menu
        case notification
    }

    func menuTitle(for metrics: ActivityMetrics) -> String {
        title(for: metrics, style: .menu)
    }

    func notificationTitle(for metrics: ActivityMetrics) -> String {
        title(for: metrics, style: .notification)
    }

    private func title(for metrics: ActivityMetrics, style: TitleStyle) -> String {
        let alignedStatus = statusAligned(to: metrics)
        let criticalMetrics = metricsBySeverity(metrics, target: .critical)
        let elevatedMetrics = metricsBySeverity(metrics, target: .elevated)

        switch alignedStatus.level {
        case .normal:
            return style == .menu
                ? L10n.string("status.title.menu.normal")
                : L10n.string("status.title.notification.normal")
        case .elevated:
            if elevatedMetrics.count > 1 {
                return style == .menu
                    ? L10n.string("status.title.menu.multipleElevated")
                    : L10n.string("status.title.notification.multipleElevated")
            }
            if let elevated = elevatedMetrics.first {
                return L10n.format("status.title.elevated.single", metricDisplayName(elevated))
            }
            return L10n.format("status.title.elevated.single", alignedStatus.triggerLabel)
        case .critical:
            if !criticalMetrics.isEmpty, !elevatedMetrics.isEmpty {
                let criticalText: String
                if criticalMetrics.count == 1, let onlyCritical = criticalMetrics.first {
                    criticalText = L10n.format("status.title.critical.single", metricDisplayName(onlyCritical))
                } else {
                    criticalText = style == .menu
                        ? L10n.string("status.title.menu.multipleCritical")
                        : L10n.string("status.title.notification.multipleCritical")
                }

                let elevatedText: String
                if elevatedMetrics.count == 1, let onlyElevated = elevatedMetrics.first {
                    elevatedText = style == .menu
                        ? L10n.format("status.title.elevated.metric.menu", metricDisplayName(onlyElevated))
                        : L10n.format("status.title.elevated.metric.notification", metricDisplayName(onlyElevated))
                } else {
                    elevatedText = style == .menu
                        ? L10n.string("status.title.menu.multipleElevated")
                        : L10n.string("status.title.notification.multipleElevated")
                }

                return L10n.format("status.title.combined", criticalText, elevatedText)
            }

            if criticalMetrics.count > 1 {
                return style == .menu
                    ? L10n.string("status.title.menu.multipleCritical")
                    : L10n.string("status.title.notification.multipleCritical")
            }

            if let onlyCritical = criticalMetrics.first {
                return L10n.format("status.title.critical.single", metricDisplayName(onlyCritical))
            }

            return L10n.format("status.title.critical.single", alignedStatus.triggerLabel)
        }
    }

    func message(for metrics: ActivityMetrics) -> String {
        guard metrics.hasLiveData else {
            return L10n.string("status.message.collecting")
        }

        let metricSummaries = notificationDescriptions(for: metrics)
        if metricSummaries.isEmpty {
            return L10n.string("status.message.healthy")
        }

        return metricSummaries.joined(separator: ", ")
    }

    /// Explains which configured alert thresholds were reached, rather than repeating live readings.
    /// Menu-only strings keep notification wording independent. Formatting runs on each refresh,
    /// so it deliberately emits no logs; metric collection and alert delivery own observability.
    func menuSummary(for metrics: ActivityMetrics) -> String {
        guard metrics.hasLiveData else {
            return L10n.string("status.menu.collecting")
        }

        let affected = nonNormalMetrics(metrics)
        guard !affected.isEmpty else {
            return L10n.string("status.menu.normal")
        }

        let clauses = affected.map { metric, severity in
            let threshold = formattedThreshold(for: metric, severity: severity, thresholds: metrics.thresholds)
            let key = (metric == .cpu || metric == .memory)
                ? "status.menu.threshold.percent"
                : "status.menu.threshold.throughput"
            return L10n.format(key, metricDisplayName(metric), threshold)
        }
        return L10n.format(
            affected.count == 1 ? "status.menu.threshold.single" : "status.menu.threshold.multiple",
            L10n.list(clauses)
        )
    }

    func triggerValue(for metrics: ActivityMetrics) -> Double? {
        guard let trigger else { return nil }
        switch trigger {
        case .cpu:
            return metrics.cpuUsagePercentage
        case .memory:
            return metrics.memoryUsage
        case .disk:
            return metrics.disk.totalBytesPerSecond
        case .network:
            return metrics.network.totalBytesPerSecond
        }
    }

    private var triggerLabel: String {
        guard let trigger else { return L10n.string("status.trigger.activity") }
        return triggerDisplayName(trigger)
    }

    private func triggerDisplayName(_ trigger: TriggerMetric) -> String {
        switch trigger {
        case .cpu:
            return L10n.string("status.metric.cpu")
        case .memory:
            return L10n.string("status.metric.memory")
        case .disk:
            return L10n.string("status.metric.disk")
        case .network:
            return L10n.string("status.metric.network")
        }
    }

    private func metricDisplayName(_ metric: TriggerMetric) -> String {
        triggerDisplayName(metric)
    }

    private func formattedTriggerValue(for trigger: TriggerMetric, metrics: ActivityMetrics) -> String {
        switch trigger {
        case .cpu:
            return metrics.cpuUsagePercentage.formatted(.percent.precision(.fractionLength(0)))
        case .memory:
            return metrics.memoryUsage.formatted(.percent.precision(.fractionLength(0)))
        case .disk:
            return metrics.disk.formattedTotalPerSecond + "/s"
        case .network:
            return metrics.network.formattedBytesPerSecond(metrics.network.totalBytesPerSecond) + "/s"
        }
    }

    static let normal = ActivityStatus(level: .normal, trigger: nil)
    static let elevated = ActivityStatus(level: .elevated, trigger: .cpu)
    static let critical = ActivityStatus(level: .critical, trigger: .cpu)

    /// Keeps user-facing copy in sync with the latest metrics even if the stored status lags or differs.
    private func statusAligned(to metrics: ActivityMetrics) -> ActivityStatus {
        let metricsStatus = ActivityStatus(metrics: metrics)
        return metricsStatus
    }

    private func metricsBySeverity(_ metrics: ActivityMetrics, target: ActivityMetrics.MetricSeverity) -> [TriggerMetric] {
        let pairs: [(TriggerMetric, ActivityMetrics.MetricSeverity)] = [
            (.cpu, metrics.cpuSeverity),
            (.memory, metrics.memorySeverity),
            (.disk, metrics.diskSeverity),
            (.network, metrics.networkSeverity)
        ]
        return pairs.filter { $0.1 == target }.map { $0.0 }
    }

    private func nonNormalMetrics(_ metrics: ActivityMetrics) -> [(TriggerMetric, ActivityMetrics.MetricSeverity)] {
        let pairs: [(TriggerMetric, ActivityMetrics.MetricSeverity)] = [
            (.cpu, metrics.cpuSeverity),
            (.memory, metrics.memorySeverity),
            (.disk, metrics.diskSeverity),
            (.network, metrics.networkSeverity)
        ]

        return pairs
            .filter { $0.1 != .normal }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return ActivityStatus.priority(for: lhs.0) > ActivityStatus.priority(for: rhs.0)
                }
                return lhs.1.rawValue > rhs.1.rawValue
            }
    }

    private static func priority(for trigger: TriggerMetric) -> Int {
        switch trigger {
        case .cpu:
            return 4
        case .memory:
            return 3
        case .disk:
            return 2
        case .network:
            return 1
        }
    }

    private func notificationDescriptions(for metrics: ActivityMetrics) -> [String] {
        nonNormalMetrics(metrics).map { metric, severity in
            let valueText = formattedValue(for: metric, metrics: metrics)
            let severityText = severityTag(for: severity)
            return L10n.format(
                "status.message.metricSummary",
                metricDisplayName(metric),
                valueText,
                severityText
            )
        }
    }

    private func formattedThreshold(
        for metric: TriggerMetric,
        severity: ActivityMetrics.MetricSeverity,
        thresholds: ActivityThresholds
    ) -> String {
        let value: Double
        switch (metric, severity) {
        case (.cpu, .elevated): value = thresholds.cpuElevatedPercent
        case (.cpu, .critical): value = thresholds.cpuCriticalPercent
        case (.memory, .elevated): value = thresholds.memoryElevatedPercent
        case (.memory, .critical): value = thresholds.memoryCriticalPercent
        case (.disk, .elevated): value = thresholds.diskElevatedMegabytesPerSecond
        case (.disk, .critical): value = thresholds.diskCriticalMegabytesPerSecond
        case (.network, .elevated): value = thresholds.networkElevatedMegabytesPerSecond
        case (.network, .critical): value = thresholds.networkCriticalMegabytesPerSecond
        case (_, .normal): value = 0
        }
        switch metric {
        case .cpu, .memory:
            return (value / 100).formatted(.percent.precision(.fractionLength(0...2)))
        case .disk, .network:
            return value.formatted(.number.precision(.fractionLength(0...2)))
        }
    }

    private func formattedValue(for metric: TriggerMetric, metrics: ActivityMetrics) -> String {
        switch metric {
        case .cpu:
            return metrics.cpuUsagePercentage.formatted(.percent.precision(.fractionLength(0)))
        case .memory:
            return metrics.memoryUsage.formatted(.percent.precision(.fractionLength(0)))
        case .disk:
            return metrics.disk.formattedTotalPerSecond + "/s"
        case .network:
            return metrics.network.formattedBytesPerSecond(metrics.network.totalBytesPerSecond) + "/s"
        }
    }

    private func severityTag(for severity: ActivityMetrics.MetricSeverity) -> String {
        switch severity {
        case .normal:
            return L10n.string("status.severity.normal")
        case .elevated:
            return L10n.string("status.severity.elevated.abbrev")
        case .critical:
            return L10n.string("status.severity.critical.abbrev")
        }
    }
}
