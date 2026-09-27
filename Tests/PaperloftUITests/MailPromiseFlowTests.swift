import AppKit
import XCTest

final class MailPromiseFlowTests: XCTestCase {
    @MainActor private func freshApp() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate()
        for running in NSWorkspace.shared.runningApplications where running.bundleIdentifier == "app.paperloft.receipts" {
            print("MAIL_RUNNING_APP pid=\(running.processIdentifier) bundle=\(running.bundleURL?.path ?? "nil") executable=\(running.executableURL?.path ?? "nil")")
        }
        let launched = app.buttons["toolbar.settings"].waitForExistence(timeout: 15)
        if !launched { print("LAUNCH_FAILURE_TREE \(app.debugDescription)") }
        XCTAssertTrue(launched)
        app.buttons["toolbar.settings"].click()
        let fresh = app.buttons["settings.newSampleLibrary"]
        XCTAssertTrue(fresh.waitForExistence(timeout: 10)); fresh.click()
        app.typeKey("w", modifierFlags: .command)
        app.buttons["sidebar.inbox"].click()
        XCTAssertTrue(app.buttons["inbox.import"].waitForExistence(timeout: 10))
        return app
    }
    @MainActor func testWindowMenuReopensWindowlessAppDiagnostic() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        app.menuBarItems["Window"].click()
        app.menuBarItems["Window"].menuItems["Paperloft Receipts"].click()
        let shown = app.buttons["toolbar.settings"].waitForExistence(timeout: 15)
        print("WINDOW_MENU_DIAGNOSTIC \(app.debugDescription)")
        XCTAssertTrue(shown)
    }
    @MainActor func testWindowMenuPrimedMenuBarOpenInboxDiagnostic() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        for running in NSWorkspace.shared.runningApplications where running.bundleIdentifier == "app.paperloft.receipts" {
            print("PRIMED_MAIL_RUNNING_APP pid=\(running.processIdentifier) bundle=\(running.bundleURL?.path ?? "nil") executable=\(running.executableURL?.path ?? "nil")")
        }
        // This diagnostic deliberately isolates the menu-bar action from launch restoration.
        app.menuBarItems["Window"].click()
        app.menuBarItems["Window"].menuItems["Paperloft Receipts"].click()
        XCTAssertTrue(app.buttons["toolbar.settings"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.windows["main"].exists)
        app.buttons["sidebar.library"].click()
        app.typeKey("w", modifierFlags: .command)
        XCTAssertFalse(app.windows["main"].exists)
        let status = app.descendants(matching: .any).matching(identifier: "menubar.status").firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 10)); status.click()
        let open = app.buttons["menubar.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10)); open.click()
        let reopened = app.windows["main"].waitForExistence(timeout: 10)
        print("PRIMED_REOPEN_TREE \(app.debugDescription)")
        XCTAssertTrue(reopened)
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
    @MainActor func testWindowMenuPrimedNativePromiseDragDiagnostic() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        app.menuBarItems["Window"].click()
        app.menuBarItems["Window"].menuItems["Paperloft Receipts"].click()
        XCTAssertTrue(app.buttons["toolbar.settings"].waitForExistence(timeout: 15))
        app.buttons["toolbar.settings"].click()
        XCTAssertTrue(app.buttons["settings.newSampleLibrary"].waitForExistence(timeout: 10))
        app.buttons["settings.newSampleLibrary"].click()
        app.typeKey("w", modifierFlags: .command)
        app.buttons["sidebar.inbox"].click()
        XCTAssertTrue(app.buttons["inbox.import"].waitForExistence(timeout: 10))
        let email = try XCTUnwrap(Bundle(for: MailPromiseFlowTests.self).url(forResource: "mail-receipt", withExtension: "eml"))
        let original = try Data(contentsOf: email)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = XCUIApplication(url: repo.appendingPathComponent("build/MailPromiseSource.app"))
        source.launchArguments = [email.path]
        let main = app.windows["main"]
        XCTAssertTrue(main.exists)
        let recipientFrame = main.frame
        let recipientPoint = CGPoint(x: recipientFrame.minX + recipientFrame.width * 0.75, y: recipientFrame.midY)
        source.launch(); defer { source.terminate() }
        for running in NSWorkspace.shared.runningApplications where ["app.paperloft.receipts", "app.paperloft.synthetic-mail-source"].contains(running.bundleIdentifier ?? "") {
            print("PROMISE_DIAGNOSTIC_PROCESS pid=\(running.processIdentifier) bundle=\(running.bundleURL?.path ?? "nil") executable=\(running.executableURL?.path ?? "nil")")
        }
        let sourceWindow = source.windows.firstMatch
        XCTAssertTrue(sourceWindow.waitForExistence(timeout: 10))
        source.activate()
        let dragSource = source.groups["synthetic.promise.dragSource"]
        XCTAssertTrue(dragSource.waitForExistence(timeout: 10))
        XCTAssertTrue(dragSource.isHittable)
        print("PROMISE_SOURCE_BEFORE \(source.debugDescription)")
        let start = dragSource.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let startPoint = start.screenPoint
        let destination = start.withOffset(CGVector(dx: recipientPoint.x - startPoint.x, dy: recipientPoint.y - startPoint.y))
        print("PROMISE_GESTURE start=\(startPoint) destination=\(recipientPoint) coordinateOwner=source")
        start.press(forDuration: 0.5, thenDragTo: destination, withVelocity: .slow, thenHoldForDuration: 0.5)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "native-promise-drag-result"; shot.lifetime = .keepAlways; add(shot)
        print("PROMISE_SOURCE_TREE \(source.debugDescription)")
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 45))
        XCTAssertTrue(app.scrollViews["review.importNotices"].exists)
        print("PROMISE_DELIVERY_TREE \(source.debugDescription)")
        XCTAssertTrue(source.windows.containing(NSPredicate(format: "title CONTAINS %@", "PROMISE_DELIVERED")).firstMatch.exists)
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
        let reopened = app.windows["main"].waitForExistence(timeout: 10)
        if !reopened { print("REOPEN_FAILURE_TREE \(app.debugDescription)") }
        XCTAssertTrue(reopened)
        XCTAssertTrue(app.buttons["inbox.import"].waitForExistence(timeout: 10))
    }
}
