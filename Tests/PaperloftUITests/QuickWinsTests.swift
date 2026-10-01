import XCTest

/// Second design review copy/navigation follow-ups: View › Inbox/Library/History (⌘1–⌘3), one name
/// for the export, and an empty library that says how to fill it.
final class QuickWinsTests: XCTestCase {
    @MainActor
    func testSectionShortcutsExportNameAndEmptyLibrary() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        XCTAssertTrue(app.buttons["sidebar.settings"].waitForExistence(timeout: 15))
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["settings.newSampleLibrary"].waitForExistence(timeout: 10))
        app.buttons["settings.newSampleLibrary"].click(); app.typeKey("w", modifierFlags: .command)
        let heading = app.staticTexts["content.title"]
        func shows(_ title: String) -> Bool {
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", title), object: heading)], timeout: 5) == .completed
        }
        app.typeKey("2", modifierFlags: .command); XCTAssertTrue(shows("Library"), "⌘2 shows Library")
        XCTAssertTrue(app.staticTexts["No receipts filed yet"].waitForExistence(timeout: 5), "an empty library teaches the next step")
        app.typeKey("3", modifierFlags: .command); XCTAssertTrue(shows("History"), "⌘3 shows History")
        app.typeKey("1", modifierFlags: .command); XCTAssertTrue(shows("A place for your paperwork"), "⌘1 shows the Inbox")
        app.menuBars.menuBarItems["File"].click()
        XCTAssertTrue(app.menuBars.menuItems["Tax & Accountant Export…"].exists, "the File menu uses the same name as the button and sheet")
        app.typeKey(.escape, modifierFlags: [])
    }
}
