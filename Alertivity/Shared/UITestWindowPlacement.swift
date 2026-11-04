#if DEBUG
import AppKit

/// XCTest cannot capture windows on some secondary displays. Only isolated test launches move.
@MainActor enum UITestWindowPlacement {
    static func placeOnPrimaryScreen(_ window: NSWindow) {
        guard ProcessInfo.processInfo.arguments.contains("UITests"),
              let screen = NSScreen.screens.first else { return }
        let bounds = screen.visibleFrame
        window.setFrameOrigin(NSPoint(
            x: bounds.midX - window.frame.width / 2,
            y: bounds.midY - window.frame.height / 2
        ))
        AppLogger.lifecycle.debug("Positioned isolated UI-test window on primary display")
    }
}
#endif
