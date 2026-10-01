import XCTest

/// QA-08: Return alone doesn't file a document whose total Paperloft couldn't verify; it moves
/// focus to the total. Clicking Confirm or ⌘Return files it, and correcting the total restores Return.
final class FlaggedTotalTests: XCTestCase {
    @MainActor
    func testReturnDoesNotFileAnUnverifiedTotal() throws {
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
        let vendor = app.textFields["review.vendor"], total = app.textFields["review.total"]
        XCTAssertTrue(vendor.waitForExistence(timeout: 60))
        app.waitForInboxToSettle()
        // Stub fields disagree with each sample's text, so the total is flagged.
        XCTAssertTrue(app.staticTexts["Verify total against receipt."].waitForExistence(timeout: 10))
        let hint = app.staticTexts["review.keyboardHint"]
        func text(_ element: XCUIElement) -> String { element.label.isEmpty ? (element.value as? String ?? "") : element.label }
        XCTAssertTrue(text(hint).contains("⌘Return"), "the hint explains how to confirm: \(text(hint))")
        let selectedBefore = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'inbox.item.'")).count
        vendor.click(); app.typeKey(.return, modifierFlags: [])
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: total)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 3), .completed, "Return moves to the flagged total")
        XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'inbox.item.'")).count, selectedBefore,
                       "nothing was filed")
        // Correcting the total clears the flag and Return files again.
        total.typeKey("a", modifierFlags: .command); total.typeText("13.75")
        XCTAssertTrue(text(hint).hasPrefix("Return to confirm"), "a corrected total can be confirmed with Return")
        app.typeKey(.return, modifierFlags: [])
        let filed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count < %d", selectedBefore),
                                              object: app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'inbox.item.'")))
        XCTAssertEqual(XCTWaiter().wait(for: [filed], timeout: 15), .completed, "Return files once the total is corrected")
    }
}
