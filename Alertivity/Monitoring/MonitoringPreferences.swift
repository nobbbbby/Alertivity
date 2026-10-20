import Foundation

/// Defines the supported monitoring controls in one place so settings UI and runtime validation cannot drift apart.
enum MonitoringPreferences {
    static let notificationCooldownOptions = [1, 5, 10, 15, 30, 60]
    static let defaultNotificationCooldownMinutes = 10

    /// Reject unsupported saved values so the picker always represents the runtime preference.
    static func normalizedNotificationCooldown(_ value: Int) -> Int {
        notificationCooldownOptions.contains(value) ? value : defaultNotificationCooldownMinutes
    }

    static let durationOptions = [30, 60, 120, 240, 600]
    static let cpuThresholdOptions = Array(stride(from: 20, through: 100, by: 15))
    static let memoryThresholdOptions = Array(stride(from: 5, through: 50, by: 5))

    private static let durationRange = 10...600
    private static let cpuThresholdRange = 1...100
    private static let memoryThresholdRange = 5...50

    static func normalizedDuration(_ value: Int) -> Int {
        value.clamped(to: durationRange)
    }

    static func normalizedCPUThreshold(_ value: Int) -> Int {
        value.clamped(to: cpuThresholdRange)
    }

    static func normalizedMemoryThreshold(_ value: Int) -> Int {
        value.clamped(to: memoryThresholdRange)
    }
}

struct ActivityThresholds: Codable, Equatable, Sendable {
    enum ValidationError: Error, Equatable {
        case cpuOutOfRange
        case memoryOutOfRange
        case diskOutOfRange
        case networkOutOfRange
        case elevatedMustBeBelowCritical
    }

    static let percentRange = 1.0...100.0
    static let throughputRange = 0.1...100_000.0

    static let `default`: ActivityThresholds = {
        guard let value = ActivityThresholds(
            cpuElevatedPercent: 50,
            cpuCriticalPercent: 80,
            memoryElevatedPercent: 70,
            memoryCriticalPercent: 85,
            diskElevatedMegabytesPerSecond: 30,
            diskCriticalMegabytesPerSecond: 120,
            networkElevatedMegabytesPerSecond: 5,
            networkCriticalMegabytesPerSecond: 20
        ) else {
            preconditionFailure("Built-in activity thresholds must be valid")
        }
        return value
    }()

    let cpuElevatedPercent: Double
    let cpuCriticalPercent: Double
    let memoryElevatedPercent: Double
    let memoryCriticalPercent: Double
    let diskElevatedMegabytesPerSecond: Double
    let diskCriticalMegabytesPerSecond: Double
    let networkElevatedMegabytesPerSecond: Double
    let networkCriticalMegabytesPerSecond: Double

    init?(
        cpuElevatedPercent: Double,
        cpuCriticalPercent: Double,
        memoryElevatedPercent: Double,
        memoryCriticalPercent: Double,
        diskElevatedMegabytesPerSecond: Double,
        diskCriticalMegabytesPerSecond: Double,
        networkElevatedMegabytesPerSecond: Double,
        networkCriticalMegabytesPerSecond: Double
    ) {
        guard Self.validate(
            cpuElevatedPercent: cpuElevatedPercent,
            cpuCriticalPercent: cpuCriticalPercent,
            memoryElevatedPercent: memoryElevatedPercent,
            memoryCriticalPercent: memoryCriticalPercent,
            diskElevatedMegabytesPerSecond: diskElevatedMegabytesPerSecond,
            diskCriticalMegabytesPerSecond: diskCriticalMegabytesPerSecond,
            networkElevatedMegabytesPerSecond: networkElevatedMegabytesPerSecond,
            networkCriticalMegabytesPerSecond: networkCriticalMegabytesPerSecond
        ) == nil else { return nil }

        self.cpuElevatedPercent = cpuElevatedPercent
        self.cpuCriticalPercent = cpuCriticalPercent
        self.memoryElevatedPercent = memoryElevatedPercent
        self.memoryCriticalPercent = memoryCriticalPercent
        self.diskElevatedMegabytesPerSecond = diskElevatedMegabytesPerSecond
        self.diskCriticalMegabytesPerSecond = diskCriticalMegabytesPerSecond
        self.networkElevatedMegabytesPerSecond = networkElevatedMegabytesPerSecond
        self.networkCriticalMegabytesPerSecond = networkCriticalMegabytesPerSecond
    }

    static func validate(
        cpuElevatedPercent: Double,
        cpuCriticalPercent: Double,
        memoryElevatedPercent: Double,
        memoryCriticalPercent: Double,
        diskElevatedMegabytesPerSecond: Double,
        diskCriticalMegabytesPerSecond: Double,
        networkElevatedMegabytesPerSecond: Double,
        networkCriticalMegabytesPerSecond: Double
    ) -> ValidationError? {
        guard percentRange.contains(cpuElevatedPercent), percentRange.contains(cpuCriticalPercent) else {
            return .cpuOutOfRange
        }
        guard percentRange.contains(memoryElevatedPercent), percentRange.contains(memoryCriticalPercent) else {
            return .memoryOutOfRange
        }
        guard throughputRange.contains(diskElevatedMegabytesPerSecond), throughputRange.contains(diskCriticalMegabytesPerSecond) else {
            return .diskOutOfRange
        }
        guard throughputRange.contains(networkElevatedMegabytesPerSecond), throughputRange.contains(networkCriticalMegabytesPerSecond) else {
            return .networkOutOfRange
        }
        guard
            cpuElevatedPercent < cpuCriticalPercent,
            memoryElevatedPercent < memoryCriticalPercent,
            diskElevatedMegabytesPerSecond < diskCriticalMegabytesPerSecond,
            networkElevatedMegabytesPerSecond < networkCriticalMegabytesPerSecond
        else {
            return .elevatedMustBeBelowCritical
        }
        return nil
    }

    var cpuElevated: Double { cpuElevatedPercent / 100 }
    var cpuCritical: Double { cpuCriticalPercent / 100 }
    var memoryElevated: Double { memoryElevatedPercent / 100 }
    var memoryCritical: Double { memoryCriticalPercent / 100 }
    var diskElevatedBytesPerSecond: Double { diskElevatedMegabytesPerSecond * 1_000_000 }
    var diskCriticalBytesPerSecond: Double { diskCriticalMegabytesPerSecond * 1_000_000 }
    var networkElevatedBytesPerSecond: Double { networkElevatedMegabytesPerSecond * 1_000_000 }
    var networkCriticalBytesPerSecond: Double { networkCriticalMegabytesPerSecond * 1_000_000 }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
