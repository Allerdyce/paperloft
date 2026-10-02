import XCTest

/// Critique follow-up: the export sheet uses native pickers, opens from File › Export for Accountant…,
/// and keeps its layout steady when the period changes.
final class ExportSheetTests: XCTestCase {
    @MainActor
    func testExportSheetUsesNativePickersAndSteadyLayout() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub", "-PaperloftStoreMock", "YES"]
        // Export is part of Pro; the mock store remembers it across the relaunch below.
        app.launch(); app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        app.makePro(); app.terminate()
        app.launch(); app.activate()
        defer { app.terminate() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        if !app.staticTexts["content.title"].waitForExistence(timeout: 3) {
            app.menuBars.menuBarItems["Window"].click()
            app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
        }
        XCTAssertTrue(app.staticTexts["content.title"].waitForExistence(timeout: 10))
        // Right after launch, while startup is still opening the library, ⇧⌘E opens the sheet once it's ready.
        app.typeKey("e", modifierFlags: [.command, .shift])
        let period = app.descendants(matching: .any)["export.period"]
        XCTAssertTrue(period.waitForExistence(timeout: 15), "⇧⌘E opens the export sheet")
        let sheet = app.sheets.firstMatch
        let year = app.popUpButtons["export.year"]
        XCTAssertTrue(year.exists, "the year is chosen from a pop-up, not typed")
        let yearFrame = sheet.frame, periodFrame = period.frame
        period.click(); app.menuItems["Quarter"].click()
        XCTAssertTrue(app.descendants(matching: .any)["export.quarter"].waitForExistence(timeout: 2))
        XCTAssertTrue(year.exists)
        XCTAssertEqual(sheet.frame.height, yearFrame.height, accuracy: 1, "switching to Quarter doesn't resize the sheet")
        period.click(); app.menuItems["Custom dates"].click()
        XCTAssertTrue(app.datePickers["export.start"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.datePickers["export.end"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["export.validation"].exists, "no error before any input")
        // Export is offered only when the period has filed receipts, and the summary says which.
        let summary = app.staticTexts["export.summary.count"]
        let empty = (summary.label.isEmpty ? (summary.value as? String ?? "") : summary.label).hasPrefix("No filed receipts")
        XCTAssertEqual(app.buttons["export.create"].isEnabled, !empty)
        XCTAssertEqual(sheet.frame.height, yearFrame.height, accuracy: 1, "switching to Custom dates doesn't resize the sheet")
        XCTAssertEqual(period.frame.minX, periodFrame.minX, accuracy: 1, "the Period control stays put")
        app.buttons["export.close"].click()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: period)
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 5), .completed, "Cancel closes the sheet")
    }
}
