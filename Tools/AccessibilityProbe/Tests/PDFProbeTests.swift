import XCTest

final class PDFProbeTests: XCTestCase {
    @MainActor private func run(label: Bool) throws {
        let app = XCUIApplication(); app.launchArguments = ["--pdf"]; app.launch()
        XCTAssertTrue(app.buttons["Inspect pages"].waitForExistence(timeout: 10))
        app.buttons[label ? "Label pages" : "Inspect pages"].click()
        print("PDF_REPORT_INITIAL \(app.staticTexts["pdf.report"].value ?? "nil")")
        if label { app.buttons["Inspect pages"].click() }
        print("PDF_REPORT_PERSISTENCE \(app.staticTexts["pdf.report"].value ?? "nil")")
        print("PDF_TREE \(app.debugDescription)")
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.lifetime = .keepAlways
        attachment.name = label ? "pdf-labeled" : "pdf-baseline"; add(attachment)
        try app.performAccessibilityAudit { issue in
            print("PDF_ISSUE type=\(issue.auditType) description=\(issue.compactDescription) element=\(issue.element?.debugDescription ?? "nil")")
            return false
        }
    }
    @MainActor func testPDFBaseline() throws { try run(label: false) }
    @MainActor func testPDFPublicLabel() throws { try run(label: true) }
}
