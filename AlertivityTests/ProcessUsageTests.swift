import Testing
@testable import Alertivity

@Suite struct ProcessUsageTests {
    @Test
    func displayNameFallsBackToLastPathComponent() {
        let process = ProcessUsage(
            pid: 1,
            command: "/Applications/Safari.app/Contents/MacOS/Safari",
            cpuPercent: 0.1,
            memoryPercent: 0.05,
            triggers: [.cpu]
        )
        expectEqual(process.displayName, "Safari")
        expectEqual(process.searchTerm, "Safari")
    }

    @Test
    func triggeredFlagsReflectTriggersSet() {
        let both = ProcessUsage(pid: 2, command: "foo", cpuPercent: 0.2, memoryPercent: 0.3, triggers: [.cpu, .memory])
        expectTrue(both.triggeredByCPU)
        expectTrue(both.triggeredByMemory)

        let cpuOnly = ProcessUsage(pid: 3, command: "bar", cpuPercent: 0.2, memoryPercent: 0.0, triggers: [.cpu])
        expectTrue(cpuOnly.triggeredByCPU)
        expectFalse(cpuOnly.triggeredByMemory)
    }
}
