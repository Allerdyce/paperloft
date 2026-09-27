import XCTest

final class SettingsProbeTests: XCTestCase {
    @MainActor func testNativeSettingsContrast() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--settings"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Open Settings"].waitForExistence(timeout: 10))
        app.buttons["Open Settings"].click()
        XCTAssertTrue(app.staticTexts["Probe Settings"].waitForExistence(timeout: 10))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "native-settings-overlap"; shot.lifetime = .keepAlways; add(shot)
        print("SETTINGS_TREE \(app.debugDescription)")
        try app.performAccessibilityAudit { issue in
            let text = "\(issue.compactDescription)\n\(issue.element?.debugDescription ?? "nil")"
            print("SETTINGS_ISSUE \(text)")
            let details = XCTAttachment(string: text); details.name = "Native settings issue"
            details.lifetime = .keepAlways; self.add(details)
            return false
        }
    }
}
