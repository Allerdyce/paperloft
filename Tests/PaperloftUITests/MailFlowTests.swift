import XCTest

final class MailFlowTests: XCTestCase {
    @MainActor func testReceiptAttachmentSuppressesBodyAndKeepsNoticesAfterRestart() throws {
        try verifyEmailImport(resource: "mail-receipt")
    }
    @MainActor func testHTMLBodyRendersAndRemainsReviewableAfterRestart() throws {
        try verifyEmailImport(resource: "mail-body-only")
    }
    @MainActor private func verifyEmailImport(resource: String) throws {
        continueAfterFailure = false
        let fixture = try XCTUnwrap(Bundle(for: MailFlowTests.self).url(forResource: resource, withExtension: "eml"))
        let original = try Data(contentsOf: fixture)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PaperloftMailFlow-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let email = root.appendingPathComponent(resource + ".eml")
        let template = String(decoding: original, as: UTF8.self)
            .replacingOccurrences(of: #"(?m)^Message-ID:[^\r\n]*[\r\n]+"#, with: "", options: .regularExpression)
        let bytes = Data(("Message-ID: <" + UUID().uuidString + "@example.invalid>\r\n" + template).utf8)
        try bytes.write(to: email)
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate(); defer { app.terminate() }
        XCTAssertTrue(app.buttons["sidebar.settings"].waitForExistence(timeout: 15))
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["settings.newSampleLibrary"].waitForExistence(timeout: 10))
        app.buttons["settings.newSampleLibrary"].click()
        app.typeKey("w", modifierFlags: .command)
        app.buttons["sidebar.inbox"].click()
        importEmail(email, in: app)
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 60))
        // QA-05: rows use the sender's filename (here none, so "Attachment.pdf"), never the staged UUID name.
        let uuidNamed = NSPredicate(format: "value BEGINSWITH 'Attachment-' OR label BEGINSWITH 'Attachment-'")
        XCTAssertFalse(app.staticTexts.matching(uuidNamed).firstMatch.exists, "no Inbox row shows a staged UUID filename")
        if resource == "mail-receipt" { XCTAssertTrue(app.staticTexts["Attachment.pdf"].exists, "the attachment row is readable") }
        let notices = app.descendants(matching: .any)["review.importNotices"].firstMatch
        XCTAssertTrue(notices.waitForExistence(timeout: 10))
        app.buttons["review.importDetailsButton"].click()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "value CONTAINS %@", "original email is unchanged")).firstMatch.exists)
        app.terminate(); app.launch(); app.activate()
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.descendants(matching: .any)["review.importNotices"].firstMatch.exists)
        app.buttons["review.setAside"].click()
        XCTAssertTrue(app.buttons["inbox.import"].waitForExistence(timeout: 30), "One email should produce one selected receipt")
        XCTAssertFalse(app.textFields["review.vendor"].exists)
        app.buttons["sidebar.library"].click()
        XCTAssertTrue(app.staticTexts["0 documents"].waitForExistence(timeout: 10), "Email-derived documents must remain in review")
        // Same message remains a duplicate after the original review is removed,
        // and after another app restart. Content changes do not evade Message-ID.
        app.buttons["sidebar.inbox"].click()
        try (bytes + Data("\r\n".utf8)).write(to: email)
        importEmail(email, in: app)
        let duplicate = app.staticTexts.containing(NSPredicate(format: "value == %@", "Email already imported")).firstMatch
        XCTAssertTrue(duplicate.waitForExistence(timeout: 30))
        XCTAssertFalse(app.textFields["review.vendor"].exists)
        app.terminate(); app.launch(); app.activate()
        XCTAssertTrue(duplicate.waitForExistence(timeout: 30))
        app.buttons["inbox.setAsideError"].click()
        XCTAssertTrue(app.buttons["inbox.import"].waitForExistence(timeout: 10))
        XCTAssertEqual(try Data(contentsOf: email), bytes + Data("\r\n".utf8))
        XCTAssertEqual(try Data(contentsOf: fixture), original)
    }
    @MainActor private func importEmail(_ email: URL, in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["inbox.import"].waitForExistence(timeout: 10))
        app.buttons["inbox.import"].click()
        // Exercise the real file-selection grant, not an import test hook.
        app.typeKey("g", modifierFlags: [.command, .shift])
        let location = app.textFields.firstMatch
        XCTAssertTrue(location.waitForExistence(timeout: 10))
        location.typeText(email.path); location.typeKey(.return, modifierFlags: [])
        let open = app.windows["open-panel"].buttons["OKButton"]
        XCTAssertTrue(open.waitForExistence(timeout: 10)); open.click()
    }

}
