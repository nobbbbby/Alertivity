import Foundation
@testable import Alertivity

func makeMetrics(
    cpu: Double,
    memory: Double,
    diskBytesPerSecond: Double = 0,
    networkBytesPerSecond: Double = 0,
    highActivityProcesses: [ProcessUsage] = []
) -> ActivityMetrics {
    ActivityMetrics(
        cpuUsage: cpu,
        memoryUsed: Measurement(value: memory * 16, unit: .gigabytes),
        memoryTotal: Measurement(value: 16, unit: .gigabytes),
        runningProcesses: 10,
        network: NetworkMetrics(
            receivedBytesPerSecond: networkBytesPerSecond / 2,
            sentBytesPerSecond: networkBytesPerSecond / 2
        ),
        disk: DiskMetrics(
            readBytesPerSecond: diskBytesPerSecond / 2,
            writeBytesPerSecond: diskBytesPerSecond / 2
        ),
        highActivityProcesses: highActivityProcesses
    )
}
