import Testing
import AppKit
@testable import Alertivity

@Suite struct ProcessActionsTests {
    @Test
    func revealInActivityMonitorOpensAppAndRunsScript() {
        var openedURL: URL?
        var openedConfiguration: NSWorkspace.OpenConfiguration?
        var scriptSource: String?

        let dummyURL = URL(fileURLWithPath: "/Applications/Activity Monitor.app")
        let originalURLProvider = ProcessActions.activityMonitorURLProvider
        let originalOpenApplication = ProcessActions.openApplication
        let originalScriptRunner = ProcessActions.appleScriptRunner
        defer {
            ProcessActions.activityMonitorURLProvider = originalURLProvider
            ProcessActions.openApplication = originalOpenApplication
            ProcessActions.appleScriptRunner = originalScriptRunner
        }

        ProcessActions.activityMonitorURLProvider = { dummyURL }
        ProcessActions.openApplication = { url, config in
            openedURL = url
            openedConfiguration = config
        }
        ProcessActions.appleScriptRunner = { source in
            scriptSource = source
        }

        let process = ProcessUsage(
            pid: 1234,
            command: "/Applications/Safari.app/Contents/MacOS/Safari",
            cpuPercent: 0.3,
            memoryPercent: 0.1,
            triggers: [.cpu]
        )

        ProcessActions.revealInActivityMonitor(process)

        expectEqual(openedURL, dummyURL)
        expectTrue(openedConfiguration?.activates ?? false)
        expectTrue(scriptSource?.contains(process.displayName) ?? false)
    }

    @Test
    func terminateFallsBackToKillWhenTermFails() {
        var calls: [(pid_t, Int32)] = []
        let originalKill = ProcessActions.killHandler
        defer { ProcessActions.killHandler = originalKill }

        ProcessActions.killHandler = { pid, signal in
            calls.append((pid, signal))
            return calls.count == 1 ? -1 : 0
        }

        let process = ProcessUsage(
            pid: 9999,
            command: "dummy",
            cpuPercent: 0.1,
            memoryPercent: 0.1,
            triggers: [.cpu]
        )

        ProcessActions.terminate(process)

        expectEqual(calls.count, 2)
        expectEqual(calls[0].0, process.pid)
        expectEqual(calls[0].1, SIGTERM)
        expectEqual(calls[1].1, SIGKILL)
    }

}
