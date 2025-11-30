import Foundation

struct ProcessUsage: Identifiable, Hashable, Sendable {
    enum Trigger: String, Sendable {
        case cpu
        case memory
    }

    let pid: Int32
    let command: String
    let cpuPercent: Double
    let memoryPercent: Double
    let triggers: Set<Trigger>

    var id: Int32 { pid }

    var displayName: String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Unknown Process" }
        let url = URL(fileURLWithPath: trimmed)
        let last = url.lastPathComponent
        return last.isEmpty ? trimmed : last
    }

    var cpuDescription: String {
        cpuPercent.formatted(.percent.precision(.fractionLength(0)))
    }

    var memoryDescription: String {
        memoryPercent.formatted(.percent.precision(.fractionLength(0)))
    }

    var searchTerm: String {
        displayName
    }

    var triggeredByCPU: Bool {
        triggers.contains(.cpu)
    }

    var triggeredByMemory: Bool {
        triggers.contains(.memory)
    }

    static let preview: [ProcessUsage] = [
        ProcessUsage(pid: 1234, command: "/Applications/Xcode.app/Contents/MacOS/Xcode", cpuPercent: 0.82, memoryPercent: 0.14, triggers: [.cpu]),
        ProcessUsage(pid: 5678, command: "/Applications/Safari.app/Contents/MacOS/Safari", cpuPercent: 0.34, memoryPercent: 0.09, triggers: [.cpu]),
        ProcessUsage(pid: 9012, command: "/usr/bin/Terminal", cpuPercent: 0.21, memoryPercent: 0.18, triggers: [.memory])
    ]
}

struct ActivityMetrics: Sendable, Equatable {
    var cpuUsage: Double
    var memoryUsed: Measurement<UnitInformationStorage>
    var memoryTotal: Measurement<UnitInformationStorage>
    var runningProcesses: Int
    var network: NetworkMetrics
    var disk: DiskMetrics
    var highActivityProcesses: [ProcessUsage]

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
        disk: .zero,
        highActivityProcesses: []
    )
}

extension ActivityMetrics {
    /// Returns true once the metrics differ from the initial placeholder sample.
    var hasLiveData: Bool {
        if self == .placeholder { return false }
        if runningProcesses > 0 { return true }
        if cpuUsage > 0 { return true }
        if memoryUsed.converted(to: .bytes).value > 0 { return true }
        if disk.totalBytesPerSecond > 0 { return true }
        if network.totalBytesPerSecond > 0 { return true }
        if !highActivityProcesses.isEmpty { return true }
        return false
    }

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
        disk: DiskMetrics(readBytesPerSecond: 900_000, writeBytesPerSecond: 600_000),
        highActivityProcesses: ProcessUsage.preview
    )

    static let previewElevated = ActivityMetrics(
        cpuUsage: 0.67,
        memoryUsed: Measurement(value: 9, unit: .gigabytes),
        memoryTotal: Measurement(value: 16, unit: .gigabytes),
        runningProcesses: 134,
        network: NetworkMetrics(
            receivedBytesPerSecond: 2_200_000,
            sentBytesPerSecond: 1_600_000
        ),
        disk: DiskMetrics(readBytesPerSecond: 8_000_000, writeBytesPerSecond: 5_500_000),
        highActivityProcesses: ProcessUsage.preview
    )

    static let previewCritical = ActivityMetrics(
        cpuUsage: 0.92,
        memoryUsed: Measurement(value: 10, unit: .gigabytes),
        memoryTotal: Measurement(value: 16, unit: .gigabytes),
        runningProcesses: 162,
        network: NetworkMetrics(
            receivedBytesPerSecond: 2_400_000,
            sentBytesPerSecond: 1_800_000
        ),
        disk: DiskMetrics(readBytesPerSecond: 9_000_000, writeBytesPerSecond: 7_000_000),
        highActivityProcesses: ProcessUsage.preview
    )

    static let previewMultiElevated = ActivityMetrics(
        cpuUsage: 0.64,
        memoryUsed: Measurement(value: 25, unit: .gigabytes),
        memoryTotal: Measurement(value: 32, unit: .gigabytes),
        runningProcesses: 140,
        network: NetworkMetrics(
            receivedBytesPerSecond: 7_200_000,
            sentBytesPerSecond: 5_600_000
        ),
        disk: DiskMetrics(readBytesPerSecond: 18_000_000, writeBytesPerSecond: 12_000_000),
        highActivityProcesses: ProcessUsage.preview
    )

    static let previewCriticalWithMemoryElevated = ActivityMetrics(
        cpuUsage: 0.88,
        memoryUsed: Measurement(value: 25, unit: .gigabytes),
        memoryTotal: Measurement(value: 32, unit: .gigabytes),
        runningProcesses: 150,
        network: NetworkMetrics(
            receivedBytesPerSecond: 2_000_000,
            sentBytesPerSecond: 1_500_000
        ),
        disk: DiskMetrics(readBytesPerSecond: 8_000_000, writeBytesPerSecond: 6_000_000),
        highActivityProcesses: ProcessUsage.preview
    )

    static let previewMultiCritical = ActivityMetrics(
        cpuUsage: 0.88,
        memoryUsed: Measurement(value: 27, unit: .gigabytes),
        memoryTotal: Measurement(value: 32, unit: .gigabytes),
        runningProcesses: 158,
        network: NetworkMetrics(
            receivedBytesPerSecond: 22_000_000,
            sentBytesPerSecond: 18_000_000
        ),
        disk: DiskMetrics(readBytesPerSecond: 110_000_000, writeBytesPerSecond: 86_000_000),
        highActivityProcesses: ProcessUsage.preview
    )

    static let previewDiskCritical = ActivityMetrics(
        cpuUsage: 0.32,
        memoryUsed: Measurement(value: 10, unit: .gigabytes),
        memoryTotal: Measurement(value: 32, unit: .gigabytes),
        runningProcesses: 112,
        network: NetworkMetrics(
            receivedBytesPerSecond: 2_400_000,
            sentBytesPerSecond: 1_900_000
        ),
        disk: DiskMetrics(readBytesPerSecond: 120_000_000, writeBytesPerSecond: 104_000_000),
        highActivityProcesses: []
    )
}

extension ActivityMetrics {
    enum MetricSeverity: Int, Sendable {
        case normal = 0
        case elevated = 1
        case critical = 2
    }

    var cpuSeverity: MetricSeverity {
        switch cpuUsagePercentage {
        case ..<0.5:
            return .normal
        case 0.5..<0.8:
            return .elevated
        default:
            return .critical
        }
    }

    var memorySeverity: MetricSeverity {
        switch memoryUsage {
        case ..<0.7:
            return .normal
        case 0.7..<0.85:
            return .elevated
        default:
            return .critical
        }
    }

    var diskSeverity: MetricSeverity {
        switch disk.totalBytesPerSecond {
        case ..<20_000_000: // ~20 MB/s
            return .normal
        case 20_000_000..<100_000_000: // ~20-100 MB/s
            return .elevated
        default:
            return .critical
        }
    }

    var networkSeverity: MetricSeverity {
        switch network.totalBytesPerSecond {
        case ..<5_000_000: // ~5 MB/s
            return .normal
        case 5_000_000..<20_000_000: // ~5-20 MB/s
            return .elevated
        default:
            return .critical
        }
    }

    func severity(for selection: MetricMenuSelection) -> MetricSeverity {
        switch selection {
        case .cpu:
            return cpuSeverity
        case .memory:
            return memorySeverity
        case .disk:
            return diskSeverity
        case .network:
            return networkSeverity
        }
    }

    func highestSeverityMetric(
        allowedSeverities: Set<MetricSeverity> = [.elevated, .critical]
    ) -> (MetricMenuSelection, MetricSeverity)? {
        let ranked: [(MetricMenuSelection, MetricSeverity)] = [
            (.cpu, cpuSeverity),
            (.memory, memorySeverity),
            (.disk, diskSeverity),
            (.network, networkSeverity)
        ]

        let filtered = ranked.filter { allowedSeverities.contains($0.1) }
        guard !filtered.isEmpty else { return nil }

        return filtered.max { lhs, rhs in
            if lhs.1 == rhs.1 {
                return MetricMenuSelection.autoSwitchPriorityIndex(lhs.0) > MetricMenuSelection.autoSwitchPriorityIndex(rhs.0)
            }
            return lhs.1.rawValue < rhs.1.rawValue
        }
    }
}

struct NetworkMetrics: Sendable, Equatable {
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

struct DiskMetrics: Sendable, Equatable {
    var readBytesPerSecond: Double
    var writeBytesPerSecond: Double

    var totalBytesPerSecond: Double {
        max(0, readBytesPerSecond + writeBytesPerSecond)
    }

    func formattedBytesPerSecond(_ bytes: Double) -> String {
        Self.byteFormatter.string(fromByteCount: Int64(max(bytes, 0)))
    }

    var formattedReadPerSecond: String {
        formattedBytesPerSecond(readBytesPerSecond)
    }

    var formattedWritePerSecond: String {
        formattedBytesPerSecond(writeBytesPerSecond)
    }

    var formattedTotalPerSecond: String {
        formattedBytesPerSecond(totalBytesPerSecond)
    }

    var formattedReadWriteSummary: String {
        "↑ \(formattedReadPerSecond)/s • ↓ \(formattedWritePerSecond)/s"
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    static let zero = DiskMetrics(
        readBytesPerSecond: 0,
        writeBytesPerSecond: 0
    )
}
