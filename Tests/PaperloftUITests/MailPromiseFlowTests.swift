import XCTest

final class MailPromiseFlowTests: XCTestCase {
    @MainActor private func freshApp() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate()
        XCTAssertTrue(app.buttons["toolbar.settings"].waitForExistence(timeout: 15))
        app.buttons["toolbar.settings"].click()
        let fresh = app.buttons["settings.newSampleLibrary"]
        XCTAssertTrue(fresh.waitForExistence(timeout: 10)); fresh.click()
        app.typeKey("w", modifierFlags: .command)
        app.buttons["sidebar.inbox"].click()
        XCTAssertTrue(app.buttons["inbox.import"].waitForExistence(timeout: 10))
        return app
    }
    @MainActor func testNativePromisedEmailDragReachesReview() throws {
        continueAfterFailure = false
        let app = try freshApp(); defer { app.terminate() }
        let email = try XCTUnwrap(Bundle(for: MailPromiseFlowTests.self).url(forResource: "mail-receipt", withExtension: "eml"))
        let original = try Data(contentsOf: email)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = XCUIApplication(url: repo.appendingPathComponent("build/MailPromiseSource.app"))
        source.launchArguments = [email.path]
        source.launch(); defer { source.terminate() }
        let sourceWindow = source.windows.firstMatch
        XCTAssertTrue(sourceWindow.waitForExistence(timeout: 10))
        let main = app.windows["main"]
        XCTAssertTrue(main.exists)
        let start = sourceWindow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let destination = main.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5))
        start.press(forDuration: 0.5, thenDragTo: destination, withVelocity: .slow, thenHoldForDuration: 0.5)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "native-promise-drag-result"; shot.lifetime = .keepAlways; add(shot)
        print("PROMISE_SOURCE_TREE \(source.debugDescription)")
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 45))
        XCTAssertTrue(app.scrollViews["review.importNotices"].exists)
        app.buttons["review.setAside"].click()
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 30))
        app.buttons["sidebar.library"].click()
        XCTAssertTrue(app.staticTexts["0 documents"].waitForExistence(timeout: 10))
        XCTAssertEqual(try Data(contentsOf: email), original)
    }
    @MainActor func testMenuBarOpenInboxAfterClosingMainWindow() throws {
        continueAfterFailure = false
        let app = try freshApp(); defer { app.terminate() }
        app.buttons["sidebar.library"].click()
        app.typeKey("w", modifierFlags: .command)
        XCTAssertFalse(app.windows["main"].exists)
        print("MENU_BAR_TREE \(app.debugDescription)")
        let status = app.descendants(matching: .any).matching(identifier: "menubar.status").firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 10)); status.click()
        let open = app.buttons["menubar.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10)); open.click()
        XCTAssertTrue(app.windows["main"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["inbox.import"].waitForExistence(timeout: 10))
    }
}
