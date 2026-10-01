import XCTest

/// Second design review follow-ups: rows lead with merchant and total, History and the export sheet
/// say what they hold, and Settings shows what the file name pattern produces.
final class PolishTwoTests: XCTestCase {
    @MainActor
    func testRowsHistoryExportAndFileNameSayWhatTheyHold() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub", "-PaperloftStoreMock", "YES"]
        app.launch(); app.activate(); defer { app.terminate() }
        XCTAssertTrue(app.buttons["sidebar.settings"].waitForExistence(timeout: 15))
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["settings.newSampleLibrary"].waitForExistence(timeout: 10))
        app.buttons["settings.newSampleLibrary"].click()
        app.toolbars.buttons["Filing"].click()
        let example = app.staticTexts["settings.fileNameExample"]
        XCTAssertTrue(example.waitForExistence(timeout: 5))
        func text(_ element: XCUIElement) -> String { element.label.isEmpty ? (element.value as? String ?? "") : element.label }
        XCTAssertTrue(text(example).hasPrefix("Example: 2026-09-08"), text(example))
        app.typeKey("w", modifierFlags: .command)

        app.typeKey("3", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["No filings yet"].waitForExistence(timeout: 5))
        app.typeKey("1", modifierFlags: .command)
        app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 60))
        let summary = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Sample merchant · ' OR value BEGINSWITH 'Sample merchant · '")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10), "a read document's row leads with merchant and total")
        XCTAssertTrue(text(summary).contains("$12.50"), text(summary))

        app.typeKey("e", modifierFlags: [.command, .shift])
        let count = app.staticTexts["export.summary.count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertTrue(text(count).hasPrefix("0 receipts"), text(count))
        XCTAssertTrue(app.buttons["export.reviewInbox"].exists, "unfiled Inbox receipts are pointed out")
        app.buttons["export.reviewInbox"].click()
        XCTAssertTrue(count.waitForNonExistence(timeout: 5), "Review Inbox closes the sheet")
    }
}
