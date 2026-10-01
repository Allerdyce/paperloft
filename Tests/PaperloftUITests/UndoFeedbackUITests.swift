import XCTest

/// Second design review P1s in the running app: filing shows where the document went with Undo,
/// Undo returns it to the Inbox, and ⌘Z in a review field undoes typing rather than a filing.
final class UndoFeedbackUITests: XCTestCase {
    @MainActor
    func testFilingNoticeUndoAndTextUndoPrecedence() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        XCTAssertTrue(app.buttons["sidebar.settings"].waitForExistence(timeout: 15))
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["settings.newSampleLibrary"].waitForExistence(timeout: 10))
        app.buttons["settings.newSampleLibrary"].click(); app.typeKey("w", modifierFlags: .command)
        app.buttons["sidebar.inbox"].click()
        app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        let vendor = app.textFields["review.vendor"]
        XCTAssertTrue(vendor.waitForExistence(timeout: 60))
        func text(_ element: XCUIElement) -> String { element.label.isEmpty ? (element.value as? String ?? "") : element.label }
        // The All chip counts every Inbox document; the list itself only exposes rows on screen.
        let all = app.buttons["inbox.filter.All"]
        func inboxCount() -> Int { Int(text(all).filter(\.isNumber)) ?? -1 }
        XCTAssertTrue(all.waitForExistence(timeout: 10))
        let count = inboxCount()

        // Confirm: a notice says where it was filed and offers Undo.
        app.buttons["review.file"].click()
        let notice = app.staticTexts["inbox.notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 10))
        XCTAssertTrue(text(notice).hasPrefix("Filed to "), text(notice))
        let banner = XCTAttachment(screenshot: app.windows["main"].screenshot()); banner.name = "Filing notice"; banner.lifetime = .keepAlways; add(banner)
        XCTAssertEqual(inboxCount(), count - 1)

        // ⌘Z while typing in a field undoes the typing, not the filing.
        XCTAssertTrue(vendor.waitForExistence(timeout: 10))
        vendor.click(); app.typeKey("a", modifierFlags: .command); app.typeText("Typo Vendor")
        let typed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Typo Vendor'"), object: vendor)
        XCTAssertEqual(XCTWaiter().wait(for: [typed], timeout: 3), .completed, "typed: \(vendor.value as? String ?? "nil")")
        app.typeKey("z", modifierFlags: .command)
        let untyped = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != 'Typo Vendor'"), object: vendor)
        XCTAssertEqual(XCTWaiter().wait(for: [untyped], timeout: 3), .completed, "⌘Z undid the typing")
        XCTAssertEqual(inboxCount(), count - 1, "the filing was not undone by text undo")

        // The notice's Undo returns the document to the Inbox.
        // History's Undo returns the document to the Inbox and offers to show it.
        app.buttons["sidebar.history"].click()
        let undo = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.undo.")).firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 10)); undo.click()
        XCTAssertTrue(app.staticTexts["Returned to the Inbox for review"].waitForExistence(timeout: 10))
        let show = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.showInInbox.")).firstMatch
        XCTAssertTrue(show.waitForExistence(timeout: 10)); show.click()
        XCTAssertTrue(all.waitForExistence(timeout: 10))
        let back = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in inboxCount() == count }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [back], timeout: 15), .completed, "the undone document is back in the Inbox")
        XCTAssertTrue(app.staticTexts["Returned by Undo"].waitForExistence(timeout: 5), "its row says where it came from")
    }
}
