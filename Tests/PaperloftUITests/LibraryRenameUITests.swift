import XCTest

/// QA-07 in the sandboxed app: a library folder renamed in Finder is followed through its bookmark.
final class LibraryRenameUITests: XCTestCase {
    @MainActor
    func testRenamedLibraryFolderIsFollowedWhenPaperloftBecomesActive() throws {
        continueAfterFailure = false
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("LibraryRename-" + UUID().uuidString, isDirectory: true)
        let folder = base.appendingPathComponent("Receipts", isDirectory: true), renamed = base.appendingPathComponent("Receipts 2026", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        if !app.buttons["sidebar.settings"].waitForExistence(timeout: 3) {
            app.menuBars.menuBarItems["Window"].click()
            app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
        }
        app.typeKey(",", modifierFlags: .command)
        let choose = app.buttons["settings.chooseFolder"]
        XCTAssertTrue(choose.waitForExistence(timeout: 10)); choose.click()
        app.typeKey("g", modifierFlags: [.command, .shift])
        let location = app.textFields.firstMatch
        XCTAssertTrue(location.waitForExistence(timeout: 5))
        location.typeText(folder.path)
        app.typeKey(.return, modifierFlags: [])
        let open = app.windows["open-panel"].buttons["OKButton"]
        XCTAssertTrue(open.waitForExistence(timeout: 5)); open.click()
        let summary = app.descendants(matching: .any)["settings.libraryFolder"]
        func shows(_ url: URL) -> Bool {
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", url.path), object: summary)], timeout: 10) == .completed
        }
        XCTAssertTrue(shows(folder), "the chosen folder is the library")
        app.typeKey("w", modifierFlags: .command)

        // Rename it while Paperloft is open, then come back to Paperloft.
        try FileManager.default.moveItem(at: folder, to: renamed)
        XCUIApplication(bundleIdentifier: "com.apple.finder").activate()
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertTrue(shows(renamed), "Settings follows the renamed folder: \(summary.value as? String ?? "nil")")

        // Leave the shared UI-test profile on a sample library, as other tests expect.
        app.buttons["settings.newSampleLibrary"].click()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Practice library'")).firstMatch.waitForExistence(timeout: 10))
        app.typeKey("w", modifierFlags: .command)
    }
}
