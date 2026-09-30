import XCTest

/// Critique follow-up for Settings: folders shown as Finder shows them, each pane sized to its
/// content, a native category list with +/−, and View › Show/Hide Sidebar.
final class SettingsPolishTests: XCTestCase {
    @MainActor
    func testSettingsPanesFitAndCategoriesUseList() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        XCTAssertTrue(app.buttons["sidebar.settings"].waitForExistence(timeout: 15))
        let view = app.menuBars.menuBarItems["View"]; view.click()
        XCTAssertTrue(view.menuItems.matching(NSPredicate(format: "title ENDSWITH 'Sidebar'")).firstMatch.exists, "View menu toggles the sidebar")
        app.typeKey(.escape, modifierFlags: [])

        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["settings.newSampleLibrary"].waitForExistence(timeout: 10))
        let window = app.windows.containing(.any, identifier: "settings.root").firstMatch
        let practice = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Practice library' OR value CONTAINS 'Practice library'")).firstMatch
        XCTAssertTrue(practice.exists, "the library shows a readable name, not a container path")
        XCTAssertEqual(app.buttons["settings.reveal"].label, "Show in Finder")
        // The pane ends near the window's bottom edge: no large empty band, nothing cut off.
        let lastGeneral = app.staticTexts["© 2026 EvidencePair LLC"]
        XCTAssertTrue(lastGeneral.exists)
        XCTAssertLessThan(window.frame.maxY - lastGeneral.frame.maxY, 60, "General fits its content")
        XCTAssertGreaterThan(window.frame.maxY, lastGeneral.frame.maxY)

        app.toolbars.buttons["Categories"].click()
        let addButton = app.buttons["settings.addCategory"], removeButton = app.buttons["settings.removeCategory"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        XCTAssertLessThan(window.frame.maxY - addButton.frame.maxY, 60, "Categories fits its content")
        XCTAssertGreaterThan(window.frame.maxY, addButton.frame.maxY)
        let before = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'settings.category.'")).count
        addButton.click()
        let added = app.textFields.matching(NSPredicate(format: "value BEGINSWITH 'New Category'")).firstMatch
        XCTAssertTrue(added.waitForExistence(timeout: 3), "+ adds a category")
        XCTAssertTrue(removeButton.isEnabled, "the new category is selected")
        removeButton.click()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: added)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 3), .completed, "− removes the selected category")
        XCTAssertEqual(app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'settings.category.'")).count, before)
        let shot = XCTAttachment(screenshot: window.screenshot()); shot.name = "Settings Categories"; shot.lifetime = .keepAlways; add(shot)
        app.toolbars.buttons["General"].click()
        let general = XCTAttachment(screenshot: window.screenshot()); general.name = "Settings General"; general.lifetime = .keepAlways; add(general)
        app.typeKey("w", modifierFlags: .command)
    }
}
