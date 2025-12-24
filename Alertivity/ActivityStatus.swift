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
            return style == .menu ? "System Is Stable" : "System is stable"
        case .elevated:
            if elevatedMetrics.count > 1 {
                return style == .menu ? "Multiple Metrics Elevated" : "Multiple metrics elevated"
            }
            if let elevated = elevatedMetrics.first {
                return "Elevated \(metricDisplayName(elevated))"
            }
            return "Elevated \(alignedStatus.triggerLabel)"
        case .critical:
            if !criticalMetrics.isEmpty, !elevatedMetrics.isEmpty {
                let criticalText: String
                if criticalMetrics.count == 1, let onlyCritical = criticalMetrics.first {
                    criticalText = "Critical \(metricDisplayName(onlyCritical))"
                } else {
                    criticalText = style == .menu ? "Multiple Metrics Critical" : "Multiple metrics critical"
                }

                let elevatedText: String
                if elevatedMetrics.count == 1, let onlyElevated = elevatedMetrics.first {
                    elevatedText = style == .menu
                        ? "\(metricDisplayName(onlyElevated)) Elevated"
                        : "\(metricDisplayName(onlyElevated)) elevated"
                } else {
                    elevatedText = style == .menu ? "Multiple Metrics Elevated" : "Multiple metrics elevated"
                }

                return "\(criticalText); \(elevatedText)"
            }

            if criticalMetrics.count > 1 {
                return style == .menu ? "Multiple Metrics Critical" : "Multiple metrics critical"
            }

            if let onlyCritical = criticalMetrics.first {
                return "Critical \(metricDisplayName(onlyCritical))"
            }

            return "Critical \(alignedStatus.triggerLabel)"
        }
    }

    func message(for metrics: ActivityMetrics) -> String {
        guard metrics.hasLiveData else {
            return "Collecting live metrics…"
        }

        let metricSummaries = notificationDescriptions(for: metrics)
        if metricSummaries.isEmpty {
            return "Everything looks healthy."
        }

        return metricSummaries.joined(separator: ", ")
    }

    func menuSummary(for metrics: ActivityMetrics) -> String {
        guard metrics.hasLiveData else {
            return "Collecting live metrics…"
        }

        let nonNormal = nonNormalMetrics(metrics)
        if nonNormal.isEmpty {
            return "Everything looks healthy."
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
        guard let trigger else { return "activity" }
        return triggerDisplayName(trigger)
    }

    private func triggerDisplayName(_ trigger: TriggerMetric) -> String {
        switch trigger {
        case .cpu:
            return "CPU"
        case .memory:
            return "Memory"
        case .disk:
            return "Disk"
        case .network:
            return "Network"
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
        switch items.count {
        case 0:
            return ""
        case 1:
            return items[0]
        case 2:
            return items[0] + ", and " + items[1]
        default:
            return items.dropLast().joined(separator: ", ") + ", and " + items.last!
        }
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
            return "\(metricDisplayName(metric)) \(valueText) (\(severityText))"
        }
    }

    private func menuSingleSummary(for metric: TriggerMetric, severity: ActivityMetrics.MetricSeverity) -> String {
        switch (metric, severity) {
        case (.cpu, .elevated):
            return "CPU activity exceeded the elevated threshold, reaching a usage of more than 50%."
        case (.cpu, .critical):
            return "CPU activity exceeded the critical threshold, reaching a usage of more than 80%."
        case (.memory, .elevated):
            return "Memory activity exceeded the elevated threshold, reaching a usage of more than 70%."
        case (.memory, .critical):
            return "Memory activity exceeded the critical threshold, reaching a usage of more than 85%."
        case (.disk, .elevated):
            return "Disk activity exceeded the elevated threshold, reaching an aggregated rate of ≥30 MB/s."
        case (.disk, .critical):
            return "Disk activity exceeded the critical threshold, reaching an aggregated rate of ≥120 MB/s."
        case (.network, .elevated):
            return "Network activity exceeded the elevated threshold, reaching an aggregated rate of ≥5 MB/s."
        case (.network, .critical):
            return "Network activity exceeded the critical threshold, reaching an aggregated rate of ≥20 MB/s."
        case (_, .normal):
            return ""
        }
    }

    private func menuMultiSummaryClause(for metric: TriggerMetric, severity: ActivityMetrics.MetricSeverity) -> String {
        switch (metric, severity) {
        case (.cpu, .elevated):
            return "CPU usage over 50% (elevated)"
        case (.cpu, .critical):
            return "CPU usage over 80% (critical)"
        case (.memory, .elevated):
            return "Memory usage over 70% (elevated)"
        case (.memory, .critical):
            return "Memory usage over 85% (critical)"
        case (.disk, .elevated):
            return "Disk activity over 30 MB/s (elevated)"
        case (.disk, .critical):
            return "Disk activity over 120 MB/s (critical)"
        case (.network, .elevated):
            return "Network activity over 5 MB/s (elevated)"
        case (.network, .critical):
            return "Network activity over 20 MB/s (critical)"
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
            return "normal"
        case .elevated:
            return "elev"
        case .critical:
            return "crit"
        }
    }
}
