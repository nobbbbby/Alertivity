import AppKit
import OSLog
import SwiftUI

/// Help menu action that opens GitHub's issue form in the default browser.
struct FeedbackLink: View {
    @Environment(\.openURL) private var openURL
    private static let issueURL = URL(string: "https://github.com/nobbbbby/Alertivity/issues/new")!

    var body: some View {
        Button("feedback.send") {
            openURL(Self.issueURL) { accepted in
                if accepted {
                    AppLogger.feedback.info("Opened GitHub feedback form")
                } else {
                    AppLogger.feedback.error("Failed to open GitHub feedback form")
                    // Help commands have no SwiftUI presentation anchor.
                    let alert = NSAlert()
                    alert.messageText = L10n.string("feedback.openError")
                    alert.addButton(withTitle: L10n.string("general.ok"))
                    NSApp.activate()
                    if let window = NSApp.keyWindow {
                        alert.beginSheetModal(for: window)
                    } else {
                        alert.runModal()
                    }
                }
            }
        }
        .help("feedback.help")
        .accessibilityIdentifier("feedback.send")
    }
}
