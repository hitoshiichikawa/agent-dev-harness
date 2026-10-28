import XCTest

/// smoke 1 本のみ。ロジックは Domain のテストで。
final class SmokeUITests: XCTestCase {
    func testLaunchShowsExamplesWindow() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Examples"].exists || app.navigationBars["Examples"].exists)
    }
}
