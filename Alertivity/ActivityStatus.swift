import SwiftUI
import Foundation
import AppKit

private func symbolOrFallback(_ name: String) -> String {
    if NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil {
        return name
    } else {
        return "waveform"
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

        let ranked: [(TriggerMetric, ActivityMetrics.MetricSeverity, Double)] = [
            (.cpu, cpuSeverity, metrics.cpuUsagePercentage),
            (.memory, memorySeverity, metrics.memoryUsage),
            (.disk, diskSeverity, metrics.disk.usage)
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
        switch level {
        case .normal:
            return .green
        case .elevated:
            return .yellow
        case .critical:
            return .red
        }
    }

    var symbolName: String {
        switch level {
        case .normal:
            return symbolOrFallback("waveform.low")
        case .elevated:
            return symbolOrFallback("waveform.mid")
        case .critical:
            return "waveform"
        }
    }

    var title: String {
        switch level {
        case .normal:
            return "System is stable"
        case .elevated:
            return "Elevated \(triggerLabel)"
        case .critical:
            return "Critical \(triggerLabel)"
        }
    }

    func message(for metrics: ActivityMetrics) -> String {
        guard metrics.hasLiveData else {
            return "Collecting live metrics…"
        }

        let nonNormalMetrics: [String] = [
            metrics.cpuSeverity != .normal ? "CPU \(metrics.cpuUsagePercentage.formatted(.percent.precision(.fractionLength(0))))" : nil,
            metrics.memorySeverity != .normal ? "Mem \(metrics.memoryUsage.formatted(.percent.precision(.fractionLength(0))))" : nil,
            metrics.diskSeverity != .normal ? "Disk \(metrics.disk.usage.formatted(.percent.precision(.fractionLength(0))))" : nil
        ].compactMap { $0 }

        let summary = nonNormalMetrics.joined(separator: ", ")

        switch level {
        case .normal:
            return "Everything looks healthy."
        case .elevated:
            let detail = summary.isEmpty ? nil : " \(summary)"
            return "Elevated activity.\(detail ?? "")"
        case .critical:
            var message = "High activity."
            if !summary.isEmpty {
                message += " \(summary)"
            }
            if let culprit = metrics.highActivityProcesses.first, trigger != .disk {
                message += " Culprit: \(culprit.displayName) @ \(culprit.cpuDescription)."
            }
            return message
        }
    }

    func notificationTitle(for metrics: ActivityMetrics) -> String {
        guard metrics.hasLiveData else { return title }
        guard let trigger else { return title }

        switch level {
        case .normal:
            return "System is stable"
        case .elevated:
            return "Elevated \(triggerDisplayName(trigger))"
        case .critical:
            return "Critical \(triggerDisplayName(trigger))"
        }
    }

    func triggerValue(for metrics: ActivityMetrics) -> Double? {
        guard let trigger else { return nil }
        switch trigger {
        case .cpu:
            return metrics.cpuUsagePercentage
        case .memory:
            return metrics.memoryUsage
        case .disk:
            return metrics.disk.usage
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
        }
    }

    private func formattedTriggerValue(for trigger: TriggerMetric, metrics: ActivityMetrics) -> String {
        switch trigger {
        case .cpu:
            return metrics.cpuUsagePercentage.formatted(.percent.precision(.fractionLength(0)))
        case .memory:
            return metrics.memoryUsage.formatted(.percent.precision(.fractionLength(0)))
        case .disk:
            return metrics.disk.usage.formatted(.percent.precision(.fractionLength(0)))
        }
    }

    static let normal = ActivityStatus(level: .normal, trigger: nil)
    static let elevated = ActivityStatus(level: .elevated, trigger: .cpu)
    static let critical = ActivityStatus(level: .critical, trigger: .cpu)

    private static func priority(for trigger: TriggerMetric) -> Int {
        switch trigger {
        case .cpu:
            return 3
        case .memory:
            return 2
        case .disk:
            return 1
        }
    }
}
