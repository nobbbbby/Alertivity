#if DEBUG
import Foundation

/// Process fixtures are notification-only; they never become actionable rows in the metrics panel.
enum CaptureNotificationKind: String, CaseIterable, Identifiable {
    case system = "System activity"
    case processCPU = "Process CPU"
    case processMemory = "Process memory"
    case processCPUAndMemory = "Process CPU + memory"

    var id: String { rawValue }

    static var availableCases: [Self] {
        AppDistribution.current == .openSource ? allCases : [.system]
    }

    var process: ProcessUsage? {
        let triggers: Set<ProcessUsage.Trigger>
        switch self {
        case .system: return nil
        case .processCPU: triggers = [.cpu]
        case .processMemory: triggers = [.memory]
        case .processCPUAndMemory: triggers = [.cpu, .memory]
        }
        return ProcessUsage(
            pid: 0,
            command: "/Applications/Xcode.app/Contents/MacOS/Xcode",
            cpuPercent: 0.86,
            memoryPercent: 0.18,
            triggers: triggers
        )
    }
}
#endif
