import XCTest

extension XCTestCase {
    /// Runs the default accessibility audit and fails on every finding except the system-owned
    /// kinds ACCEPTANCE.md AC-13 (owner-approved amendment, 2026-10-01) excuses. Every finding is
    /// attached, labelled, for review.
    @MainActor func auditAccessibility(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit { issue in
            let systemOwned = Self.isSystemOwned(issue)
            let detail = XCTAttachment(string: issue.detailedDescription + "\n" + (issue.element?.debugDescription ?? "No element"))
            detail.name = systemOwned ? "System-owned accessibility finding (AC-13 exception)" : "Accessibility issue details"
            detail.lifetime = .keepAlways
            self.add(detail)
            return systemOwned
        }
    }
    /// Only the three kinds the native probe (Tools/AccessibilityProbe) reproduces in a minimal
    /// non-Paperloft app: findings on Touch Bar items, on the system Emoji & Symbols item, and the
    /// parent/child mismatch XCTest attributes to no element. Anything on an app element fails.
    @MainActor static func isSystemOwned(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        guard let element = issue.element else { return issue.auditType == .parentChild }
        if element.elementType == .touchBar || element.debugDescription.contains("TouchBar") { return true }
        return element.label.localizedCaseInsensitiveContains("emoji & symbols")
    }
}
