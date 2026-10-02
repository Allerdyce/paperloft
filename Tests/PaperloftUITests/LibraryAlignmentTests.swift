import XCTest

/// Critique follow-up for the Library: sortable column headers that line up with their values,
/// localized dates and amounts, toolbar actions, and Edit › Find… (⌘F).
final class LibraryAlignmentTests: XCTestCase {
    @MainActor
    func testLibraryHeadersSortAlignAndFind() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "parser"]
        app.launch(); app.activate(); defer { app.terminate() }
        if !app.buttons["sidebar.settings"].waitForExistence(timeout: 3) {
            app.menuBars.menuBarItems["Window"].click()
            app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
        }
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["settings.newSampleLibrary"].waitForExistence(timeout: 10))
        app.buttons["settings.newSampleLibrary"].click(); app.typeKey("w", modifierFlags: .command)
        app.buttons["sidebar.inbox"].click()
        app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        for file in ["01-office.pdf", "02-meal.pdf", "03-travel.pdf", "04-software.pdf", "05-utilities.pdf"] {
            XCTAssertTrue(app.staticTexts[file].waitForExistence(timeout: 30)); app.staticTexts[file].click()
            XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 30))
            app.buttons["review.file"].click()
            XCTAssertTrue(app.staticTexts[file].waitForNonExistence(timeout: 15))
        }
        app.buttons["sidebar.library"].click()
        XCTAssertTrue(app.staticTexts["5 receipts"].waitForExistence(timeout: 15))

        // SwiftUI puts a text's string in the accessibility value when it has an identifier.
        func text(_ element: XCUIElement) -> String { element.label.isEmpty ? (element.value as? String ?? "") : element.label }
        // Headers sit over their values.
        let dates = app.staticTexts.matching(identifier: "library.date"), totals = app.staticTexts.matching(identifier: "library.total")
        XCTAssertEqual(app.buttons["library.sort.Date"].frame.minX, dates.firstMatch.frame.minX, accuracy: 2, "Date header lines up with the dates")
        XCTAssertEqual(app.buttons["library.sort.Total"].frame.maxX, totals.firstMatch.frame.maxX, accuracy: 2, "Total header lines up with the amounts")
        let amounts = totals.allElementsBoundByIndex.map(text)
        XCTAssertEqual(amounts.count, 5)
        XCTAssertTrue(amounts.allSatisfy { $0.hasPrefix("$") }, "amounts are localized currency: \(amounts)")
        let firstDate = text(dates.firstMatch)
        XCTAssertFalse(firstDate.isEmpty || firstDate.contains("-"), "dates are localized, not ISO: \(firstDate)")

        // Sorting.
        func merchants() -> [String] { app.staticTexts.matching(identifier: "library.merchant").allElementsBoundByIndex.map(text) }
        app.buttons["library.sort.Merchant"].click()
        let ascending = merchants()
        XCTAssertEqual(ascending.count, 5)
        XCTAssertFalse(ascending.contains(""), "merchant names are readable: \(ascending)")
        XCTAssertEqual(ascending, ascending.sorted { $0.localizedStandardCompare($1) == .orderedAscending }, "Merchant sorts A to Z")
        XCTAssertEqual(app.buttons["library.sort.Merchant"].value as? String, "Ascending")
        app.buttons["library.sort.Merchant"].click()
        XCTAssertEqual(merchants(), ascending.reversed(), "a second click reverses the order")
        // The order survives a trip to another section.
        app.buttons["sidebar.history"].click(); app.buttons["sidebar.library"].click()
        XCTAssertTrue(app.staticTexts["5 receipts"].waitForExistence(timeout: 10))
        XCTAssertEqual(merchants(), ascending.reversed(), "sort order is kept when coming back to Library")

        // Toolbar actions follow the selection.
        XCTAssertFalse(app.buttons["library.reveal"].isEnabled)
        app.staticTexts.matching(identifier: "library.merchant").firstMatch.click()
        XCTAssertTrue(app.buttons["library.reveal"].isEnabled)
        XCTAssertTrue(app.buttons["library.quickLook"].isEnabled)
        let light = XCTAttachment(screenshot: app.windows["main"].screenshot()); light.name = "Library sorted by merchant"; light.lifetime = .keepAlways; add(light)

        // ⌘F from another section opens the Library with search focused.
        app.buttons["sidebar.inbox"].click()
        app.typeKey("f", modifierFlags: .command)
        let search = app.textFields["library.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: search)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 5), .completed, "⌘F focuses Library search")
        app.typeText("Juniper")
        XCTAssertTrue(app.staticTexts["1 receipt"].waitForExistence(timeout: 10), "typing after ⌘F searches the Library")
    }
}
