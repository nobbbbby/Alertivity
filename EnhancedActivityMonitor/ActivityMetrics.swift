import Foundation

struct ActivityMetrics: Sendable {
    var cpuUsage: Double
    var memoryUsed: Measurement<UnitInformationStorage>
    var memoryTotal: Measurement<UnitInformationStorage>
    var runningProcesses: Int
    var network: NetworkMetrics
    var disk: DiskMetrics

    var memoryUsage: Double {
        guard memoryTotal.value > 0 else { return 0 }
        return min(max(memoryUsed.converted(to: .bytes).value / memoryTotal.converted(to: .bytes).value, 0), 1)
    }

    static let placeholder = ActivityMetrics(
        cpuUsage: 0,
        memoryUsed: Measurement(value: 0, unit: .gigabytes),
        memoryTotal: Measurement(value: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824, unit: .gigabytes),
        runningProcesses: 0,
        network: .zero,
        disk: .placeholder
    )
}

extension ActivityMetrics {
    var cpuUsagePercentage: Double {
        min(max(cpuUsage, 0), 1)
    }

    static let previewNormal = ActivityMetrics(
        cpuUsage: 0.23,
        memoryUsed: Measurement(value: 6, unit: .gigabytes),
        memoryTotal: Measurement(value: 16, unit: .gigabytes),
        runningProcesses: 98,
        network: NetworkMetrics(
            receivedBytesPerSecond: 1_200_000,
            sentBytesPerSecond: 820_000
        ),
        disk: DiskMetrics(
            used: Measurement(value: 380, unit: .gigabytes),
            total: Measurement(value: 512, unit: .gigabytes)
        )
    )

    static let previewElevated = ActivityMetrics(
        cpuUsage: 0.67,
        memoryUsed: Measurement(value: 9, unit: .gigabytes),
        memoryTotal: Measurement(value: 16, unit: .gigabytes),
        runningProcesses: 134,
        network: NetworkMetrics(
            receivedBytesPerSecond: 6_300_000,
            sentBytesPerSecond: 4_800_000
        ),
        disk: DiskMetrics(
            used: Measurement(value: 410, unit: .gigabytes),
            total: Measurement(value: 512, unit: .gigabytes)
        )
    )

    static let previewCritical = ActivityMetrics(
        cpuUsage: 0.92,
        memoryUsed: Measurement(value: 14, unit: .gigabytes),
        memoryTotal: Measurement(value: 16, unit: .gigabytes),
        runningProcesses: 162,
        network: NetworkMetrics(
            receivedBytesPerSecond: 12_400_000,
            sentBytesPerSecond: 9_600_000
        ),
        disk: DiskMetrics(
            used: Measurement(value: 470, unit: .gigabytes),
            total: Measurement(value: 512, unit: .gigabytes)
        )
    )
}

struct NetworkMetrics: Sendable {
    var receivedBytesPerSecond: Double
    var sentBytesPerSecond: Double

    var totalBytesPerSecond: Double {
        max(0, receivedBytesPerSecond + sentBytesPerSecond)
    }

    func formattedBytesPerSecond(_ bytes: Double) -> String {
        Self.byteFormatter.string(fromByteCount: Int64(max(bytes, 0)))
    }

    var formattedUpload: String {
        formattedBytesPerSecond(sentBytesPerSecond)
    }

    var formattedDownload: String {
        formattedBytesPerSecond(receivedBytesPerSecond)
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    static let zero = NetworkMetrics(
        receivedBytesPerSecond: 0,
        sentBytesPerSecond: 0
    )
}

struct DiskMetrics: Sendable {
    var used: Measurement<UnitInformationStorage>
    var total: Measurement<UnitInformationStorage>

    var usage: Double {
        let usedBytes = used.converted(to: .bytes).value
        let totalBytes = total.converted(to: .bytes).value
        guard totalBytes > 0 else { return 0 }
        return min(max(usedBytes / totalBytes, 0), 1)
    }

    var free: Measurement<UnitInformationStorage> {
        let freeBytes = max(total.converted(to: .bytes).value - used.converted(to: .bytes).value, 0)
        return Measurement(value: freeBytes, unit: .bytes).converted(to: .gigabytes)
    }

    var formattedUsed: String {
        Self.measurementFormatter.string(from: used.converted(to: .gigabytes))
    }

    var formattedTotal: String {
        Self.measurementFormatter.string(from: total.converted(to: .gigabytes))
    }

    var formattedUsageSummary: String {
        "\(formattedUsed) of \(formattedTotal)"
    }

    private static let measurementFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }()

    static let placeholder = DiskMetrics(
        used: Measurement(value: 0, unit: .gigabytes),
        total: Measurement(value: 1, unit: .gigabytes)
    )
}
