import XCTest
@testable import Alertivity

final class SystemMetricsProviderTests: XCTestCase {
    func testChangingCPUThresholdClearsTrackedProcesses() {
        let provider = SystemMetricsProvider()
        provider.highActivityDuration = 1

        let process = ProcessUsage(
            pid: 4242,
            command: "/Applications/Safari.app/Contents/MacOS/Safari",
            cpuPercent: 0.5,
            memoryPercent: 0.1
        )

        let initialTimestamp = Date()
        let initialResult = provider.simulateFilterHighActivity(processes: [process], at: initialTimestamp)
        XCTAssertTrue(initialResult.isEmpty, "High-activity dwell should block first sample")
        XCTAssertEqual(provider.trackedProcessIDsForTesting, [process.pid])

        let maturedTimestamp = initialTimestamp.addingTimeInterval(1.1)
        let maturedResult = provider.simulateFilterHighActivity(processes: [process], at: maturedTimestamp)
        XCTAssertEqual(maturedResult.map(\.pid), [process.pid])

        provider.highActivityCPUThreshold = 0.8
        XCTAssertTrue(provider.trackedProcessIDsForTesting.isEmpty, "Threshold change should clear cached tracking")

        let afterChangeTimestamp = maturedTimestamp.addingTimeInterval(0.5)
        let resultAfterChange = provider.simulateFilterHighActivity(processes: [], at: afterChangeTimestamp)
        XCTAssertTrue(resultAfterChange.isEmpty, "No stale processes should remain after threshold change")
        XCTAssertTrue(provider.trackedProcessIDsForTesting.isEmpty)
    }
}
