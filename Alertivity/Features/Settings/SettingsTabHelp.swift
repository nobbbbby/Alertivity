import AppKit
import SwiftUI

/// Attach descriptions to native tab controls without making the content pane a hover target.
struct SettingsTabHelp: NSViewRepresentable {
    let descriptions: [String: String]

    func makeNSView(context: Context) -> HelpView { HelpView() }

    func updateNSView(_ view: HelpView, context: Context) {
        view.descriptions = descriptions
        view.needsLayout = true
        // SwiftUI may install the tab controls after this representable is updated.
        DispatchQueue.main.async { [weak view] in view?.applyHelp() }
    }

    /// Both Settings presentations use native tooltip properties; unrelated items retain their help.
    @discardableResult
    static func apply(_ descriptions: [String: String], to tabs: [NSTabViewItem], toolbarItems: [NSToolbarItem]) -> Int {
        var updated = 0
        for item in tabs {
            if let help = descriptions[item.label], item.toolTip != help {
                item.toolTip = help
                updated += 1
            }
        }
        for item in toolbarItems {
            if let help = descriptions[item.label], item.toolTip != help {
                item.toolTip = help
                updated += 1
            }
        }
        return updated
    }

    /// Older SwiftUI Settings toolbars may recreate their buttons independently of item metadata.
    @discardableResult
    static func apply(_ descriptions: [String: String], to control: NSView) -> Int {
        if let button = control as? NSButton,
           let help = descriptions[button.title] ?? descriptions[button.accessibilityLabel() ?? ""],
           button.toolTip != help {
            button.toolTip = help
            button.setAccessibilityHelp(help)
            return 1
        }
        if let segments = control as? NSSegmentedControl {
            var updated = 0
            for index in 0..<segments.segmentCount {
                if let help = descriptions[segments.label(forSegment: index) ?? ""],
                   segments.toolTip(forSegment: index) != help {
                    segments.setToolTip(help, forSegment: index)
                    updated += 1
                }
            }
            return updated
        }
        return 0
    }

    final class HelpView: NSView {
        var descriptions: [String: String] = [:]

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in self?.applyHelp() }
        }

        override func layout() {
            super.layout()
            applyHelp()
        }

        func applyHelp() {
            guard let window, let content = window.contentView else { return }
            var updated = 0
            func visit(_ view: NSView) {
                updated += SettingsTabHelp.apply(descriptions, to: view)
                if let tabs = view as? NSTabView {
                    updated += SettingsTabHelp.apply(descriptions, to: tabs.tabViewItems, toolbarItems: [])
                }
                for child in view.subviews { visit(child) }
            }
            // Tab buttons live in the title bar, outside the SwiftUI content view.
            visit(content.superview ?? content)
            // Settings can present tab items in a toolbar, including its overflow menu.
            updated += SettingsTabHelp.apply(descriptions, to: [], toolbarItems: window.toolbar?.items ?? [])
            if updated > 0 {
                AppLogger.lifecycle.debug("Settings tab help updated; controls: \(updated, privacy: .public)")
            }
        }
    }
}
