import Foundation
import XCTest
import PaperloftKit
import UniformTypeIdentifiers

@MainActor final class IntakeCleanupTests: XCTestCase {
    private let fields = ExtractedFields(kind: "receipt", vendor: "Synthetic shop", date: "2026-09-29", total: "12.00", currency: "USD", category: "Office supplies", confidence: 1, backend: "stub")
    private func workspace() throws -> (URL, UserDefaults, URL, Data) {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/IntakeCleanup/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "app.paperloft.cleanup." + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { try FileManager.default.removeItem(at: root); UserDefaults.standard.removePersistentDomain(forName: suite) }
        let pdf = try MailImport.bodyPDF("Synthetic shop\nTotal USD 12.00")
        let bytes = Data(("Message-ID: <cleanup@example.invalid>\r\nContent-Type: multipart/mixed; boundary=parts\r\n\r\n--parts\r\nContent-Type: application/pdf\r\nContent-Transfer-Encoding: base64\r\nContent-Disposition: attachment\r\n\r\n" + pdf.base64EncodedString() + "\r\n--parts--\r\n").utf8)
        let original = root.appendingPathComponent("Original.eml"); try bytes.write(to: original)
        return (root, defaults, original, bytes)
    }
    private func finish(_ app: AppModel) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while app.processing && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(app.processing)
    }
    private func scratchIsEmpty(_ support: URL) throws -> Bool {
        let folder = support.appendingPathComponent("MailScratch")
        if !FileManager.default.fileExists(atPath: folder.path) { return true }
        return try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty
    }
    func testCommittedEmailReleasesOnlyParentAndAttemptScratchThenRestarts() async throws {
        let (root, defaults, original, bytes) = try workspace(), support = root.appendingPathComponent("support")
        let app = AppModel(support: support, preferences: defaults, extractionBackend: StubBackend(response: fields))
        await app.intake([original]); let parent = try XCTUnwrap(app.items.first?.documentURL)
        try await app.newSampleLibrary(); try await finish(app)
        XCTAssertEqual(app.items.count, 1); XCTAssertEqual(app.items.first?.status, "ready")
        XCTAssertFalse(FileManager.default.fileExists(atPath: parent.path)); XCTAssertTrue(try scratchIsEmpty(support))
        XCTAssertEqual(try Data(contentsOf: original), bytes)
        let child = try XCTUnwrap(app.items.first?.documentURL); XCTAssertTrue(FileManager.default.fileExists(atPath: child.path))
        let reopened = AppModel(support: support, preferences: defaults, extractionBackend: StubBackend(response: fields)); await reopened.start()
        XCTAssertEqual(reopened.items.first?.documentURL, child); XCTAssertFalse(reopened.mailRecoveryNeeded)
    }
    func testSnapshotFailurePreservesOwnedParentForRetryAndOriginal() async throws {
        let (root, defaults, original, bytes) = try workspace(), support = root.appendingPathComponent("support")
        var fail = false
        let app = AppModel(support: support, preferences: defaults, mailSnapshotWriter: { data, url in
            if fail { throw AppIssue("Synthetic snapshot failure") }; try data.write(to: url, options: .atomic)
        }, extractionBackend: StubBackend(response: fields))
        await app.intake([original]); let parent = try XCTUnwrap(app.items.first?.documentURL)
        fail = true; try await app.newSampleLibrary(); try await finish(app)
        XCTAssertTrue(app.mailRecoveryNeeded); XCTAssertEqual(try Data(contentsOf: parent), bytes); XCTAssertTrue(try scratchIsEmpty(support))
        XCTAssertEqual(try Data(contentsOf: original), bytes)
        let reopened = AppModel(support: support, preferences: defaults, extractionBackend: StubBackend(response: fields)); await reopened.start()
        // Startup may resume the parent; its source must survive until that delivery commits.
        try await finish(reopened)
        XCTAssertEqual(reopened.items.first?.status, "ready"); XCTAssertFalse(reopened.mailRecoveryNeeded)
    }
    func testLedgerFailureRetainsParentDespitePublishedChildrenAndRestart() async throws {
        let (root, defaults, original, bytes) = try workspace(), support = root.appendingPathComponent("support")
        let app = AppModel(support: support, preferences: defaults, mailCommit: { _ in throw AppIssue("Synthetic ledger failure") }, extractionBackend: StubBackend(response: fields))
        await app.intake([original]); let parent = try XCTUnwrap(app.items.first?.documentURL)
        try await app.newSampleLibrary(); try await finish(app)
        XCTAssertTrue(app.mailRecoveryNeeded); XCTAssertEqual(app.items.first?.status, "ready")
        XCTAssertEqual(try Data(contentsOf: parent), bytes); XCTAssertTrue(try scratchIsEmpty(support))
        let reopened = AppModel(support: support, preferences: defaults); await reopened.start()
        XCTAssertFalse(reopened.mailRecoveryNeeded); XCTAssertNotNil(reopened.items.first?.mailDelivery)
        XCTAssertEqual(try Data(contentsOf: parent), bytes, "Uncertain transactions retain abandoned records; no broad startup GC")
        XCTAssertEqual(try Data(contentsOf: original), bytes)
    }
    func testScanRemovesOnlyCurrentScratchAfterOwnedPublication() async throws {
        let (root, defaults, _, _) = try workspace(), support = root.appendingPathComponent("support")
        let app = AppModel(support: support, preferences: defaults)
        await app.importScan(try MailImport.bodyPDF("Synthetic scanned receipt"), typeIdentifier: UTType.pdf.identifier)
        XCTAssertEqual(app.items.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(app.items.first?.documentURL).path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: support.appendingPathComponent("Scans").path).isEmpty)
    }
}
