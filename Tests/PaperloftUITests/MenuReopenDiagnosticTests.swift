import XCTest

/// Scoped regression through real menu controls; existing acceptance tests stay unchanged.
final class MenuReopenDiagnosticTests: XCTestCase {
    @MainActor func testMenuOpenInboxAfterClosingMain() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        if !app.buttons["sidebar.library"].waitForExistence(timeout: 3) {
            app.menuBars.menuBarItems["Window"].click()
            app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
        }
        XCTAssertTrue(app.buttons["sidebar.library"].waitForExistence(timeout: 10))
        app.buttons["sidebar.library"].click()
        XCTAssertEqual(app.staticTexts["content.title"].value as? String, "Library")
        app.typeKey("w", modifierFlags: .command)
        XCTAssertFalse(app.windows["main"].exists)
        let status = app.descendants(matching: .any).matching(identifier: "menubar.status").firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 10)); status.click()
        let open = app.buttons["menubar.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        XCTAssertTrue(open.isEnabled); XCTAssertTrue(open.isHittable)
        print("MENU_REOPEN_BEFORE \(app.debugDescription)")
        let before = XCTAttachment(screenshot: app.screenshot()); before.name = "Menu before Open Inbox"; before.lifetime = .keepAlways; add(before)
        open.click()
        let reopened = app.windows["main"].waitForExistence(timeout: 10)
        print("MENU_REOPEN_AFTER \(app.debugDescription)")
        let after = XCTAttachment(screenshot: app.screenshot()); after.name = "After Open Inbox"; after.lifetime = .keepAlways; add(after)
        XCTAssertTrue(reopened, "The real menu action must restore the closed main window")
        XCTAssertEqual(app.staticTexts["content.title"].value as? String, "A place for your paperwork")
    }
}
