import XCTest

final class CoreFlowTests: XCTestCase {
    @MainActor
    private func freshApp() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.buttons["sidebar.settings"].waitForExistence(timeout: 15))
        app.typeKey(",", modifierFlags: .command)
        let fresh = app.buttons["settings.newSampleLibrary"]
        XCTAssertTrue(fresh.waitForExistence(timeout: 10)); fresh.click()
        app.typeKey("w", modifierFlags: .command)
        app.buttons["sidebar.inbox"].click()
        XCTAssertTrue(app.buttons["inbox.import"].waitForExistence(timeout: 10))
        return app
    }
    @MainActor
    func testSamplesKeyboardEditFileSearchAndUndo() throws {
        continueAfterFailure = false
        let started = Date()
        let app = try freshApp(); defer { app.terminate() }
        app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        let vendor = app.textFields["review.vendor"]
        XCTAssertTrue(vendor.waitForExistence(timeout: 60))
        // Review starts at the vendor field; complete this review with keyboard only.
        app.typeKey("a", modifierFlags: .command); app.typeText("Keyboard Desk")
        app.typeKey(.tab, modifierFlags: [])
        app.typeKey("a", modifierFlags: .command); app.typeText("2026-07-12")
        app.typeKey(.tab, modifierFlags: [])
        app.typeKey("a", modifierFlags: .command); app.typeText("42.35")
        XCTAssertEqual(vendor.value as? String, "Keyboard Desk")
        XCTAssertEqual(app.textFields["review.total"].value as? String, "42.35")
        app.typeKey(.return, modifierFlags: [])
        app.buttons["sidebar.library"].click()
        XCTAssertTrue(app.staticTexts["Keyboard Desk"].waitForExistence(timeout: 15))
        XCTAssertLessThan(Date().timeIntervalSince(started), 60, "Samples must reach a filed document within 60 seconds from launch")
        XCTAssertTrue(app.staticTexts["$42.35"].exists)
        let search = app.textFields["library.search"]; search.click(); search.typeText("Keyboard")
        XCTAssertTrue(app.staticTexts["Keyboard Desk"].waitForExistence(timeout: 5))
        search.typeKey("a", modifierFlags: .command); search.typeText("no-such-vendor")
        XCTAssertTrue(app.staticTexts["No matching documents"].waitForExistence(timeout: 5))
        app.buttons["library.export"].click()
        let exportYear = app.popUpButtons["export.year"]
        XCTAssertTrue(exportYear.waitForExistence(timeout: 5)); exportYear.click()
        app.menuItems["2026"].click()
        app.buttons["export.create"].click()
        XCTAssertTrue(app.staticTexts["Export complete"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["export.result"].value as? String, "1 document copied, with transactions.csv and summary.pdf.")
        app.buttons["export.close"].click()
        app.buttons["sidebar.history"].click()
        let undo = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.undo.")).firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 5)); undo.click()
        XCTAssertTrue(app.staticTexts["Undone"].waitForExistence(timeout: 10))
        app.buttons["sidebar.library"].click()
        XCTAssertTrue(app.staticTexts["0 documents"].waitForExistence(timeout: 5))
    }
    @MainActor
    func testInvalidAmountCannotFileAndSetAsideAdvancesInbox() throws {
        continueAfterFailure = false
        let app = try freshApp(); defer { app.terminate() }
        app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        let total = app.textFields["review.total"]
        XCTAssertTrue(total.waitForExistence(timeout: 60)); total.click()
        total.typeKey("a", modifierFlags: .command); total.typeText("-2.00")
        XCTAssertFalse(app.buttons["review.file"].isEnabled)
        XCTAssertTrue(app.staticTexts["Enter the total shown on the receipt."].exists)
        app.buttons["review.setAside"].click()
        XCTAssertTrue(app.textFields["review.total"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.textFields["review.total"].value as? String, "12.50")
    }
    @MainActor
    func testDuplicateStateFollowsFilingAndUndo() throws {
        continueAfterFailure = false
        let app = try freshApp(); defer { app.terminate() }
        app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 60))
        app.buttons["review.file"].click()
        app.buttons["sidebar.library"].click()
        XCTAssertTrue(app.staticTexts["1 document"].waitForExistence(timeout: 15))
        app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        let repeatDocument = app.staticTexts["01-office.pdf"]
        XCTAssertTrue(repeatDocument.waitForExistence(timeout: 10)); repeatDocument.click()
        XCTAssertTrue(app.staticTexts["review.duplicate"].waitForExistence(timeout: 60))
        XCTAssertFalse(app.buttons["review.file"].isEnabled)
        app.buttons["sidebar.history"].click()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.undo.")).firstMatch.click()
        XCTAssertTrue(app.staticTexts["Undone"].waitForExistence(timeout: 10))
        app.buttons["sidebar.inbox"].click()
        XCTAssertTrue(app.buttons["review.file"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["review.duplicate"].exists)
        XCTAssertTrue(app.buttons["review.file"].isEnabled)
    }
    @MainActor
    func testDraftSurvivesRelaunch() throws {
        continueAfterFailure = false
        let app = try freshApp(); defer { app.terminate() }
        app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        let vendor = app.textFields["review.vendor"]
        XCTAssertTrue(vendor.waitForExistence(timeout: 60)); vendor.click()
        vendor.typeKey("a", modifierFlags: .command); vendor.typeText("Saved Draft")
        app.terminate(); app.launch(); app.activate()
        XCTAssertTrue(vendor.waitForExistence(timeout: 20))
        XCTAssertEqual(vendor.value as? String, "Saved Draft")
    }
    @MainActor
    func testCoreScreensAccessibilityAudit() throws {
        continueAfterFailure = true
        let app = try freshApp(); defer { app.terminate() }
        try audit(app)
        for section in ["library", "history"] {
            app.buttons["sidebar." + section].click()
            try audit(app)
        }
        // Audit Settings as the only window, every pane. While Settings is open the audit also
        // inspects the main window behind it, even minimized, and measures its elements against
        // whatever pixels cover them (evidence/a11y-probe/intake11-current/settings-isolation.md).
        // The main window's screens are audited above while active and unobstructed.
        app.typeKey("w", modifierFlags: .command)
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["settings.newSampleLibrary"].waitForExistence(timeout: 10))
        try audit(app)
        for pane in ["Filing", "Categories"] {
            let tab = app.toolbars.buttons[pane]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Settings pane \(pane)")
            tab.click()
            try audit(app)
        }
        app.typeKey("w", modifierFlags: .command)
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["settings.newSampleLibrary"].waitForExistence(timeout: 10), "Settings reopens on General")
        app.typeKey("w", modifierFlags: .command)
        app.menuBars.menuBarItems["Window"].click()
        app.menuBars.menuBarItems["Window"].menuItems["Paperloft Receipts"].click()
        XCTAssertTrue(app.buttons["sidebar.inbox"].waitForExistence(timeout: 10))
        app.buttons["sidebar.inbox"].click(); app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 60))
        try audit(app)
    }

    @MainActor
    private func audit(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit { issue in
            let detail = XCTAttachment(string: issue.detailedDescription + "\n" + (issue.element?.debugDescription ?? "No element"))
            detail.name = "Accessibility issue details"; detail.lifetime = .keepAlways
            self.add(detail)
            return false
        }
    }

}
