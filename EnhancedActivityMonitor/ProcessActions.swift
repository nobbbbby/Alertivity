import AppKit
import Foundation
import Darwin

enum ProcessActions {
    static func revealInActivityMonitor(_ process: ProcessUsage) {
        if #available(macOS 11.0, *) {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                NSWorkspace.shared.openApplication(at: url, configuration: configuration, completionHandler: nil)
            }
        } else {
            _ = NSWorkspace.shared.launchApplication(
                withBundleIdentifier: "com.apple.ActivityMonitor",
                options: [],
                additionalEventParamDescriptor: nil,
                launchIdentifier: nil
            )
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

        runAppleScript(script)
    }

    static func terminate(_ process: ProcessUsage) {
        let pid = process.pid
        guard pid > 0 else { return }
        let terminateResult = kill(pid, SIGTERM)
        if terminateResult != 0 {
            _ = kill(pid, SIGKILL)
        }
    }

    private static func runAppleScript(_ source: String) {
        guard let script = NSAppleScript(source: source) else { return }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
    }
}

private extension String {
    var appleScriptEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
