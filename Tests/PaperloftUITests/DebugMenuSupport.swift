import XCTest

/// The Debug menu (Debug and QA builds only) replaces extra launch arguments: SPEC 6.7 lists the
/// only launch hooks, so tests set up store and quota states through these menu commands.
extension XCUIApplication {
    /// Chooses Debug › … › item, e.g. `debugMenu("Mock Store", "Make Pro (Lifetime)")`.
    @MainActor func debugMenu(_ path: String..., file: StaticString = #filePath, line: UInt = #line) {
        let bar = menuBars.menuBarItems["Debug"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "Debug menu", file: file, line: line)
        bar.click()
        var menu = bar.menus.firstMatch
        for (index, title) in path.enumerated() {
            let item = menu.menuItems[title]
            XCTAssertTrue(item.waitForExistence(timeout: 5), "Debug menu item \(title)", file: file, line: line)
            if index < path.count - 1 { item.hover(); menu = item.menus.firstMatch } else { item.click() }
        }
    }
    /// The mock store (`-PaperloftStoreMock YES`) remembers purchases; these set a known state.
    @MainActor func makePro() { debugMenu("Mock Store", "Make Pro (Lifetime)") }
    @MainActor func returnToFree() { debugMenu("Mock Store", "Return to Free") }
}
