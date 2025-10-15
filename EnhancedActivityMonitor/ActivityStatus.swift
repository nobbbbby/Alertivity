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

enum ActivityStatus: String, Sendable, Equatable {
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
        if !metrics.hasLiveData {
            return "Collecting live metrics…"
        }

        switch self {
        case .normal:
            return "Everything looks healthy. "
        case .elevated:
            return "Usage is elevated. Keep an eye on resource-intensive tasks."
        case .critical:
            if let culprit = metrics.highActivityProcesses.first {
                return "High-activity process: \(culprit.displayName) is consuming \(culprit.cpuDescription) of CPU. Consider closing or force quitting it."
            }
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
            return symbolOrFallback("waveform.low")
        case .elevated:
            return symbolOrFallback("waveform.mid")
        case .critical:
            return "waveform"
        }
    }
}
