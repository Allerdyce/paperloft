import XCTest

/// AC-11: from a first launch, the shipping "Try with Samples" button to a first filed receipt,
/// with only the SPEC 6.7 launch hooks. The onboarding screen is audited too (AC-13).
final class OnboardingSamplesTests: XCTestCase {
    @MainActor private func showMainWindow(_ app: XCUIApplication) {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        if !app.buttons["sidebar.inbox"].waitForExistence(timeout: 5) {
            app.menuBars.menuBarItems["Window"].click()
            app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
        }
        XCTAssertTrue(app.buttons["sidebar.inbox"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testTryWithSamplesToFirstFiledReceipt() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate()
        showMainWindow(app)
        // Debug menu: forget the UI-test library, Inbox and settings, so the next launch is a first launch.
        app.debugMenu("Reset to First Launch and Quit")
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 15))

        let started = Date()
        app.launch(); app.activate(); defer { app.terminate() }
        showMainWindow(app)
        let samples = app.buttons["onboarding.trySamples"]
        XCTAssertTrue(samples.waitForExistence(timeout: 15), "a first launch offers the samples")
        XCTAssertTrue(app.buttons["onboarding.chooseFolder"].exists, "and choosing a library folder")
        let onboarding = XCTAttachment(screenshot: app.windows["main"].screenshot()); onboarding.name = "First launch"; onboarding.lifetime = .keepAlways; add(onboarding)
        try auditAccessibility(app)

        samples.click()
        let vendor = app.textFields["review.vendor"]
        XCTAssertTrue(vendor.waitForExistence(timeout: 30), "a sample opens for review")
        let confirm = app.buttons["review.file"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10)); XCTAssertTrue(confirm.isEnabled)
        confirm.click()
        app.buttons["sidebar.library"].click()
        XCTAssertTrue(app.staticTexts["1 receipt"].waitForExistence(timeout: 15), "the first receipt is filed")
        XCTAssertLessThan(Date().timeIntervalSince(started), 60, "first launch to a filed receipt in under a minute")
    }
}
