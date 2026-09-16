import Foundation

/// Defines the supported monitoring controls in one place so settings UI and runtime validation cannot drift apart.
enum MonitoringPreferences {
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

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
