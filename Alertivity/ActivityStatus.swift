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

    func title(for metrics: ActivityMetrics) -> String {
        let alignedStatus = statusAligned(to: metrics)
        let activeMetrics = elevatedOrCriticalMetrics(in: metrics)
        let criticalMetrics = metricsBySeverity(metrics, target: .critical)
        let elevatedMetrics = metricsBySeverity(metrics, target: .elevated)

        switch alignedStatus.level {
        case .normal:
            return "System is stable"
        case .elevated:
            if activeMetrics.count > 1 {
                return "Multiple metrics elevated"
            } else {
                return "Elevated \(alignedStatus.triggerLabel)"
            }
        case .critical:
            if criticalMetrics.count > 1, elevatedMetrics.isEmpty {
                return "Multiple metrics critical"
            } else if !criticalMetrics.isEmpty, !elevatedMetrics.isEmpty {
                let criticalList = listMetrics(criticalMetrics)
                let elevatedList = listMetrics(elevatedMetrics)
                return "Critical \(criticalList); \(elevatedList) elevated"
            } else if criticalMetrics.count > 1 {
                return "Critical \(listMetrics(criticalMetrics))"
            } else {
                return "Critical \(alignedStatus.triggerLabel)"
            }
        }
    }

    func message(for metrics: ActivityMetrics) -> String {
        let alignedStatus = statusAligned(to: metrics)
        guard metrics.hasLiveData else {
            return "Collecting live metrics…"
        }

        let metricSummaries = statusMessageDescriptions(for: metrics)

        var message: String
        if metricSummaries.isEmpty {
            message = "Everything looks healthy."
        } else {
            message = metricSummaries.joined(separator: "; ")
        }

        if let culprit = metrics.highActivityProcesses.first, alignedStatus.trigger != .disk {
            message += " Culprit: \(culprit.displayName) @ \(culprit.cpuDescription)."
        }

        return message
    }

    func notificationTitle(for metrics: ActivityMetrics) -> String {
        title(for: metrics)
    }

    func menuSummary(for metrics: ActivityMetrics) -> String {
        guard metrics.hasLiveData else {
            return "Collecting live metrics…"
        }

        let metricSummaries = menuThresholdDescriptions(for: metrics)
        if metricSummaries.isEmpty {
            return "Everything looks healthy."
        }

        return metricSummaries.joined(separator: "; ")
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
            return "Disk throughput"
        case .network:
            return "Network throughput"
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

    private func listMetrics(_ metrics: [TriggerMetric]) -> String {
        metrics.map { metricDisplayName($0) }.joined(separator: ", ")
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

    private func elevatedOrCriticalMetrics(in metrics: ActivityMetrics) -> [TriggerMetric] {
        var results: [TriggerMetric] = []
        if metrics.cpuSeverity != .normal {
            results.append(.cpu)
        }
        if metrics.memorySeverity != .normal {
            results.append(.memory)
        }
        if metrics.diskSeverity != .normal {
            results.append(.disk)
        }
        if metrics.networkSeverity != .normal {
            results.append(.network)
        }
        return results
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

    private func statusMessageDescriptions(for metrics: ActivityMetrics) -> [String] {
        let pairs: [(TriggerMetric, ActivityMetrics.MetricSeverity)] = [
            (.cpu, metrics.cpuSeverity),
            (.memory, metrics.memorySeverity),
            (.disk, metrics.diskSeverity),
            (.network, metrics.networkSeverity)
        ]

        return pairs.compactMap { metric, severity in
            guard severity != .normal else { return nil }
            let valueText = formattedValue(for: metric, metrics: metrics)
            let severityText = severityLabel(for: severity)
            return "\(metricDisplayName(metric)) \(severityText) (\(valueText))"
        }
    }

    private func menuThresholdDescriptions(for metrics: ActivityMetrics) -> [String] {
        let pairs: [(TriggerMetric, ActivityMetrics.MetricSeverity)] = [
            (.cpu, metrics.cpuSeverity),
            (.memory, metrics.memorySeverity),
            (.disk, metrics.diskSeverity),
            (.network, metrics.networkSeverity)
        ]

        return pairs.compactMap { metric, severity in
            guard severity != .normal else { return nil }
            let valueText = formattedValue(for: metric, metrics: metrics)
            if let thresholdText = thresholdDescription(for: metric, severity: severity, metrics: metrics) {
                return "\(metricDisplayName(metric)) \(valueText) (\(thresholdText))"
            }
            return "\(metricDisplayName(metric)) \(valueText)"
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

    private func thresholdDescription(for metric: TriggerMetric, severity: ActivityMetrics.MetricSeverity, metrics: ActivityMetrics) -> String? {
        switch (metric, severity) {
        case (.cpu, .elevated):
            return "≥50%"
        case (.cpu, .critical):
            return "≥80%"
        case (.memory, .elevated):
            return "≥70%"
        case (.memory, .critical):
            return "≥85%"
        case (.disk, .elevated):
            return "≥\(metrics.disk.formattedBytesPerSecond(20_000_000))/s"
        case (.disk, .critical):
            return "≥\(metrics.disk.formattedBytesPerSecond(100_000_000))/s"
        case (.network, .elevated):
            return "≥\(metrics.network.formattedBytesPerSecond(5_000_000))/s"
        case (.network, .critical):
            return "≥\(metrics.network.formattedBytesPerSecond(20_000_000))/s"
        default:
            return nil
        }
    }

    private func severityLabel(for severity: ActivityMetrics.MetricSeverity) -> String {
        switch severity {
        case .normal:
            return "normal"
        case .elevated:
            return "elevated"
        case .critical:
            return "critical"
        }
    }
}
