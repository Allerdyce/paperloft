import XCTest

/// SPEC 6.8 / AC-18: five 2880 x 1800 screenshots from the real app with sample data, plus the
/// paywall for in-app purchase review. Run on demand; images are attachments named "AppStore-*".
final class AppStoreScreenshotTests: XCTestCase {
    @MainActor private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "system", "-PaperloftWindowSize", "1440x900"] + extra
        app.launch(); app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        if !app.buttons["sidebar.settings"].waitForExistence(timeout: 5) {
            app.menuBars.menuBarItems["Window"].click()
            app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
        }
        XCTAssertTrue(app.buttons["sidebar.settings"].waitForExistence(timeout: 10))
        return app
    }
    @MainActor private func theme(_ name: String, _ app: XCUIApplication, freshLibrary: Bool = false) {
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["settings.newSampleLibrary"].waitForExistence(timeout: 10))
        if freshLibrary { app.buttons["settings.newSampleLibrary"].click() }
        app.radioButtons[name].click()
        app.typeKey("w", modifierFlags: .command)
        sleep(1)
    }
    @MainActor private func shoot(_ name: String, _ app: XCUIApplication) {
        sleep(1)
        let window = app.windows["main"]
        XCTAssertEqual(window.frame.width, 1440, accuracy: 1); XCTAssertEqual(window.frame.height, 900, accuracy: 1)
        let image = XCTAttachment(screenshot: window.screenshot()); image.name = "AppStore-" + name; image.lifetime = .keepAlways; add(image)
    }

    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        continueAfterFailure = false
        let app = launch(["-PaperloftStoreMock", "YES"]); defer { app.terminate() }
        theme("Light", app, freshLibrary: true)
        app.buttons["sidebar.inbox"].click()
        app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        for file in ["01-office.pdf", "02-meal.pdf", "03-travel.pdf", "04-software.pdf", "05-utilities.pdf"] {
            XCTAssertTrue(app.staticTexts[file].waitForExistence(timeout: 60))
        }
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 60))
        // Wait until the model has read every sample, so no row still says Processing.
        let processing = app.buttons["inbox.filter.Processing"]
        let done = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label ENDSWITH ' 0' OR label ENDSWITH ', 0'"), object: processing)
        XCTAssertEqual(XCTWaiter().wait(for: [done], timeout: 180), .completed, "reading finished: \(processing.label)")
        app.staticTexts["02-meal.pdf"].click()
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 10))
        shoot("1-review-light", app)
        theme("Dark", app)
        app.staticTexts["03-travel.pdf"].click()
        shoot("4-review-dark", app)
        theme("Light", app)
        for file in ["01-office.pdf", "02-meal.pdf", "03-travel.pdf", "04-software.pdf", "05-utilities.pdf"] {
            app.staticTexts[file].click()
            XCTAssertTrue(app.buttons["review.file"].waitForExistence(timeout: 10)); app.buttons["review.file"].click()
            XCTAssertTrue(app.staticTexts[file].waitForNonExistence(timeout: 15))
        }
        app.buttons["sidebar.library"].click()
        XCTAssertTrue(app.staticTexts["5 documents"].waitForExistence(timeout: 15))
        app.staticTexts.matching(identifier: "library.merchant").element(boundBy: 1).click()
        shoot("2-library-light", app)
        app.typeKey("e", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.descendants(matching: .any)["export.period"].waitForExistence(timeout: 15))
        shoot("3-export-light", app)
        app.buttons["export.close"].click()
        app.buttons["sidebar.history"].click()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history.undo.'")).firstMatch.waitForExistence(timeout: 10))
        shoot("5-history-light", app)
        theme("System", app)
    }

    @MainActor
    func testCapturePaywallForPurchaseReview() throws {
        continueAfterFailure = false
        let app = launch(["-PaperloftStoreMock", "Free", "-PaperloftScreenshotMode", "YES"]); defer { app.terminate() }
        theme("Light", app, freshLibrary: true)
        app.buttons["sidebar.library"].click()
        app.buttons["library.export"].click()
        XCTAssertTrue(app.buttons["paywall.yearly"].waitForExistence(timeout: 10))
        let image = XCTAttachment(screenshot: app.windows["main"].screenshot()); image.name = "AppStore-iap-review-paywall"; image.lifetime = .keepAlways; add(image)
        app.buttons["paywall.continue"].click()
        theme("System", app)
    }
}
