import XCTest

final class ProbeTests: XCTestCase {
    @MainActor private func audit(empty: Bool) throws {
        let app = XCUIApplication()
        if empty { app.launchArguments = ["--empty"] }
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        if !empty { app.textFields.firstMatch.click() }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = empty ? "empty-window" : "standard-controls"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        print("PROBE_TREE \(app.debugDescription)")
        try app.performAccessibilityAudit { issue in
            print("PROBE_ISSUE type=\(issue.auditType) description=\(issue.compactDescription) detail=\(issue.detailedDescription) element=\(issue.element?.debugDescription ?? "nil")")
            return false
        }
    }
    @MainActor func testEmptyWindowAudit() throws { try audit(empty: true) }
    @MainActor func testStandardControlsAudit() throws { try audit(empty: false) }
}
