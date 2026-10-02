import XCTest
import AppKit

/// AC-11 purchase flows with the mock store (Debug/QA only): the paywall at the 26th document of a
/// month, buy yearly, buy lifetime, restore, expiry back to Free, and the paywall at the first export.
/// Real StoreKit purchases are exercised in the supervised shakedown with the local StoreKit file.
final class PaywallFlowTests: XCTestCase {
    @MainActor private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"] + arguments
        app.launch(); app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        if !app.buttons["sidebar.settings"].waitForExistence(timeout: 5) {
            app.menuBars.menuBarItems["Window"].click()
            app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
        }
        XCTAssertTrue(app.buttons["sidebar.settings"].waitForExistence(timeout: 10))
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["settings.newSampleLibrary"].waitForExistence(timeout: 10))
        app.buttons["settings.newSampleLibrary"].click(); app.typeKey("w", modifierFlags: .command)
        app.buttons["sidebar.inbox"].click()
        return app
    }
    @MainActor private func text(_ element: XCUIElement) -> String { element.label.isEmpty ? (element.value as? String ?? "") : element.label }
    @MainActor private func lifetimeChoice(_ app: XCUIApplication) -> XCUIElement {
        app.radioButtons.matching(NSPredicate(format: "label BEGINSWITH 'Lifetime'")).firstMatch
    }
    private func receiptPDF() throws -> URL {
        let pdf = NSMutableData()
        var page = CGRect(x: 0, y: 0, width: 400, height: 400)
        let context = try XCTUnwrap(CGContext(consumer: XCTUnwrap(CGDataConsumer(data: pdf)), mediaBox: &page, nil))
        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        ("Limit Test Stationers\n2026-09-14\nTotal USD 18.25 \(UUID().uuidString.prefix(6))" as NSString)
            .draw(at: NSPoint(x: 30, y: 300), withAttributes: [.font: NSFont.systemFont(ofSize: 18)])
        NSGraphicsContext.restoreGraphicsState(); context.endPDFPage(); context.closePDF()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("limit-\(UUID().uuidString).pdf")
        try (pdf as Data).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    @MainActor
    func testTwentySixthDocumentPaywallPurchasesRestoreAndExpiry() throws {
        continueAfterFailure = false
        let app = launch(["-PaperloftStoreMock", "Free", "-PaperloftQuotaUsed", "25"]); defer { app.terminate() }
        // Import one real document: this month's 25 automatic reads are already used.
        XCTAssertTrue(app.buttons["inbox.import"].waitForExistence(timeout: 10)); app.buttons["inbox.import"].click()
        app.typeKey("g", modifierFlags: [.command, .shift])
        let location = app.textFields.firstMatch
        XCTAssertTrue(location.waitForExistence(timeout: 10))
        location.typeText(try receiptPDF().path); location.typeKey(.return, modifierFlags: [])
        let open = app.windows["open-panel"].buttons["OKButton"]
        XCTAssertTrue(open.waitForExistence(timeout: 10)); open.click()

        let buy = app.buttons["paywall.buy"], headline = app.staticTexts["paywall.headline"]
        XCTAssertTrue(buy.waitForExistence(timeout: 20), "the paywall appears at the 26th document")
        XCTAssertEqual(text(headline), "This month's 25 automatic reads are used", "it says why it opened")
        XCTAssertEqual(buy.label, "Start Free Trial", "Yearly is preselected; one prominent buy button")
        XCTAssertTrue(lifetimeChoice(app).exists)
        XCTAssertTrue(app.buttons["paywall.restore"].exists, "Restore Purchases is always visible")
        XCTAssertFalse(app.buttons["paywall.close"].exists, "Not Now is the only way out, as a sheet's cancel button")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Paywall at document 26"; shot.lifetime = .keepAlways; add(shot)
        // Not Now: the document waits, with Fill In Details and upgrade offered.
        app.buttons["paywall.continue"].click()
        XCTAssertTrue(app.buttons["inbox.enterManually"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Limit reached"].exists)

        // Buy yearly: Pro is active and the paused document is read automatically.
        app.buttons["inbox.upgrade"].click()
        XCTAssertTrue(buy.waitForExistence(timeout: 10)); buy.click()
        XCTAssertTrue(app.staticTexts["You have Paperloft Pro"].waitForExistence(timeout: 10))
        XCTAssertTrue(text(app.staticTexts["paywall.planSummary"]).hasPrefix("Your free trial ends on"), text(app.staticTexts["paywall.planSummary"]))
        XCTAssertFalse(buy.exists, "Pro shows its own content, not the offer")
        app.buttons["paywall.continue"].click()
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 20), "buying Pro resumes reading")
        XCTAssertFalse(app.staticTexts["Limit reached"].exists)

        // Settings shows Pro, and Manage Pro… opens the same sheet with Restore.
        app.typeKey(",", modifierFlags: .command)
        let proStatus = app.staticTexts["settings.proStatus"]
        XCTAssertTrue(proStatus.waitForExistence(timeout: 10)); XCTAssertTrue(text(proStatus).hasPrefix("Paperloft Pro is active"), text(proStatus))
        XCTAssertTrue(app.buttons["settings.restore"].exists)
        app.buttons["settings.upgrade"].click()
        let controls = app.descendants(matching: .any)["storeMock.controls"]
        XCTAssertTrue(controls.waitForExistence(timeout: 10))
        // Expiry: the subscription ends and Free returns.
        XCTAssertTrue(app.buttons["storeMock.expire"].waitForExistence(timeout: 5)); app.buttons["storeMock.expire"].click()
        XCTAssertTrue(app.staticTexts["Get Paperloft Pro"].waitForExistence(timeout: 5), "expiry goes back to Free")
        // Lifetime purchase.
        lifetimeChoice(app).click()
        XCTAssertEqual(buy.label, "Buy Lifetime")
        buy.click()
        XCTAssertTrue(app.staticTexts["You have Paperloft Pro"].waitForExistence(timeout: 10))
        XCTAssertEqual(text(app.staticTexts["paywall.planSummary"]), "Lifetime purchase. Pro stays yours.")
        // Restore: clear the local entitlement, then restore it.
        app.buttons["storeMock.clear"].click()
        XCTAssertTrue(buy.waitForExistence(timeout: 5))
        app.buttons["paywall.restore"].click()
        XCTAssertTrue(app.staticTexts["You have Paperloft Pro"].waitForExistence(timeout: 10), "Restore Purchases brings Pro back")
        XCTAssertEqual(text(app.staticTexts["paywall.status"]), "Purchases restored.")
        app.buttons["paywall.continue"].click()
        app.typeKey("w", modifierFlags: .command)
    }

    @MainActor
    func testFreeExportShowsThePaywallInsteadOfTheSheet() throws {
        continueAfterFailure = false
        let app = launch(["-PaperloftStoreMock", "Free"]); defer { app.terminate() }
        app.buttons["sidebar.library"].click()
        let export = app.buttons["library.export"]
        XCTAssertTrue(export.waitForExistence(timeout: 10)); export.click()
        XCTAssertTrue(app.buttons["paywall.buy"].waitForExistence(timeout: 10), "the first export shows the paywall on Free")
        XCTAssertEqual(text(app.staticTexts["paywall.headline"]), "Tax & Accountant Export is part of Pro")
        XCTAssertFalse(app.descendants(matching: .any)["export.period"].exists)
        app.buttons["paywall.continue"].click()
    }
}
