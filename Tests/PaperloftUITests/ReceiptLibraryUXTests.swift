import XCTest

final class ReceiptLibraryUXTests: XCTestCase {
    @MainActor
    func testSidebarSettingsStaysInMainWindow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        XCTAssertTrue(app.buttons["sidebar.settings"].waitForExistence(timeout: 10))
        let count = app.windows.count
        app.buttons["sidebar.settings"].click()
        XCTAssertTrue(app.windows["main"].buttons["settings.chooseFolder"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.windows.count, count)
        XCTAssertEqual(app.staticTexts["content.title"].value as? String, "Settings")
        app.buttons["sidebar.library"].click()
        XCTAssertTrue(app.textFields["library.search"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["settings.chooseFolder"].exists)
    }

    @MainActor
    func testInboxStatusFiltersKeepReviewSelectionConsistent() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        if !app.buttons["sidebar.settings"].waitForExistence(timeout: 3) {
            app.menuBars.menuBarItems["Window"].click()
            app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
        }
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["settings.newSampleLibrary"].waitForExistence(timeout: 10))
        app.buttons["settings.newSampleLibrary"].click(); app.typeKey("w", modifierFlags: .command)
        app.buttons["sidebar.inbox"].click()
        XCTAssertTrue(app.buttons["inbox.import"].waitForExistence(timeout: 10)); app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 60))
        app.buttons["inbox.filter.Processing"].click()
        XCTAssertTrue(app.staticTexts["No receipts in this view"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["review.file"].exists)
        app.buttons["inbox.filter.Ready"].click()
        XCTAssertTrue(app.staticTexts["No receipts in this view"].waitForExistence(timeout: 10))
        app.buttons["inbox.filter.Issues"].click()
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["review.file"].isEnabled)
        XCTAssertTrue(app.staticTexts["Issue"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Why this needs checking"].exists)
        XCTAssertTrue(app.staticTexts["Verify total against receipt."].exists)
        XCTAssertFalse(app.staticTexts["Waiting"].exists)
        XCTAssertEqual(app.buttons["review.file"].label, "Confirm")
        XCTAssertEqual(app.buttons["review.setAside"].label, "Remove")
        XCTAssertTrue(app.buttons["inbox.addMore"].isHittable)
        XCTAssertEqual(app.buttons["inbox.paste"].label, "Paste")
        XCTAssertEqual(app.buttons["inbox.addMore"].label, "Import")
        XCTAssertEqual(app.buttons["inbox.paste"].frame.midY, app.buttons["inbox.filter.All"].frame.midY, accuracy: 2)
        XCTAssertEqual(app.buttons["inbox.addMore"].frame.midY, app.buttons["inbox.paste"].frame.midY, accuracy: 2)
        XCTAssertGreaterThan(app.buttons["inbox.paste"].frame.minX, app.buttons["inbox.addMore"].frame.maxX)
        XCTAssertTrue(app.buttons["inbox.paste"].isHittable)
        XCTAssertFalse(app.buttons["inbox.samples"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["inbox.readyCount"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["inbox.processingCount"].exists)
        app.buttons["review.expandPreview"].click()
        XCTAssertTrue(app.windows["Quick Look"].waitForExistence(timeout: 10))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(app.textFields["review.total"].exists)
        app.buttons["review.openPreview"].click()
        XCTAssertTrue(app.windows["Quick Look"].waitForExistence(timeout: 10))
        app.typeKey(.escape, modifierFlags: [])
        let dateBeforeCalendar = app.textFields["review.date"].value as? String
        app.buttons["review.chooseDate"].click()
        XCTAssertTrue(app.buttons["review.useDate"].waitForExistence(timeout: 5))
        app.buttons["Next month"].click()
        app.buttons["Today"].click()
        app.buttons["Cancel"].click()
        XCTAssertEqual(app.textFields["review.date"].value as? String, dateBeforeCalendar)
        app.buttons["review.chooseDate"].click()
        XCTAssertTrue(app.buttons["review.useDate"].waitForExistence(timeout: 5))
        app.buttons["Next month"].click()
        app.buttons["Previous month"].click()
        let calendarShot = XCTAttachment(screenshot: app.windows["main"].screenshot()); calendarShot.name = "Compact calendar"; calendarShot.lifetime = .keepAlways; add(calendarShot)
        app.buttons["review.useDate"].click()
        let total = app.textFields["review.total"]
        let originalTotal = total.value as! String
        total.click(); total.typeKey("a", modifierFlags: .command); total.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["Enter the total shown on the receipt."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["review.file"].isEnabled)
        total.typeText(originalTotal)
        XCTAssertTrue(app.buttons["review.file"].isEnabled)
        let ready = XCTAttachment(screenshot: app.windows["main"].screenshot()); ready.name = "Inbox status filters"; ready.lifetime = .keepAlways; add(ready)
        app.buttons["review.file"].click()
        app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        XCTAssertTrue(app.buttons["inbox.filter.Duplicates"].waitForExistence(timeout: 10))
        app.buttons["inbox.filter.Duplicates"].click()
        XCTAssertTrue(app.staticTexts["review.duplicate"].waitForExistence(timeout: 60))
        XCTAssertFalse(app.buttons["review.file"].isEnabled)
        app.buttons["inbox.filter.Issues"].click()
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 10))
        app.buttons["inbox.filter.All"].click()
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 10))
        let checks = app.checkBoxes.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inbox.select."))
        XCTAssertGreaterThanOrEqual(checks.count, 2)
        let firstID = checks.element(boundBy: 0).identifier
        let secondID = checks.element(boundBy: 1).identifier
        app.checkBoxes[firstID].click(); app.checkBoxes[secondID].click()
        XCTAssertTrue(app.staticTexts["2 selected"].exists)
        app.buttons["inbox.removeSelected"].click()
        XCTAssertFalse(app.checkBoxes[firstID].exists)
        XCTAssertFalse(app.checkBoxes[secondID].exists)
        app.buttons["inbox.selectAll"].click(); app.buttons["inbox.removeSelected"].click()
        XCTAssertTrue(app.buttons["inbox.import"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["inbox.paste"].isHittable)
        XCTAssertFalse(app.buttons["inbox.samples"].exists)
        let empty = XCTAttachment(screenshot: app.windows["main"].screenshot())
        empty.name = "Empty Inbox entry cards"; empty.lifetime = .keepAlways; add(empty)
    }

    @MainActor
    func testLibraryVisualReferenceAndFilters() throws {
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
        app.buttons["settings.newSampleLibrary"].click()
        app.radioButtons["Light"].click()
        app.typeKey("w", modifierFlags: .command)
        app.buttons["sidebar.inbox"].click()
        XCTAssertTrue(app.buttons["inbox.import"].waitForExistence(timeout: 10)); app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        for file in ["01-office.pdf", "02-meal.pdf", "03-travel.pdf", "04-software.pdf", "05-utilities.pdf"] {
            XCTAssertTrue(app.staticTexts[file].waitForExistence(timeout: 30)); app.staticTexts[file].click()
            XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 30))
            let fileButton = app.buttons["review.file"]
            XCTAssertTrue(fileButton.isEnabled); fileButton.click()
            XCTAssertTrue(app.staticTexts[file].waitForNonExistence(timeout: 15))
        }
        app.buttons["sidebar.library"].click()
        XCTAssertTrue(app.staticTexts["5 documents"].waitForExistence(timeout: 15))
        app.staticTexts["Meadow Internet"].firstMatch.click()
        let light = XCTAttachment(screenshot: app.windows["main"].screenshot()); light.name = "Redesigned library Light five receipts"; light.lifetime = .keepAlways; add(light)
        let search = app.textFields["library.search"]
        search.click(); search.typeText("Juniper")
        XCTAssertTrue(app.staticTexts["1 documents"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Juniper Cafe"].firstMatch.exists)
        search.typeKey("a", modifierFlags: .command); search.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["5 documents"].waitForExistence(timeout: 10))
        let kind = app.descendants(matching: .any)["library.kind"]
        XCTAssertTrue(kind.exists); kind.click()
        app.menuItems["Invoice"].click()
        XCTAssertTrue(app.staticTexts["0 documents"].waitForExistence(timeout: 10))
        kind.click(); app.menuItems["All types"].click()
        XCTAssertTrue(app.staticTexts["5 documents"].waitForExistence(timeout: 10))
        let view = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "library.view.")).firstMatch
        XCTAssertTrue(view.exists); view.click()
        XCTAssertTrue(app.windows["Quick Look"].waitForExistence(timeout: 10)); app.typeKey(.escape, modifierFlags: [])
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.radioButtons["Dark"].waitForExistence(timeout: 10)); app.radioButtons["Dark"].click()
        app.typeKey("w", modifierFlags: .command)
        let dark = XCTAttachment(screenshot: app.screenshot()); dark.name = "Redesigned library Dark five receipts"; dark.lifetime = .keepAlways; add(dark)
        app.typeKey(",", modifierFlags: .command); app.radioButtons["System"].click(); app.typeKey("w", modifierFlags: .command)
    }

    @MainActor
    func testAppearanceChoicePersists() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        func settings() {
            if !app.buttons["sidebar.settings"].waitForExistence(timeout: 3) {
                app.menuBars.menuBarItems["Window"].click()
                app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
            }
            app.typeKey(",", modifierFlags: .command)
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
            if !app.buttons["sidebar.settings"].waitForExistence(timeout: 3) {
                app.menuBars.menuBarItems["Window"].click()
                app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
            }
            XCTAssertTrue(app.buttons["sidebar.settings"].waitForExistence(timeout: 10))
        }
        showWindow()
        app.typeKey(",", modifierFlags: .command)
        let fresh = app.buttons["settings.newSampleLibrary"]
        XCTAssertTrue(fresh.waitForExistence(timeout: 10)); fresh.click()
        app.typeKey("w", modifierFlags: .command)
        app.buttons["sidebar.inbox"].click()
        XCTAssertTrue(app.buttons["inbox.import"].waitForExistence(timeout: 10))
        app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        let vendor = app.textFields["review.vendor"]
        XCTAssertTrue(vendor.waitForExistence(timeout: 60))
        XCTAssertTrue(app.staticTexts["Issue"].firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any)["inbox.readyCount"].exists)
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
