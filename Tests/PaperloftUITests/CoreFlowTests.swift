import XCTest

final class CoreFlowTests: XCTestCase {
    @MainActor
    private func freshApp() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.buttons["toolbar.settings"].waitForExistence(timeout: 15))
        app.buttons["toolbar.settings"].click()
        let fresh = app.buttons["settings.newSampleLibrary"]
        XCTAssertTrue(fresh.waitForExistence(timeout: 10)); fresh.click()
        app.typeKey("w", modifierFlags: .command)
        app.buttons["sidebar.inbox"].click()
        XCTAssertTrue(app.buttons["inbox.samples"].waitForExistence(timeout: 10))
        return app
    }
    @MainActor
    func testSamplesKeyboardEditFileSearchAndUndo() throws {
        continueAfterFailure = false
        let app = try freshApp(); defer { app.terminate() }
        let started = Date()
        app.buttons["inbox.samples"].click()
        let vendor = app.textFields["review.vendor"]
        XCTAssertTrue(vendor.waitForExistence(timeout: 60))
        // Review starts at the vendor field; complete this review with keyboard only.
        app.typeKey("a", modifierFlags: .command); app.typeText("Keyboard Desk")
        app.typeKey(.tab, modifierFlags: [])
        app.typeKey("a", modifierFlags: .command); app.typeText("2026-07-12")
        app.typeKey(.tab, modifierFlags: [])
        app.typeKey("a", modifierFlags: .command); app.typeText("42.35")
        XCTAssertEqual(vendor.value as? String, "Keyboard Desk")
        XCTAssertEqual(app.textFields["review.total"].value as? String, "42.35")
        app.typeKey(.return, modifierFlags: [])
        app.buttons["sidebar.library"].click()
        XCTAssertTrue(app.staticTexts["Keyboard Desk"].waitForExistence(timeout: 15))
        XCTAssertLessThan(Date().timeIntervalSince(started), 60, "Samples must reach a filed document within60seconds")
        XCTAssertTrue(app.staticTexts["USD 42.35"].exists)
        let search = app.textFields["library.search"]; search.click(); search.typeText("Keyboard")
        XCTAssertTrue(app.staticTexts["Keyboard Desk"].waitForExistence(timeout: 5))
        search.typeKey("a", modifierFlags: .command); search.typeText("no-such-vendor")
        XCTAssertTrue(app.staticTexts["No matching documents"].waitForExistence(timeout: 5))
        app.buttons["sidebar.history"].click()
        let undo = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.undo.")).firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 5)); undo.click()
        XCTAssertTrue(app.staticTexts["Undone"].waitForExistence(timeout: 10))
        app.buttons["sidebar.library"].click()
        XCTAssertTrue(app.staticTexts["0 documents"].waitForExistence(timeout: 5))
    }
    @MainActor
    func testInvalidAmountCannotFileAndSetAsideAdvancesInbox() throws {
        continueAfterFailure = false
        let app = try freshApp(); defer { app.terminate() }
        app.buttons["inbox.samples"].click()
        let total = app.textFields["review.total"]
        XCTAssertTrue(total.waitForExistence(timeout: 60)); total.click()
        total.typeKey("a", modifierFlags: .command); total.typeText("-2.00")
        XCTAssertFalse(app.buttons["review.file"].isEnabled)
        XCTAssertTrue(app.staticTexts["review.validation"].exists)
        app.buttons["review.setAside"].click()
        XCTAssertTrue(app.textFields["review.total"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.textFields["review.total"].value as? String, "12.50")
    }
}
