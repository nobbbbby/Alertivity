import Foundation

struct ActivityMetrics: Sendable {
    var cpuUsage: Double
    var memoryUsed: Measurement<UnitInformationStorage>
    var memoryTotal: Measurement<UnitInformationStorage>
    var runningProcesses: Int

    var memoryUsage: Double {
        guard memoryTotal.value > 0 else { return 0 }
        return min(max(memoryUsed.converted(to: .bytes).value / memoryTotal.converted(to: .bytes).value, 0), 1)
    }

    static let placeholder = ActivityMetrics(
        cpuUsage: 0,
        memoryUsed: Measurement(value: 0, unit: .gigabytes),
        memoryTotal: Measurement(value: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824, unit: .gigabytes),
        runningProcesses: 0
    )
}

extension ActivityMetrics {
    var cpuUsagePercentage: Double {
        min(max(cpuUsage, 0), 1)
    }
}
