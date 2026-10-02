import XCTest

/// Critic r4: the Inbox status chips must tell VoiceOver which one is selected. They stay
/// Paperloft's coloured chips (owner reference design); the selection must be readable without
/// seeing the colour or the checkmark.
final class StatusChipAccessibilityTests: XCTestCase {
    @MainActor
    func testSelectedChipIsExposedToAccessibility() throws {
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
        app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        app.waitForInboxToSettle()
        let all = app.buttons["inbox.filter.All"], ready = app.buttons["inbox.filter.Ready"]
        XCTAssertTrue(all.isSelected, "All starts selected")
        XCTAssertFalse(ready.isSelected)
        ready.click()
        XCTAssertTrue(ready.isSelected, "the clicked chip is selected")
        XCTAssertFalse(all.isSelected)
    }
}
