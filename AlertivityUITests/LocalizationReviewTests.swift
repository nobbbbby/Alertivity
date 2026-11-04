import Foundation
import XCTest

/// Opt-in screenshot matrix for release language and layout review in both built apps.
final class LocalizationReviewTests: XCTestCase {
    func testLocalizedOnboardingAndSettings() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let paths = environment["ALERTIVITY_LOCALIZATION_APPS"] else {
            throw XCTSkip("Set ALERTIVITY_LOCALIZATION_APPS to built app paths separated by | for language review.")
        }
        continueAfterFailure = false
        for path in paths.split(separator: "|").map(String.init) {
            let url = URL(fileURLWithPath: path)
            let bundle = try XCTUnwrap(Bundle(url: url))
            let isSourceBuild = bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String == "AlertivityNonSandboxed"
            let stepCount = isSourceBuild ? 2 : 3
            let requested = environment["ALERTIVITY_LOCALIZATION_LOCALES"]?.split(separator: ",").map(String.init)
            let locales = requested ?? bundle.localizations.filter { $0 != "Base" }.sorted()
            for locale in locales {
                try XCTContext.runActivity(named: "\(url.lastPathComponent) · \(locale)") { activity in
                    let localizedPath = try XCTUnwrap(bundle.path(forResource: locale, ofType: "lproj"))
                    let localized = try XCTUnwrap(Bundle(path: localizedPath))
                    func text(_ key: String) -> String {
                        localized.localizedString(forKey: key, value: nil, table: "Localizable")
                    }
                    let app = XCUIApplication(url: url)
                    app.launchArguments = ["UITests", "-AppleLanguages", "(\(locale))", "-AppleLocale", locale]
                    let direction = Locale.Language(identifier: locale).characterDirection == .rightToLeft ? "YES" : "NO"
                    app.launchArguments += ["-AppleTextDirection", direction, "-NSForceRightToLeftWritingDirection", direction]
                    app.launch()
                    defer { app.terminate() }
                    let next = app.buttons["onboarding.next"]
                    XCTAssertTrue(next.waitForExistence(timeout: 10))
                    let step = app.staticTexts["onboarding.step"]
                    let expectedStep = String(format: text("onboarding.step"), locale: Locale(identifier: locale), arguments: [1, stepCount])
                    XCTAssertEqual(step.value as? String, expectedStep)
                    capture(app, activity: activity, name: "\(url.lastPathComponent) \(locale) · Onboarding 1")
                    next.click()
                    let notificationStatus = app.staticTexts["onboarding.notificationStatus"]
                    XCTAssertTrue(notificationStatus.exists || notificationStatus.waitForExistence(timeout: 5))
                    capture(app, activity: activity, name: "\(url.lastPathComponent) \(locale) · Onboarding 2")
                    if !isSourceBuild {
                        next.click()
                        let proIntroduction = app.staticTexts["onboarding.pro.introduction"]
                        XCTAssertTrue(proIntroduction.exists || proIntroduction.waitForExistence(timeout: 5))
                        capture(app, activity: activity, name: "\(url.lastPathComponent) \(locale) · Onboarding Pro")
                    }
                    app.buttons["onboarding.skip"].click()
                    app.activate()
                    // The native Settings shortcut can differ in RTL languages.
                    let appMenu = app.menuBars.menuBarItems["Alertivity"]
                    appMenu.click()
                    appMenu.menus.firstMatch.menuItems.element(boundBy: 2).click()
                    let tabKeys = ["settings.tab.general", "settings.tab.menuBar", "settings.tab.notifications", "settings.tab.thresholds"]
                        + [isSourceBuild ? "settings.tab.detection" : "pro.tabTitle"]
                    for key in tabKeys {
                        // Native tabs are toolbar buttons on recent macOS and radio buttons on older releases.
                        let title = text(key)
                        let button = app.buttons[title].exists ? app.buttons[title] : app.radioButtons[title]
                        if environment["ALERTIVITY_REQUIRE_VISIBLE_TABS"] == "1" {
                            XCTAssertTrue(button.exists || button.waitForExistence(timeout: 5), "Tab should fit without overflow: \(title)")
                            if locale == "en" {
                                XCTAssertEqual(app.windows.firstMatch.frame.width, 400, accuracy: 1)
                            }
                            button.click()
                        } else if button.exists {
                            button.click()
                        } else {
                            // Compact Settings windows expose longer tab labels in native toolbar overflow.
                            let overflow = app.toolbars.popUpButtons.firstMatch
                            XCTAssertTrue(overflow.waitForExistence(timeout: 5), "Missing localized tab: \(title)")
                            overflow.click()
                            let item = app.menuItems[title]
                            XCTAssertTrue(item.waitForExistence(timeout: 5), "Missing overflow tab: \(title)")
                            item.click()
                        }
                        if environment["ALERTIVITY_REQUIRE_CONTENT_FIT"] == "1" {
                            assertContentFits(app.windows.firstMatch)
                        }
                        capture(app, activity: activity, name: "\(url.lastPathComponent) \(locale) · \(key)")
                    }
                }
            }
        }
    }

    private func assertContentFits(_ window: XCUIElement) {
        let bounds = window.frame
        let elements = window.staticTexts.allElementsBoundByIndex + window.textFields.allElementsBoundByIndex
            + window.buttons.allElementsBoundByIndex + window.popUpButtons.allElementsBoundByIndex
            + window.checkBoxes.allElementsBoundByIndex
        for element in elements {
            let frame = element.frame
            guard frame.width > 0, frame.minX.isFinite, element.isHittable else { continue }
            XCTAssertGreaterThanOrEqual(frame.minX, bounds.minX - 1, "Content extends beyond Settings: \(element.identifier)")
            XCTAssertLessThanOrEqual(frame.maxX, bounds.maxX + 1, "Content extends beyond Settings: \(element.identifier)")
        }
    }

    private func capture(_ app: XCUIApplication, activity: XCTActivity, name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        activity.add(attachment)
    }
}
