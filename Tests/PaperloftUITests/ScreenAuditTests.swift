import XCTest

/// AC-13 (P6): the accessibility audit on screens CoreFlowTests doesn't cover: Help, the menu bar
/// extra, the export sheet and the paywall. (The long Settings page in the main window scrolls
/// past the window, and the audit measures off-screen text against other pixels; see HANDOFF.md.)
final class ScreenAuditTests: XCTestCase {
    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub", "-PaperloftStoreMock", "YES"]
        app.launch(); app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        if !app.buttons["sidebar.settings"].waitForExistence(timeout: 5) {
            app.menuBars.menuBarItems["Window"].click()
            app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
        }
        XCTAssertTrue(app.buttons["sidebar.settings"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    func testHelpAndMenuBarExtra() throws {
        continueAfterFailure = true
        let app = launch(); defer { app.terminate() }
        app.menuBars.menuBarItems["Help"].click()
        app.menuBars.menuBarItems["Help"].menus.menuItems["Paperloft Help"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["help.title"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.5) // let the window finish appearing before measuring contrast
        try auditAccessibility(app, screen: "title: 'Paperloft Help'", container: app.windows["Paperloft Help"])
        app.typeKey("w", modifierFlags: .command)

        let status = app.descendants(matching: .any).matching(identifier: "menubar.status").firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 10)); status.click()
        XCTAssertTrue(app.buttons["menubar.open"].waitForExistence(timeout: 10))
        try auditAccessibility(app, screen: "Dialog", container: app.dialogs.firstMatch)
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testExportSheetAndPaywall() throws {
        continueAfterFailure = true
        let app = launch(); defer { app.terminate() }
        app.makePro()
        app.buttons["sidebar.library"].click()
        // File › Tax & Accountant Export… opens the sheet even before anything is filed.
        app.typeKey("e", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.descendants(matching: .any)["export.period"].waitForExistence(timeout: 10))
        try auditAccessibility(app, screen: "Sheet", container: app.sheets.firstMatch)
        app.buttons["export.close"].click()

        app.returnToFree()
        app.typeKey("e", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.buttons["paywall.buy"].waitForExistence(timeout: 10))
        try auditAccessibility(app, screen: "Sheet", container: app.sheets.firstMatch)
        app.buttons["paywall.continue"].click()
    }
}
