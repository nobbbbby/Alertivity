import AppKit
import OSLog
import SwiftUI

/// Keep custom application commands together, separate from the live metrics panel.
struct AlertivityCommands: Commands {
    let settings: SettingsStore
    let reviewStore: ReviewRequestStore
#if DEBUG
    @Environment(\.openWindow) private var openWindow
#endif

    var body: some Commands {
        CommandGroup(replacing: .help) {
            OnboardingLink(settings: settings)
            Divider()
            WriteReviewButton(store: reviewStore)
            FeedbackLink()
        }
#if DEBUG
        CommandMenu("Debug") {
            Button {
                // A menu-bar-only app may be an accessory until a utility window opens.
                NSApp.setActivationPolicy(.regular)
                NSApp.activate()
                openWindow(id: "activity-simulator")
                AppLogger.lifecycle.info("Opened Debug Activity Simulator")
            } label: {
                Text(verbatim: "Activity Simulator…")
            }
            .accessibilityIdentifier("capture.open")
        }
#endif
    }
}
