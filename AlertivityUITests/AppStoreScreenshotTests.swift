import Foundation
import StoreKitTest
import XCTest

/// Manual release capture uses the App Store build and local StoreKit without making a purchase.
final class AppStoreScreenshotTests: XCTestCase {
    func testCaptureProReview() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let appPath = environment["ALERTIVITY_SCREENSHOT_APP"] else {
            throw XCTSkip("Run the manual App Store screenshot workflow with an explicit app path.")
        }
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("StoreKit/Alertivity.storekit")
        let session = try SKTestSession(contentsOf: fixture)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }

        let app = XCUIApplication(url: URL(fileURLWithPath: appPath))
        app.launchArguments = ["UITests", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        defer { app.terminate() }
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        skip.click()
        app.typeKey(",", modifierFlags: .command)
        let pro = app.buttons["Pro"].exists ? app.buttons["Pro"] : app.radioButtons["Pro"]
        XCTAssertTrue(pro.waitForExistence(timeout: 10))
        pro.click()
        XCTAssertTrue(app.buttons["pro.restore"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pro.purchase"].waitForExistence(timeout: 20))
        let window = app.windows.containing(.button, identifier: "pro.restore").firstMatch
        XCTAssertTrue(window.exists)
        let screenshot = window.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "App Store Pro review (local StoreKit)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
