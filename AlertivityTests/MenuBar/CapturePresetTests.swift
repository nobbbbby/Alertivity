#if DEBUG
import Testing
@testable import Alertivity

@Suite struct CapturePresetTests {
    @Test
    func presetsIsolateTheAdvertisedMetricWithDefaultAndCustomThresholds() throws {
        let custom = try #require(ActivityThresholds(
            cpuElevatedPercent: 10, cpuCriticalPercent: 100,
            memoryElevatedPercent: 5, memoryCriticalPercent: 100,
            diskElevatedMegabytesPerSecond: 0.1, diskCriticalMegabytesPerSecond: 0.2,
            networkElevatedMegabytesPerSecond: 0.1, networkCriticalMegabytesPerSecond: 0.2
        ))
        let expected: [(CapturePreset, MetricMenuSelection, ActivityMetrics.MetricSeverity)] = [
            (.cpuElevated, .cpu, .elevated), (.cpuCritical, .cpu, .critical),
            (.memoryElevated, .memory, .elevated), (.memoryCritical, .memory, .critical),
            (.diskElevated, .disk, .elevated), (.diskCritical, .disk, .critical),
            (.networkElevated, .network, .elevated), (.networkCritical, .network, .critical)
        ]
        for thresholds in [ActivityThresholds.default, custom] {
            #expect(CapturePreset.live.metrics(thresholds: thresholds) == nil)
            let normal = try #require(CapturePreset.normal.metrics(thresholds: thresholds))
            #expect(ActivityStatus(metrics: normal).level == .normal)
            for (preset, metric, severity) in expected {
                let snapshot = try #require(preset.metrics(thresholds: thresholds))
                #expect(snapshot.hasLiveData)
                #expect(snapshot.thresholds == thresholds)
                #expect(snapshot.highActivityProcesses.isEmpty)
                for selection in MetricMenuSelection.allCases {
                    #expect(snapshot.severity(for: selection) == (selection == metric ? severity : .normal))
                }
            }
        }
    }
}
#endif
