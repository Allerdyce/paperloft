import XCTest

/// Critique follow-up for the review form: one label column, equal-width controls,
/// and a currency pop-up instead of free text.
final class ReviewFormTests: XCTestCase {
    @MainActor
    func testReviewFormAlignsControlsAndPicksCurrency() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        let vendor = app.textFields["review.vendor"]
        XCTAssertTrue(vendor.waitForExistence(timeout: 60))
        let currency = app.popUpButtons["review.currency"], category = app.popUpButtons["review.category"]
        let kind = app.popUpButtons["review.kind"], total = app.textFields["review.total"]
        XCTAssertTrue(currency.exists, "currency is a pop-up")
        // Every control starts in the same column and shares its width.
        for control in [total, currency, category, kind] {
            XCTAssertEqual(control.frame.minX, vendor.frame.minX, accuracy: 2, "\(control.identifier) starts in the control column")
            XCTAssertEqual(control.frame.width, vendor.frame.width, accuracy: 4, "\(control.identifier) matches the field width")
        }
        XCTAssertTrue((currency.value as? String ?? "").hasPrefix("USD"), "the document's currency is selected")
        currency.click()
        let euro = app.menuItems.matching(NSPredicate(format: "title BEGINSWITH 'EUR'")).firstMatch
        XCTAssertTrue(euro.waitForExistence(timeout: 3)); euro.click()
        XCTAssertTrue((currency.value as? String ?? "").hasPrefix("EUR"), "choosing a currency updates the review")
        let shot = XCTAttachment(screenshot: app.windows["main"].screenshot()); shot.name = "Review form"; shot.lifetime = .keepAlways; add(shot)
        currency.click()
        let dollar = app.menuItems.matching(NSPredicate(format: "title BEGINSWITH 'USD'")).firstMatch
        XCTAssertTrue(dollar.waitForExistence(timeout: 3)); dollar.click()
    }
}
