import XCTest

final class AlertivityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testActivitySimulatorWindowAndCustomCommandGroups() {
        let app = launchApp()
        app.launch()
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 8))
        skip.click()
        app.activate()
        XCTAssertFalse(app.windows["Activity Simulator"].exists)

        app.menuBars.menuBarItems["Help"].click()
        for title in ["Getting Started…", "Write Review…", "Send Feedback…"] {
            XCTAssertTrue(app.menuItems[title].exists, "Missing Help command: \(title)")
        }
        app.typeKey(.escape, modifierFlags: [])
        app.menuBars.menuBarItems["Debug"].click()
        app.menuItems["Activity Simulator…"].click()

        let window = app.windows["Activity Simulator"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let picker = window.popUpButtons["capture.preset"]
        XCTAssertTrue(picker.exists)
        XCTAssertEqual(picker.value as? String, "Live readings")
        XCTAssertFalse(window.buttons["capture.sendNotification"].isEnabled)
        picker.click()
        app.menuItems["CPU · Critical"].click()
        XCTAssertEqual(picker.value as? String, "CPU · Critical")
        XCTAssertTrue(window.buttons["capture.sendNotification"].isEnabled)

        // Closing the utility leaves the snapshot available for a clean screenshot.
        window.buttons[XCUIIdentifierCloseWindow].click()
        app.menuBars.menuBarItems["Debug"].click()
        app.menuItems["Activity Simulator…"].click()
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertEqual(picker.value as? String, "CPU · Critical")
        XCTAssertEqual(app.windows.matching(identifier: "Activity Simulator").count, 1)
        window.buttons["capture.returnToLive"].click()
        XCTAssertEqual(picker.value as? String, "Live readings")
        XCTAssertFalse(window.buttons["capture.sendNotification"].isEnabled)
    }

    func testFreeCustomizationControlsAreLocked() {
        verifyCustomizationControls(appStoreFree: true)
    }

    func testOpenSourceCustomizationControlsStayUnlocked() {
        verifyCustomizationControls(appStoreFree: false)
    }

    func testAppStoreOnboardingIntroducesProWithoutPurchase() {
        let app = launchApp()
        app.launchArguments.append("UITestsAppStoreFree")
        app.launch()
        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts["onboarding.step"].value as? String, "Step 1 of 3")
        next.click()
        XCTAssertEqual(app.staticTexts["onboarding.step"].value as? String, "Step 2 of 3")
        next.click()
        XCTAssertEqual(app.staticTexts["onboarding.step"].value as? String, "Step 3 of 3")
        XCTAssertTrue(app.staticTexts["onboarding.pro.introduction"].waitForExistence(timeout: 3))
        for key in ["pro.feature.thresholds", "pro.feature.cooldown", "pro.feature.duration"] {
            XCTAssertTrue(app.staticTexts[key].exists)
        }
        XCTAssertFalse(app.buttons["pro.purchase"].exists)
        XCTAssertFalse(app.buttons["pro.restore"].exists)
        app.buttons["onboarding.back"].click()
        XCTAssertEqual(app.staticTexts["onboarding.step"].value as? String, "Step 2 of 3")
        next.click()
        next.click()
        XCTAssertTrue(next.waitForNonExistence(timeout: 3))
    }

    private func verifyCustomizationControls(appStoreFree: Bool) {
        let app = launchApp()
        if appStoreFree { app.launchArguments.append("UITestsAppStoreFree") }
        app.launch()
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 8))
        skip.click()
        app.typeKey(",", modifierFlags: .command)
        let notifications = app.buttons["Notifications"]
        XCTAssertTrue(notifications.waitForExistence(timeout: 5))
        notifications.click()
        let cooldown = app.popUpButtons["settings.notificationCooldown"]
        let duration = app.popUpButtons["settings.highActivityDuration"]
        XCTAssertTrue(cooldown.waitForExistence(timeout: 3))
        XCTAssertEqual(cooldown.isEnabled, !appStoreFree)
        XCTAssertEqual(duration.isEnabled, !appStoreFree)
        XCTAssertTrue(app.checkBoxes["Enable system notifications"].isEnabled)
        for key in ["pro.lock.cooldown", "pro.lock.duration"] {
            let hint = app.images[key]
            XCTAssertEqual(hint.exists, appStoreFree)
            if appStoreFree { XCTAssertTrue(hint.isEnabled) }
        }
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "non-sandboxed")).firstMatch.exists)
        saveBoundaryScreenshot(app, name: appStoreFree ? "Free Notifications" : "Open Source Notifications")
        app.buttons["Thresholds"].click()
        let fields = app.textFields.allElementsBoundByIndex
        XCTAssertEqual(fields.count, 8)
        XCTAssertTrue(fields.allSatisfy { $0.isEnabled == !appStoreFree })
        for metric in ["cpu", "memory", "disk", "network"] {
            let hint = app.images["pro.lock.thresholds.\(metric)"]
            XCTAssertEqual(hint.exists, appStoreFree)
            if appStoreFree { XCTAssertTrue(hint.isEnabled) }
        }
        saveBoundaryScreenshot(app, name: appStoreFree ? "Free Thresholds" : "Open Source Thresholds")
        // Narrow Settings windows may place tabs in the native toolbar overflow menu.
        if !appStoreFree { XCTAssertFalse(app.buttons["Pro"].exists) }
    }

    private func saveBoundaryScreenshot(_ app: XCUIApplication, name: String) {
        // Functional checks must also run on hosts without a screenshot-capable display.
        guard ProcessInfo.processInfo.environment["ALERTIVITY_CAPTURE_UI_SCREENSHOTS"] == "1" else { return }
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testAppLaunchesAndStaysActive() {
        let app = launchApp()
        app.launch()

        // Menu-bar apps often remain background; just ensure they leave the notRunning state.
        let deadline = Date().addingTimeInterval(8)
        var isRunning = false
        repeat {
            if app.state != .notRunning {
                isRunning = true
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        XCTAssertTrue(isRunning, "App should be launched (foreground or background)")
    }

    func testOnboardingCompletionAndReplay() {
        let app = launchApp()
        app.launch()
        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        XCTAssertTrue(app.popUpButtons["onboarding.previewStyle"].waitForExistence(timeout: 3))
        saveWelcomeScreenshot(app)
        let previewStyle = app.popUpButtons["onboarding.previewStyle"]
        previewStyle.click()
        app.menuItems["CPU usage"].click()
        XCTAssertEqual(previewStyle.value as? String, "CPU usage")
        saveWelcomeScreenshot(app)
        let moreOptions = app.descendants(matching: .disclosureTriangle)["onboarding.moreOptions"]
        XCTAssertTrue(moreOptions.waitForExistence(timeout: 3))
        moreOptions.click()
        let autoSwitch = app.checkBoxes["onboarding.autoSwitch"]
        XCTAssertTrue(autoSwitch.waitForExistence(timeout: 3))
        XCTAssertTrue(checkboxIsOn(autoSwitch))
        autoSwitch.click()
        XCTAssertFalse(checkboxIsOn(autoSwitch))
        saveWelcomeScreenshot(app)
        next.click()
        XCTAssertTrue(app.staticTexts["onboarding.notificationStatus"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.checkBoxes["onboarding.autoSwitch"].exists)
        saveWelcomeScreenshot(app)
        next.click()
        XCTAssertTrue(next.waitForNonExistence(timeout: 3))

        // The same suite survives this launch; first-run presentation must stay suppressed.
        app.terminate()
        app.launchArguments.append("UITestsPreserveDefaults")
        app.launch()
        XCTAssertFalse(next.waitForExistence(timeout: 3))
        app.typeKey(",", modifierFlags: .command)
        let menuBar = app.buttons["Menu Bar"]
        XCTAssertTrue(menuBar.waitForExistence(timeout: 5))
        menuBar.click()
        XCTAssertEqual(app.popUpButtons["waveform.path.ecg"].value as? String, "Status icon")
        let savedAutoSwitch = app.checkBoxes["Auto switch to busiest metric"]
        XCTAssertTrue(savedAutoSwitch.exists)
        XCTAssertFalse(checkboxIsOn(savedAutoSwitch))
        let indicator = app.descendants(matching: .statusItem).firstMatch
        let showIndicator = app.checkBoxes["Show indicator"]
        showIndicator.click()
        XCTAssertTrue(indicator.waitForNonExistence(timeout: 3))
        showIndicator.click()
        XCTAssertTrue(indicator.waitForExistence(timeout: 3))
        let general = app.buttons["General"]
        XCTAssertTrue(general.waitForExistence(timeout: 5))
        general.click()
        XCTAssertFalse(app.buttons["onboarding.open"].exists)

        // Optional guidance belongs in Help, separate from app preferences.
        app.menuBars.menuBarItems["Help"].click()
        let menuLink = app.menuItems["Getting Started…"]
        XCTAssertTrue(menuLink.waitForExistence(timeout: 3))
        menuLink.click()
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["onboarding.step"].value as? String, "Step 1 of 2")
        app.buttons["onboarding.skip"].click()
    }

    func testApplyingPreviewStyleIsExplicitAndPersists() {
        let app = launchApp()
        app.launch()
        let picker = app.popUpButtons["onboarding.previewStyle"]
        XCTAssertTrue(picker.waitForExistence(timeout: 8))
        let apply = app.buttons["onboarding.applyStyle"]
        XCTAssertFalse(apply.isEnabled)
        picker.click()
        app.menuItems["Network throughput"].click()
        XCTAssertTrue(apply.isEnabled)
        apply.click()
        XCTAssertFalse(apply.isEnabled)
        // Continue and Done must not apply a subsequent exploratory selection.
        picker.click()
        app.menuItems["CPU usage"].click()
        app.buttons["onboarding.next"].click()
        app.buttons["onboarding.next"].click()
        app.terminate()
        app.launchArguments.append("UITestsPreserveDefaults")
        app.launch()
        app.typeKey(",", modifierFlags: .command)
        let menuBar = app.buttons["Menu Bar"]
        XCTAssertTrue(menuBar.waitForExistence(timeout: 5))
        menuBar.click()
        XCTAssertTrue(app.popUpButtons["arrow.up.arrow.down"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.popUpButtons["arrow.up.arrow.down"].value as? String, "Network throughput")
        app.menuBars.menuBarItems["Help"].click()
        app.menuItems["Getting Started…"].click()
        XCTAssertTrue(picker.waitForExistence(timeout: 3))
        XCTAssertEqual(picker.value as? String, "Network throughput")
        picker.click()
        app.menuItems["CPU usage"].click()
        app.buttons["onboarding.skip"].click()
        app.menuBars.menuBarItems["Help"].click()
        app.menuItems["Getting Started…"].click()
        XCTAssertTrue(picker.waitForExistence(timeout: 3))
        XCTAssertEqual(picker.value as? String, "Network throughput")
    }

    func testSkippingAndClosingSuppressFuturePresentation() {
        for closeWindow in [false, true] {
            let app = launchApp()
            app.launch()
            let next = app.buttons["onboarding.next"]
            XCTAssertTrue(next.waitForExistence(timeout: 8))
            if closeWindow {
                app.windows.containing(.button, identifier: "onboarding.next").firstMatch
                    .buttons[XCUIIdentifierCloseWindow].click()
            } else {
                app.buttons["onboarding.skip"].click()
            }
            XCTAssertTrue(next.waitForNonExistence(timeout: 3))
            app.terminate()
            app.launchArguments.append("UITestsPreserveDefaults")
            app.launch()
            XCTAssertFalse(next.waitForExistence(timeout: 3))
            app.terminate()
        }
    }

    private func checkboxIsOn(_ checkbox: XCUIElement) -> Bool {
        // Native macOS and SwiftUI controls can expose NSNumber or string accessibility values.
        if let value = checkbox.value as? NSNumber { return value.boolValue }
        return checkbox.value as? String == "1"
    }

    private func saveWelcomeScreenshot(_ app: XCUIApplication) {
        // Window captures can fail on secondary displays. Functional checks must not depend on capture support.
        guard ProcessInfo.processInfo.environment["ALERTIVITY_CAPTURE_ONBOARDING"] == "1" else { return }
        let window = app.windows.containing(.button, identifier: "onboarding.next").firstMatch
        let screenshot = window.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UITests", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        return app
    }

    private func selectMenuValue(in popup: XCUIElement, value: String) {
        guard popup.waitForExistence(timeout: 2) else { return }
        popup.click()

        let menuItem = popup.menuItems[value]
        if menuItem.waitForExistence(timeout: 2) {
            menuItem.click()
        }
    }
}
