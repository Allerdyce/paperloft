import XCTest

/// The menu bar extra (SPEC: drop target plus inbox count) in light and dark, with screenshots of
/// its window only, so design reviews can see it without the rest of the screen.
final class MenuBarExtraTests: XCTestCase {
    @MainActor private func theme(_ name: String, _ app: XCUIApplication) {
        app.typeKey(",", modifierFlags: .command)
        let picker = app.radioGroups["settings.appearance"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.radioButtons[name].click()
        app.typeKey("w", modifierFlags: .command)
    }
    @MainActor private func openExtra(_ app: XCUIApplication) -> XCUIElement {
        let status = app.descendants(matching: .any).matching(identifier: "menubar.status").firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 10)); status.click()
        let open = app.buttons["menubar.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        return app.dialogs.containing(.button, identifier: "menubar.open").firstMatch
    }

    @MainActor
    func testMenuBarExtraShowsCountDropTargetAndActions() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.buttons["sidebar.inbox"].waitForExistence(timeout: 15))
        for appearance in ["Light", "Dark"] {
            theme(appearance, app)
            let window = openExtra(app)
            XCTAssertTrue(app.descendants(matching: .any)["menubar.drop"].exists, "a drop target")
            let count = app.staticTexts["menubar.count"]
            let text = count.label.isEmpty ? (count.value as? String ?? "") : count.label
            XCTAssertTrue(text == "Your Inbox is empty" || text.hasSuffix("waiting in your Inbox"), text)
            XCTAssertTrue(app.buttons["menubar.import"].exists)
            let shot = XCTAttachment(screenshot: window.screenshot()); shot.name = "Menu bar extra \(appearance)"; shot.lifetime = .keepAlways; add(shot)
            app.typeKey(.escape, modifierFlags: [])
        }
        theme("System", app)
    }
}
