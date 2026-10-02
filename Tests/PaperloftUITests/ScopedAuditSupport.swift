import XCTest

extension XCTestCase {
    /// Audits a sheet, window or panel shown in front of the main window. The audit also measures
    /// the windows behind it against whatever now covers them; those screens are audited unobstructed
    /// in CoreFlowTests, so a finding whose path doesn't pass through the screen under test is attached
    /// for review but doesn't fail here. Every finding inside the screen under test fails, except the
    /// system-owned kinds of the AC-13 amendment. `marker` is text from that screen's line in the
    /// element path, such as "Sheet", "Dialog" or "title: 'Paperloft Help'".
    ///
    /// A contrast reading is only valid where the text is drawn: for text partly outside `container`
    /// (clipped at a scroll edge), the audit samples other pixels, so that reading is attached and not
    /// counted. Every other kind of finding on such an element still fails.
    @MainActor func auditAccessibility(_ app: XCUIApplication, screen marker: String, container: XCUIElement) throws {
        let visible = container.frame
        try app.performAccessibilityAudit { issue in
            let description = issue.element?.debugDescription ?? "No element"
            let systemOwned = Self.isSystemOwned(issue)
            let inScreen = issue.element != nil && (description.components(separatedBy: "Path to element").last ?? description).contains(marker)
            let clipped = issue.auditType == .contrast && issue.element.map { !visible.contains($0.frame) } == true
            let detail = XCTAttachment(string: issue.detailedDescription + "\n" + description)
            detail.name = systemOwned ? "System-owned accessibility finding (AC-13 exception)"
                : !inScreen ? "Behind the screen under test (audited unobstructed in CoreFlowTests)"
                : clipped ? "Contrast not measurable: text partly outside the visible area" : "Accessibility issue details"
            detail.lifetime = .keepAlways
            self.add(detail)
            return systemOwned || !inScreen || clipped
        }
    }
}
