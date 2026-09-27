import XCTest

final class NavigationTests: XCTestCase {
    @MainActor
    func testSidebarNavigation() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch()
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), "App must be foreground before clicking")
        let heading = app.staticTexts["content.title"]
        XCTAssertTrue(heading.waitForExistence(timeout: 10))
        app.buttons["sidebar.inbox"].click()
        XCTAssertEqual(heading.value as? String, "A place for your paperwork")
        app.buttons["sidebar.library"].click()
        XCTAssertEqual(heading.value as? String, "Library")
        app.buttons["sidebar.history"].click()
        XCTAssertEqual(heading.value as? String, "History")
        app.terminate()
    }
}
