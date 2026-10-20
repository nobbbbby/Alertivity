import AppKit
import Testing
@testable import Alertivity

@Suite @MainActor struct SettingsTabHelpTests {
    @Test func fallbackUpdatesVisibleTabControls() {
        let descriptions = ["Menu Bar": "Indicator help", "Thresholds": "Threshold help"]
        let button = NSButton(title: "Menu Bar", target: nil, action: nil)
        #expect(SettingsTabHelp.apply(descriptions, to: button) == 1)
        #expect(button.toolTip == "Indicator help")
        #expect(button.accessibilityHelp() == "Indicator help")
        #expect(SettingsTabHelp.apply(descriptions, to: button) == 0)

        let segments = NSSegmentedControl()
        segments.segmentCount = 2
        segments.setLabel("Thresholds", forSegment: 0)
        segments.setLabel("Other", forSegment: 1)
        segments.setToolTip("Existing help", forSegment: 1)
        #expect(SettingsTabHelp.apply(descriptions, to: segments) == 1)
        #expect(segments.toolTip(forSegment: 0) == "Threshold help")
        #expect(segments.toolTip(forSegment: 1) == "Existing help")
    }

    @Test func descriptionsReachNativeTabsAndToolbarItems() {
        let tab = NSTabViewItem(identifier: "menu")
        tab.label = "Menu Bar"
        let thresholdItem = NSToolbarItem(itemIdentifier: .init("thresholds"))
        thresholdItem.label = "Thresholds"
        let otherItem = NSToolbarItem(itemIdentifier: .init("other"))
        otherItem.label = "Other"
        otherItem.toolTip = "Existing help"
        let descriptions = ["Menu Bar": "Indicator help", "Thresholds": "Threshold help"]

        #expect(SettingsTabHelp.apply(descriptions, to: [tab], toolbarItems: [thresholdItem, otherItem]) == 2)
        #expect(tab.toolTip == "Indicator help")
        #expect(thresholdItem.toolTip == "Threshold help")
        #expect(otherItem.toolTip == "Existing help")
        #expect(SettingsTabHelp.apply(descriptions, to: [tab], toolbarItems: [thresholdItem, otherItem]) == 0)

        SettingsTabHelp.apply(["Menu Bar": "Updated indicator help", "Thresholds": "Updated threshold help"],
                              to: [tab], toolbarItems: [thresholdItem])
        #expect(tab.toolTip == "Updated indicator help")
        #expect(thresholdItem.toolTip == "Updated threshold help")
    }
}
