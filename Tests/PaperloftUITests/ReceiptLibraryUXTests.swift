import XCTest

final class ReceiptLibraryUXTests: XCTestCase {
    @MainActor
    func testAppearanceChoicePersists() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        func settings() {
            if !app.buttons["toolbar.settings"].waitForExistence(timeout: 3) {
                app.menuBars.menuBarItems["Window"].click()
                app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
            }
            app.buttons["toolbar.settings"].click()
            XCTAssertTrue(app.radioButtons["Light"].waitForExistence(timeout: 10))
        }
        settings()
        app.radioButtons["Light"].click()
        XCTAssertEqual((app.radioButtons["Light"].value as? NSNumber)?.intValue, 1)
        app.typeKey("w", modifierFlags: .command)
        let light = XCTAttachment(screenshot: app.screenshot()); light.name = "Paperloft Light"; light.lifetime = .keepAlways; add(light)
        app.terminate(); app.launch(); app.activate(); settings()
        XCTAssertEqual((app.radioButtons["Light"].value as? NSNumber)?.intValue, 1)
        app.radioButtons["Dark"].click()
        XCTAssertEqual((app.radioButtons["Dark"].value as? NSNumber)?.intValue, 1)
        let dark = XCTAttachment(screenshot: app.screenshot()); dark.name = "Paperloft Dark settings"; dark.lifetime = .keepAlways; add(dark)
        app.radioButtons["System"].click()
        XCTAssertEqual((app.radioButtons["System"].value as? NSNumber)?.intValue, 1)
        app.typeKey("w", modifierFlags: .command)
    }

    @MainActor
    func testOpenDeleteRestartRestoreAndTaxExport() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        func showWindow() {
            if !app.buttons["toolbar.settings"].waitForExistence(timeout: 3) {
                app.menuBars.menuBarItems["Window"].click()
                app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
            }
            XCTAssertTrue(app.buttons["toolbar.settings"].waitForExistence(timeout: 10))
        }
        showWindow()
        app.buttons["toolbar.settings"].click()
        let fresh = app.buttons["settings.newSampleLibrary"]
        XCTAssertTrue(fresh.waitForExistence(timeout: 10)); fresh.click()
        app.typeKey("w", modifierFlags: .command)
        app.buttons["sidebar.inbox"].click()
        XCTAssertTrue(app.buttons["inbox.samples"].waitForExistence(timeout: 10))
        app.buttons["inbox.samples"].click()
        let vendor = app.textFields["review.vendor"]
        XCTAssertTrue(vendor.waitForExistence(timeout: 60))
        XCTAssertTrue(app.staticTexts["Ready to review"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["inbox.readyCount"].exists)
        vendor.click(); vendor.typeKey("a", modifierFlags: .command); vendor.typeText("LibraryUXReceipt")
        app.buttons["review.file"].click()
        app.buttons["sidebar.library"].click()
        XCTAssertTrue(app.staticTexts["1 documents"].waitForExistence(timeout: 15))
        let receipt = app.staticTexts["LibraryUXReceipt"].firstMatch
        XCTAssertTrue(receipt.waitForExistence(timeout: 10)); receipt.doubleClick()
        // Quick Look creates a separate native preview window.
        XCTAssertTrue(app.windows["Quick Look"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.windows["Quick Look"].staticTexts["Maple Desk Supply"].waitForExistence(timeout: 10))
        app.typeKey(.escape, modifierFlags: [])
        receipt.click()
        app.buttons["library.delete"].click()
        let confirm = app.buttons["library.confirmDelete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.click()
        XCTAssertTrue(app.staticTexts["0 documents"].waitForExistence(timeout: 15))
        app.terminate(); app.launch(); app.activate(); showWindow()
        app.buttons["sidebar.library"].click()
        XCTAssertTrue(app.staticTexts["0 documents"].waitForExistence(timeout: 15))
        app.buttons["library.deleted"].click()
        XCTAssertTrue(app.staticTexts["LibraryUXReceipt"].firstMatch.waitForExistence(timeout: 10))
        let restore = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "deleted.restore.")).firstMatch
        XCTAssertTrue(restore.waitForExistence(timeout: 5)); restore.click()
        XCTAssertTrue(app.staticTexts["No deleted receipts"].waitForExistence(timeout: 15))
        app.buttons["deleted.done"].click()
        XCTAssertTrue(app.staticTexts["1 documents"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["LibraryUXReceipt"].firstMatch.exists)
        let library = XCTAttachment(screenshot: app.screenshot()); library.name = "Receipt library actions"; library.lifetime = .keepAlways; add(library)
        app.buttons["library.export"].click()
        XCTAssertTrue(app.staticTexts["Tax & Accountant Export"].waitForExistence(timeout: 10))
        let export = XCTAttachment(screenshot: app.screenshot()); export.name = "Tax accountant export"; export.lifetime = .keepAlways; add(export)
    }
}
