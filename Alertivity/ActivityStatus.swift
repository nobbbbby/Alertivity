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

    func menuSummary(for metrics: ActivityMetrics) -> String {
        guard metrics.hasLiveData else {
            return L10n.string("status.message.collecting")
        }

        let nonNormal = nonNormalMetrics(metrics)
        if nonNormal.isEmpty {
            return L10n.string("status.message.healthy")
        }

        if nonNormal.count == 1, let only = nonNormal.first {
            return menuSingleSummary(for: only.0, severity: only.1)
        }

        let clauses = nonNormal.map { metric, severity in
            menuMultiSummaryClause(for: metric, severity: severity)
        }
        return naturalListWithCommaBeforeAnd(clauses) + "."
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

    private func naturalListWithCommaBeforeAnd(_ items: [String]) -> String {
        L10n.list(items)
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

    private func menuSingleSummary(for metric: TriggerMetric, severity: ActivityMetrics.MetricSeverity) -> String {
        switch (metric, severity) {
        case (.cpu, .elevated):
            return L10n.string("status.menu.single.cpu.elevated")
        case (.cpu, .critical):
            return L10n.string("status.menu.single.cpu.critical")
        case (.memory, .elevated):
            return L10n.string("status.menu.single.memory.elevated")
        case (.memory, .critical):
            return L10n.string("status.menu.single.memory.critical")
        case (.disk, .elevated):
            return L10n.string("status.menu.single.disk.elevated")
        case (.disk, .critical):
            return L10n.string("status.menu.single.disk.critical")
        case (.network, .elevated):
            return L10n.string("status.menu.single.network.elevated")
        case (.network, .critical):
            return L10n.string("status.menu.single.network.critical")
        case (_, .normal):
            return ""
        }
    }

    private func menuMultiSummaryClause(for metric: TriggerMetric, severity: ActivityMetrics.MetricSeverity) -> String {
        switch (metric, severity) {
        case (.cpu, .elevated):
            return L10n.string("status.menu.multi.cpu.elevated")
        case (.cpu, .critical):
            return L10n.string("status.menu.multi.cpu.critical")
        case (.memory, .elevated):
            return L10n.string("status.menu.multi.memory.elevated")
        case (.memory, .critical):
            return L10n.string("status.menu.multi.memory.critical")
        case (.disk, .elevated):
            return L10n.string("status.menu.multi.disk.elevated")
        case (.disk, .critical):
            return L10n.string("status.menu.multi.disk.critical")
        case (.network, .elevated):
            return L10n.string("status.menu.multi.network.elevated")
        case (.network, .critical):
            return L10n.string("status.menu.multi.network.critical")
        case (_, .normal):
            return ""
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
