import AppKit
import SwiftUI

/// Let native tab visibility determine expansion, independently of the selected pane's content.
struct SettingsTabWidth: NSViewRepresentable {
    @Binding var width: CGFloat

    func makeNSView(context: Context) -> TabWidthView { TabWidthView() }

    func updateNSView(_ view: TabWidthView, context: Context) {
        view.contentWidth = width
        view.expand = { width = $0 }
        view.scheduleMeasurement()
    }

    final class TabWidthView: NSView {
        var contentWidth: CGFloat = 400
        var expand: ((CGFloat) -> Void)?
        private var measurementPending = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            if let window {
                NotificationCenter.default.addObserver(
                    self, selector: #selector(windowResized), name: NSWindow.didResizeNotification, object: window
                )
                NotificationCenter.default.addObserver(
                    self, selector: #selector(windowResized), name: NSWindow.didBecomeKeyNotification, object: window
                )
            }
            scheduleMeasurement()
        }

        override func layout() {
            super.layout()
            scheduleMeasurement()
        }

        @objc private func windowResized() { scheduleMeasurement() }

        func scheduleMeasurement() {
            guard !measurementPending else { return }
            measurementPending = true
            // Toolbar visibility settles after SwiftUI applies the content width to its window.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.measurementPending = false
                self.measure()
            }
        }

        private func measure() {
            guard let window, window.isVisible,
                  abs(window.contentLayoutRect.width - contentWidth) < 1 else { return }
            let limit = max(400, (window.screen?.visibleFrame.width ?? 400) - 24)
            var requiredWidth = contentWidth
            if let toolbar = window.toolbar, toolbar.isVisible,
               let visibleItems = toolbar.visibleItems {
                let visible = Set(visibleItems.map(\.itemIdentifier))
                let hiddenTabs = toolbar.items.filter { !$0.label.isEmpty && !visible.contains($0.itemIdentifier) }
                // Small bounded steps use the toolbar's actual fit instead of guessing system font/padding.
                if !hiddenTabs.isEmpty { requiredWidth += 16 }
            } else if let content = window.contentView {
                requiredWidth = max(requiredWidth, nativeTabWidth(in: content))
            }
            let next = min(ceil(requiredWidth), limit)
            guard next > contentWidth else { return }
            AppLogger.lifecycle.debug("Settings expanded to fit tabs; width: \(next, privacy: .public)")
            expand?(next)
        }

        /// Older Settings presentations expose their tab strip through NSTabView.
        private func nativeTabWidth(in view: NSView) -> CGFloat {
            if let tabs = view as? NSTabView {
                let strip = NSTabView()
                strip.tabViewType = tabs.tabViewType
                strip.font = tabs.font
                for item in tabs.tabViewItems {
                    let copy = NSTabViewItem()
                    copy.label = item.label
                    strip.addTabViewItem(copy)
                }
                return strip.minimumSize.width
            }
            return view.subviews.map { nativeTabWidth(in: $0) }.max() ?? 0
        }
    }
}
