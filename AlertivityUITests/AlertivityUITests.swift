import XCTest

final class AlertivityUITests: XCTestCase {
    func testAppLaunchesAndStaysActive() {
        let app = XCUIApplication()
        app.launchArguments.append("UITests")
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
}
