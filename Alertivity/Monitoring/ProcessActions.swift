import AppKit
import Foundation
import Darwin

enum ProcessActions {
    // Test hooks
    static var activityMonitorURLProvider: () -> URL? = {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor")
    }
    static var openApplication: (URL, NSWorkspace.OpenConfiguration) -> Void = { url, configuration in
        NSWorkspace.shared.openApplication(at: url, configuration: configuration, completionHandler: nil)
    }
    static var appleScriptRunner: (_ source: String) -> Void = { source in
        guard let script = NSAppleScript(source: source) else { return }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
    }
    static var killHandler: (_ pid: pid_t, _ signal: Int32) -> Int32 = { pid, signal in
        kill(pid, signal)
    }

    static func revealInActivityMonitor(_ process: ProcessUsage) {
        if let url = activityMonitorURLProvider() {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            openApplication(url, configuration)
        }

        let searchTerm = process.searchTerm.appleScriptEscaped
        let script = """
        delay 0.3
        tell application "System Events"
            if not (exists process "Activity Monitor") then
                return
            end if
            tell process "Activity Monitor"
                set frontmost to true
                delay 0.1
                key code 18 using {command down}
                delay 0.2
                keystroke "f" using {command down}
                delay 0.2
                keystroke "\(searchTerm)"
            end tell
        end tell
        """

        appleScriptRunner(script)
    }

    static func terminate(_ process: ProcessUsage) {
        let pid = process.pid
        guard pid > 0 else { return }
        let terminateResult = killHandler(pid, SIGTERM)
        if terminateResult != 0 {
            _ = killHandler(pid, SIGKILL)
        }
    }
}

extension String {
    var appleScriptEscaped: String {
        var result = ""
        for character in self {
            switch character {
            case "\\":
                result.append("\\\\") // Escape backslash once for AppleScript string literal
            case "\"":
                result.append("\\\\\"")
            default:
                result.append(character)
            }
        }
        return result
    }
}
