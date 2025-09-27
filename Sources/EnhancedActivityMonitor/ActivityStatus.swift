import SwiftUI

enum ActivityStatus: String, Sendable {
    case normal
    case elevated
    case critical

    init(metrics: ActivityMetrics) {
        switch metrics.cpuUsage {
        case ..<0.5:
            self = .normal
        case 0.5..<0.8:
            self = .elevated
        default:
            self = .critical
        }
    }

    var title: String {
        switch self {
        case .normal:
            return "System is stable"
        case .elevated:
            return "System is warming up"
        case .critical:
            return "High activity detected"
        }
    }

    func message(for metrics: ActivityMetrics) -> String {
        switch self {
        case .normal:
            return "Everything looks healthy. CPU usage is at \(metrics.cpuUsage.formatted(.percent))"
        case .elevated:
            return "Usage is elevated. Keep an eye on resource-intensive tasks."
        case .critical:
            return "Performance may be impacted. Consider closing demanding apps."
        }
    }

    var accentColor: Color {
        switch self {
        case .normal:
            return .green
        case .elevated:
            return .yellow
        case .critical:
            return .red
        }
    }

    var symbolName: String {
        switch self {
        case .normal:
            return "waveform"
        case .elevated:
            return "waveform.circle"
        case .critical:
            return "exclamationmark.triangle"
        }
    }
}
