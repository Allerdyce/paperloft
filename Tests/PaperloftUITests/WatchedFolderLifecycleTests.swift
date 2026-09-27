import XCTest
import AppKit
import CoreGraphics

/// Native panel/bookmark path; only existing documented sample/model/Store mock flags.
final class WatchedFolderLifecycleTests: XCTestCase {
    @MainActor
    private func launch(_ app: XCUIApplication) {
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub", "-PaperloftStoreMock", "YES"]
        app.launch(); app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        // macOS restoration may leave no window. Exercise the public Window command;
        // this test makes no claim that launch itself restores a visible window.
        if !app.buttons["sidebar.settings"].waitForExistence(timeout: 3) {
            app.menuBars.menuBarItems["Window"].click()
            app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
        }
        XCTAssertTrue(app.buttons["sidebar.settings"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testNativeFolderBookmarkPauseResumeAndRelaunch() throws {
        continueAfterFailure = false
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("WatchedNative-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let pdf = NSMutableData()
        var page = CGRect(x: 0, y: 0, width: 400, height: 400)
        let consumer = try XCTUnwrap(CGDataConsumer(data: pdf))
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &page, nil))
        context.beginPDFPage(nil)
        let graphics = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
        ("Synthetic Stationery\n2026-07-12\nTotal USD 12.50" as NSString).draw(at: NSPoint(x: 30, y: 300), withAttributes: [.font: NSFont.systemFont(ofSize: 18)])
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage(); context.closePDF()
        let original = pdf as Data
        let firstName = "Watched first " + UUID().uuidString + ".pdf"
        let secondName = "Watched second " + UUID().uuidString + ".pdf"
        try original.write(to: folder.appendingPathComponent(firstName))
        let app = XCUIApplication()
        defer { app.terminate() }
        launch(app)
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["settings.newSampleLibrary"].waitForExistence(timeout: 10))
        if app.buttons["settings.disableWatchedFolder"].exists {
            app.buttons["settings.disableWatchedFolder"].click()
        }
        app.buttons["settings.newSampleLibrary"].click()
        let choose = app.buttons["settings.chooseWatchedFolder"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: choose)], timeout: 10), .completed); choose.click()
        app.typeKey("g", modifierFlags: [.command, .shift])
        let location = app.textFields.firstMatch
        XCTAssertTrue(location.waitForExistence(timeout: 5))
        location.typeText(folder.path)
        app.typeKey(.return, modifierFlags: [])
        let open = app.windows["open-panel"].buttons["OKButton"]
        XCTAssertTrue(open.waitForExistence(timeout: 5)); open.click()
        XCTAssertTrue(app.buttons["settings.disableWatchedFolder"].waitForExistence(timeout: 10))
        app.typeKey("w", modifierFlags: .command)
        app.buttons["sidebar.inbox"].click()
        XCTAssertTrue(app.staticTexts[firstName].firstMatch.waitForExistence(timeout: 30))
        app.staticTexts[firstName].firstMatch.click()
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 30))
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent(firstName)), original)
        let received = XCTAttachment(screenshot: app.screenshot())
        received.name = "Watched native folder copied to review"; received.lifetime = .keepAlways; add(received)

        app.typeKey(",", modifierFlags: .command)
        app.buttons["settings.disableWatchedFolder"].click()
        XCTAssertTrue(app.buttons["settings.enableWatchedFolder"].waitForExistence(timeout: 10))
        try original.write(to: folder.appendingPathComponent(secondName))
        app.typeKey("w", modifierFlags: .command)
        XCTAssertFalse(app.staticTexts[secondName].firstMatch.waitForExistence(timeout: 8), "Disabled watcher must not import")
        app.typeKey(",", modifierFlags: .command)
        app.buttons["settings.enableWatchedFolder"].click()
        XCTAssertTrue(app.buttons["settings.disableWatchedFolder"].waitForExistence(timeout: 10))
        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts[secondName].firstMatch.waitForExistence(timeout: 30))
        app.terminate(); launch(app)
        XCTAssertTrue(app.staticTexts[firstName].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts[secondName].firstMatch.exists)
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["settings.disableWatchedFolder"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@ OR label == %@", folder.path, folder.path)).firstMatch.exists, "Bookmark must resolve after restart")
        let restored = XCTAttachment(screenshot: app.screenshot())
        restored.name = "Watched bookmark restored after restart"; restored.lifetime = .keepAlways; add(restored)
        app.typeKey("w", modifierFlags: .command)
        let thirdName = "Watched restart " + UUID().uuidString + ".pdf"
        try original.write(to: folder.appendingPathComponent(thirdName))
        XCTAssertTrue(app.staticTexts[thirdName].firstMatch.waitForExistence(timeout: 30), "Restored bookmark must support new intake without reselecting the folder")
        // macOS may reopen the main window on XCTest launch. Close it if restored,
        // then verify continued intake with only the menu extra. This does not
        // prove that no Window task executed during launch.
        app.typeKey("w", modifierFlags: .command)
        XCTAssertFalse(app.windows["main"].exists)
        app.terminate(); app.launch(); app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        if app.windows["main"].exists { app.typeKey("w", modifierFlags: .command) }
        XCTAssertFalse(app.windows["main"].exists)
        let fourthName = "Watched background " + UUID().uuidString + ".pdf"
        try original.write(to: folder.appendingPathComponent(fourthName))
        let status = app.descendants(matching: .any).matching(identifier: "menubar.status").firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 10)); status.click()
        XCTAssertTrue(app.staticTexts["4 documents in your inbox"].waitForExistence(timeout: 30), "Watched intake must continue while the main window is closed")
        XCTAssertFalse(app.windows["main"].exists)
        let background = XCTAttachment(screenshot: app.screenshot())
        background.name = "Watched intake after restart with main closed"; background.lifetime = .keepAlways; add(background)
        app.typeKey(.escape, modifierFlags: [])
        app.menuBars.menuBarItems["Window"].click()
        app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
        XCTAssertTrue(app.staticTexts[fourthName].firstMatch.waitForExistence(timeout: 10))
        app.typeKey(",", modifierFlags: .command)
        app.buttons["settings.disableWatchedFolder"].click()
        XCTAssertTrue(app.buttons["settings.enableWatchedFolder"].waitForExistence(timeout: 10))
        app.typeKey("w", modifierFlags: .command)
        XCTAssertEqual(app.staticTexts.matching(identifier: firstName).count, 1)
        XCTAssertEqual(app.staticTexts.matching(identifier: secondName).count, 1)
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent(secondName)), original)
    }
}
