import XCTest

/// Critique follow-up: receipt actions are reachable as menu commands with safe shortcuts.
final class ReceiptMenuTests: XCTestCase {
    @MainActor
    func testReceiptMenuNavigatesAndFiles() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate()
        defer { app.terminate() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 60))
        // Stub documents share one vendor, so follow the selected Inbox row instead.
        let rowTypes = [XCUIElement.ElementType.outlineRow, .tableRow, .cell].map(\.rawValue)
        let selectedRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "isSelected == true AND elementType IN %@", rowTypes)).firstMatch
        func selectedID() -> String? {
            guard selectedRow.exists else { return nil }
            let content = selectedRow.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'inbox.item.'")).firstMatch
            return content.exists ? content.identifier : nil
        }
        func waitForSelection(_ matches: @escaping (String?) -> Bool) -> Bool {
            let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in matches(selectedID()) }, object: nil)
            return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
        }
        let receiptMenu = app.menuBars.menuBarItems["Receipt"]
        XCTAssertTrue(receiptMenu.exists)
        XCTAssertTrue(waitForSelection { $0 != nil }, "the Inbox shows a selected document")
        let first = try XCTUnwrap(selectedID())
        receiptMenu.click(); receiptMenu.menuItems["Next Document"].click()
        XCTAssertTrue(waitForSelection { $0 != nil && $0 != first }, "Next Document selects a different document")
        receiptMenu.click(); receiptMenu.menuItems["Previous Document"].click()
        XCTAssertTrue(waitForSelection { $0 == first }, "Previous Document returns to the first document")
        receiptMenu.click(); receiptMenu.menuItems["Confirm and File"].click()
        let filed = app.descendants(matching: .any)[first]
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: filed)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 15), .completed, "Confirm and File files the document and removes it from the Inbox")
    }
}
