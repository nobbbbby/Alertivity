import AppKit
import OSLog

/// Monitoring continues when Settings, onboarding, or the menu-bar popover closes.
@MainActor
final class AlertivityAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        AppLogger.lifecycle.notice("Last window closed; keeping background monitoring active")
        return false
    }
}
