import XCTest

/// Component diagnostic: explicitly primes the public window command when needed.
/// Does not replace launch acceptance or the existing CoreFlowTests.
final class InboxRowDiagnosticTests: XCTestCase {
    @MainActor
    func testRowSelectionStatusAndDuplicateUndoAfterWindowPriming() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        if !app.buttons["toolbar.settings"].waitForExistence(timeout: 3) {
            app.menuBars.menuBarItems["Window"].click()
            app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
        }
        XCTAssertTrue(app.buttons["toolbar.settings"].waitForExistence(timeout: 10))
        app.buttons["toolbar.settings"].click()
        let fresh = app.buttons["settings.newSampleLibrary"]
        XCTAssertTrue(fresh.waitForExistence(timeout: 10)); fresh.click()
        app.typeKey("w", modifierFlags: .command)
        app.buttons["sidebar.inbox"].click()
        XCTAssertTrue(app.buttons["inbox.samples"].waitForExistence(timeout: 10))
        app.buttons["inbox.samples"].click()
        let vendor = app.textFields["review.vendor"]
        XCTAssertTrue(vendor.waitForExistence(timeout: 60))
        XCTAssertTrue(app.staticTexts["Ready to review"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "inbox.item.")).firstMatch.exists)
        vendor.click(); vendor.typeKey("a", modifierFlags: .command); vendor.typeText("First row edited")
        let second = app.staticTexts["02-meal.pdf"]
        XCTAssertTrue(second.waitForExistence(timeout: 10)); second.click()
        XCTAssertTrue(vendor.waitForExistence(timeout: 60))
        XCTAssertNotEqual(vendor.value as? String, "First row edited")
        vendor.click(); vendor.typeKey("a", modifierFlags: .command); vendor.typeText("Second row edited")
        app.staticTexts["01-office.pdf"].click()
        XCTAssertEqual(vendor.value as? String, "First row edited")
        app.buttons["review.file"].click()
        app.buttons["sidebar.library"].click()
        XCTAssertTrue(app.staticTexts["1 documents"].waitForExistence(timeout: 15))
        app.buttons["toolbar.samples"].click()
        let repeated = app.staticTexts["01-office.pdf"]
        XCTAssertTrue(repeated.waitForExistence(timeout: 10)); repeated.click()
        XCTAssertTrue(app.staticTexts["review.duplicate"].waitForExistence(timeout: 60))
        XCTAssertTrue(app.staticTexts["Duplicate"].firstMatch.exists)
        XCTAssertFalse(app.buttons["review.file"].isEnabled)
        let duplicate = XCTAttachment(screenshot: app.screenshot())
        duplicate.name = "Equatable row duplicate status"; duplicate.lifetime = .keepAlways; add(duplicate)
        app.buttons["sidebar.history"].click()
        let undo = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.undo.")).firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 10)); undo.click()
        XCTAssertTrue(app.staticTexts["Undone"].waitForExistence(timeout: 10))
        app.buttons["sidebar.inbox"].click()
        XCTAssertTrue(app.buttons["review.file"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["review.duplicate"].exists)
        XCTAssertFalse(app.staticTexts["Duplicate"].exists)
        XCTAssertTrue(app.staticTexts["Ready to review"].firstMatch.exists)
        XCTAssertTrue(app.buttons["review.file"].isEnabled)
        let restored = XCTAttachment(screenshot: app.screenshot())
        restored.name = "Equatable row ready after undo"; restored.lifetime = .keepAlways; add(restored)
    }
}
