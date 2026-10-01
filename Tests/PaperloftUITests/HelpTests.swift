import XCTest

/// AC-20: the in-app Help page opens from the Help menu and covers every topic.
final class HelpTests: XCTestCase {
    @MainActor
    func testHelpMenuOpensHelpWithAllTopics() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate()
        defer { app.terminate() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        // The Window menu also lists the Help window, so pick the Help menu's own item.
        let helpMenu = app.menuBars.menuBarItems["Help"]
        helpMenu.click()
        helpMenu.menuItems["Paperloft Help"].click()
        XCTAssertTrue(app.staticTexts["help.title"].waitForExistence(timeout: 10))
        for topic in ["start", "add", "review", "undo", "export", "pro", "privacy", "support"] {
            XCTAssertTrue(app.staticTexts["help.topic.\(topic)"].exists || app.otherElements["help.topic.\(topic)"].exists
                          || app.descendants(matching: .any)["help.topic.\(topic)"].exists, "Help topic \(topic)")
        }
        XCTAssertTrue(app.descendants(matching: .any)["help.emailSupport"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["help.privacyPolicy"].exists)
        app.typeKey("w", modifierFlags: .command)
    }
}
