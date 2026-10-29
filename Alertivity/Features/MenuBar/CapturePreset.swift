#if DEBUG
import Foundation

/// Display-only snapshots never enter the sampler or the automatic notification pipeline.
enum CapturePreset: String, CaseIterable, Identifiable {
    case live = "Live readings"
    case normal = "Normal"
    case cpuElevated = "CPU · Elevated"
    case cpuCritical = "CPU · Critical"
    case memoryElevated = "Memory · Elevated"
    case memoryCritical = "Memory · Critical"
    case diskElevated = "Disk · Elevated"
    case diskCritical = "Disk · Critical"
    case networkElevated = "Network · Elevated"
    case networkCritical = "Network · Critical"

    var id: String { rawValue }

    /// Honor the effective thresholds so each preset retains its advertised severity with Pro settings.
    func metrics(thresholds: ActivityThresholds) -> ActivityMetrics? {
        guard self != .live else { return nil }
        var metrics = ActivityMetrics(
            cpuUsage: min(0.23, thresholds.cpuElevated / 2),
            memoryUsed: Measurement(value: min(0.42, thresholds.memoryElevated / 2) * 16, unit: .gigabytes),
            memoryTotal: Measurement(value: 16, unit: .gigabytes),
            runningProcesses: 100,
            network: NetworkMetrics(receivedBytesPerSecond: thresholds.networkElevatedBytesPerSecond / 10,
                                    sentBytesPerSecond: thresholds.networkElevatedBytesPerSecond / 20),
            disk: DiskMetrics(readBytesPerSecond: thresholds.diskElevatedBytesPerSecond / 10,
                              writeBytesPerSecond: thresholds.diskElevatedBytesPerSecond / 20),
            highActivityProcesses: [],
            thresholds: thresholds
        )
        switch self {
        case .cpuElevated:
            metrics.cpuUsage = (thresholds.cpuElevated + thresholds.cpuCritical) / 2
        case .cpuCritical:
            metrics.cpuUsage = (thresholds.cpuCritical + 1) / 2
        case .memoryElevated:
            metrics.memoryUsed.value = (thresholds.memoryElevated + thresholds.memoryCritical) / 2 * 16
        case .memoryCritical:
            metrics.memoryUsed.value = (thresholds.memoryCritical + 1) / 2 * 16
        case .diskElevated, .diskCritical:
            let total = self == .diskElevated
                ? (thresholds.diskElevatedBytesPerSecond + thresholds.diskCriticalBytesPerSecond) / 2
                : thresholds.diskCriticalBytesPerSecond * 1.25
            metrics.disk = DiskMetrics(readBytesPerSecond: total * 0.6, writeBytesPerSecond: total * 0.4)
        case .networkElevated, .networkCritical:
            let total = self == .networkElevated
                ? (thresholds.networkElevatedBytesPerSecond + thresholds.networkCriticalBytesPerSecond) / 2
                : thresholds.networkCriticalBytesPerSecond * 1.25
            metrics.network = NetworkMetrics(receivedBytesPerSecond: total * 0.8, sentBytesPerSecond: total * 0.2)
        case .normal, .live:
            break
        }
        return metrics
    }
}
#endif
