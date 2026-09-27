import XCTest

final class MailFlowTests: XCTestCase {
    @MainActor func testEmailOpenPanelImportReviewsBodyAndAttachmentAndKeepsNotices() throws {
        continueAfterFailure = false
        let email = try XCTUnwrap(Bundle(for: MailFlowTests.self).url(forResource: "mail-receipt", withExtension: "eml"))
        let bytes = try Data(contentsOf: email)
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        XCTAssertTrue(app.buttons["toolbar.settings"].waitForExistence(timeout: 15))
        app.buttons["toolbar.settings"].click()
        XCTAssertTrue(app.buttons["settings.newSampleLibrary"].waitForExistence(timeout: 10))
        app.buttons["settings.newSampleLibrary"].click()
        app.typeKey("w", modifierFlags: .command)
        app.buttons["sidebar.inbox"].click()
        XCTAssertTrue(app.buttons["inbox.import"].waitForExistence(timeout: 10))
        app.buttons["inbox.import"].click()
        // Exercise the real file-selection grant, not an import test hook.
        app.typeKey("g", modifierFlags: [.command, .shift])
        let location = app.textFields.firstMatch
        XCTAssertTrue(location.waitForExistence(timeout: 10))
        location.typeText(email.path); location.typeKey(.return, modifierFlags: [])
        let open = app.windows["open-panel"].buttons["OKButton"]
        XCTAssertTrue(open.waitForExistence(timeout: 10)); open.click()
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 60))
        let notices = app.scrollViews["review.importNotices"]
        XCTAssertTrue(notices.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "value CONTAINS %@", "original email is unchanged")).firstMatch.exists)
        app.terminate(); app.launch(); app.activate()
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.scrollViews["review.importNotices"].exists)
        app.buttons["review.setAside"].click()
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.scrollViews["review.importNotices"].exists)
        app.buttons["sidebar.library"].click()
        XCTAssertTrue(app.staticTexts["0 documents"].waitForExistence(timeout: 10), "Email-derived documents must remain in review")
        XCTAssertEqual(try Data(contentsOf: email), bytes)
    }
}
