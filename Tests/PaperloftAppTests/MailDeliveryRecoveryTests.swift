import Foundation
import XCTest
import PaperloftKit

@MainActor final class MailDeliveryRecoveryTests: XCTestCase {
    private func workspace() throws -> (URL, UserDefaults) {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/MailDeliveryRecovery/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "app.paperloft.mail-delivery." + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { try FileManager.default.removeItem(at: root); UserDefaults.standard.removePersistentDomain(forName: suite) }
        return (root, defaults)
    }
    private func parent(_ root: URL) throws -> InboxItem {
        let url = root.appendingPathComponent(UUID().uuidString + ".eml")
        try Data("Message-ID: <receipt@example.invalid>\r\n\r\nSynthetic receipt".utf8).write(to: url)
        return InboxItem(id: UUID(), source: url, status: "failed")
    }
    private func child(_ root: URL) throws -> InboxItem {
        let url = root.appendingPathComponent(UUID().uuidString + ".png"); try Data([1,2,3]).write(to: url)
        let fields = ExtractedFields(vendor: "Synthetic", date: "2026-09-29", total: "12.00", currency: "USD", category: "Office supplies", backend: "stub")
        return InboxItem(id: UUID(), source: url, review: StoredReview(ReviewedDocument(source: url, contentHash: "synthetic", text: "", fields: fields)), draft: ReceiptDraft(fields), status: "ready")
    }
    private func save(_ items: [InboxItem], _ root: URL) throws { try JSONEncoder().encode(items).write(to: root.appendingPathComponent("inbox.json"), options: .atomic) }
    private func read(_ root: URL) throws -> [InboxItem] { try JSONDecoder().decode([InboxItem].self, from: Data(contentsOf: root.appendingPathComponent("inbox.json"))) }

    func testSuccessfulDeliveryAndExplicitDuplicateSurviveRelaunch() async throws {
        let (root, defaults) = try workspace(), original = try parent(root), result = try child(root)
        try save([original], root)
        let model = AppModel(support: root, preferences: defaults); await model.start()
        try model.commitMailDelivery(parentID: original.id, replacements: [result], messageID: "<receipt@example.invalid>")
        let proof = try XCTUnwrap(try read(root).first?.mailDelivery)
        let second = try parent(root)
        try save(try read(root) + [second], root)
        let reopened = AppModel(support: root, preferences: defaults); await reopened.start()
        XCTAssertTrue(try reopened.markMailDuplicate(parentID: second.id, messageID: "<receipt@example.invalid>"))
        let duplicate = try XCTUnwrap(reopened.items.first { $0.id == second.id })
        XCTAssertEqual(duplicate.status, "duplicate"); XCTAssertEqual(duplicate.duplicateMailDeliveryID, proof.deliveryID)
        XCTAssertTrue(duplicate.issue?.contains("Message-ID") == true)
        XCTAssertEqual(try read(root).count, 2)
    }

    func testPartialFailurePublishesNothingAndSameMessageCanRetry() async throws {
        let (root, defaults) = try workspace(), original = try parent(root), good = try child(root)
        var failed = try child(root); failed.status = "failed"; failed.review = nil
        try save([original], root)
        let model = AppModel(support: root, preferences: defaults); await model.start()
        XCTAssertThrowsError(try model.commitMailDelivery(parentID: original.id, replacements: [good, failed], messageID: "<receipt@example.invalid>"))
        XCTAssertFalse(model.mailRecoveryNeeded); XCTAssertEqual(try read(root).map(\.id), [original.id])
        let ledger = try MailDeliveryLedger(directory: root)
        XCTAssertNil(try ledger.committedDeliverySynchronously(messageID: "<receipt@example.invalid>"))
        model.retryMailItem(original.id); XCTAssertEqual(model.items.first?.status, "waiting")
        let reopened = AppModel(support: root, preferences: defaults); await reopened.start()
        try reopened.commitMailDelivery(parentID: original.id, replacements: [good], messageID: "<receipt@example.invalid>")
        XCTAssertEqual(try read(root).map(\.id), [good.id])
    }

    func testSaveFailurePreservesParentAndBlocksMutationsUntilReload() async throws {
        let (root, defaults) = try workspace(), original = try parent(root), result = try child(root)
        try save([original], root)
        var fail = true
        let model = AppModel(support: root, preferences: defaults, mailSnapshotWriter: { data, url in
            if fail { throw AppIssue("Synthetic save failure") }; try data.write(to: url, options: .atomic)
        }); await model.start()
        XCTAssertThrowsError(try model.commitMailDelivery(parentID: original.id, replacements: [result], messageID: "<receipt@example.invalid>"))
        XCTAssertTrue(model.mailRecoveryNeeded); XCTAssertFalse(model.canFile)
        model.setAside(original.id); model.retryMailItem(original.id)
        var edited = original.draft; edited.vendor = "Must not persist"; model.edit(edited, id: original.id)
        XCTAssertEqual(try read(root).first?.status, "failed")
        XCTAssertEqual(try read(root).first?.draft.vendor, original.draft.vendor)
        do { try await model.newSampleLibrary(discardInbox: true); XCTFail("Recovery must block reset") } catch { }
        fail = false; await model.retryMailRecovery()
        XCTAssertFalse(model.mailRecoveryNeeded)
        try model.commitMailDelivery(parentID: original.id, replacements: [result], messageID: "<receipt@example.invalid>")
        XCTAssertEqual(try read(root).map(\.id), [result.id])
    }

    func testFailureAfterSnapshotRenameReloadsChildrenInsteadOfOverwritingProof() async throws {
        let (root, defaults) = try workspace(), original = try parent(root), result = try child(root)
        try save([original], root)
        let model = AppModel(support: root, preferences: defaults, mailSnapshotWriter: { data, url in
            try data.write(to: url, options: .atomic); throw AppIssue("Synthetic sync failure after rename")
        }); await model.start()
        XCTAssertThrowsError(try model.commitMailDelivery(parentID: original.id, replacements: [result], messageID: "<receipt@example.invalid>"))
        XCTAssertEqual(model.items.map(\.id), [original.id])
        let durable = try Data(contentsOf: root.appendingPathComponent("inbox.json"))
        model.setAside(original.id)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("inbox.json")), durable)
        let reopened = AppModel(support: root, preferences: defaults); await reopened.start()
        XCTAssertFalse(reopened.mailRecoveryNeeded); XCTAssertEqual(reopened.items.map(\.id), [result.id])
        let ledger = try MailDeliveryLedger(directory: root)
        XCTAssertEqual(try ledger.committedDeliverySynchronously(messageID: "<receipt@example.invalid>"), try read(root).first?.mailDelivery?.deliveryID)
    }

    func testLedgerFailureFreezesPublishedChildrenThenRetryReplaysProof() async throws {
        let (root, defaults) = try workspace(), original = try parent(root), result = try child(root)
        try save([original], root)
        let ledger = try MailDeliveryLedger(directory: root); var fail = true
        let model = AppModel(support: root, preferences: defaults, mailCommit: { proof in
            if fail { throw AppIssue("Synthetic ledger failure") }; return try ledger.commitSynchronously(proof)
        }); await model.start()
        XCTAssertThrowsError(try model.commitMailDelivery(parentID: original.id, replacements: [result], messageID: "<receipt@example.invalid>"))
        XCTAssertTrue(model.mailRecoveryNeeded); XCTAssertEqual(model.items.map(\.id), [result.id])
        let durable = try Data(contentsOf: root.appendingPathComponent("inbox.json"))
        model.setAside(result.id)
        await model.intake([original.source]) // attempted startup recovery must fail, never append
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("inbox.json")), durable)
        XCTAssertEqual(model.items.map(\.id), [result.id])
        fail = false; await model.retryMailRecovery()
        XCTAssertFalse(model.mailRecoveryNeeded)
        XCTAssertEqual(try ledger.committedDeliverySynchronously(messageID: "<receipt@example.invalid>"), try read(root).first?.mailDelivery?.deliveryID)
    }

    func testConflictingLedgerDeliveryBlocksStartupBeforeMutation() async throws {
        let (root, defaults) = try workspace(); var result = try child(root)
        let ledger = try MailDeliveryLedger(directory: root)
        let first = try XCTUnwrap(MailDeliveryLedger.proof(messageID: "<receipt@example.invalid>")); try ledger.commitSynchronously(first)
        result.mailDelivery = try XCTUnwrap(MailDeliveryLedger.proof(messageID: "<receipt@example.invalid>"))
        try save([result], root)
        let durable = try Data(contentsOf: root.appendingPathComponent("inbox.json"))
        let model = AppModel(support: root, preferences: defaults); await model.start()
        XCTAssertTrue(model.mailRecoveryNeeded); XCTAssertTrue(model.message?.contains("conflicts") == true)
        model.setAside(result.id)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("inbox.json")), durable)
    }

    func testConflictingCommitReturnPreservesProofAndFreezes() async throws {
        let (root, defaults) = try workspace(), original = try parent(root), result = try child(root)
        try save([original], root)
        let model = AppModel(support: root, preferences: defaults, mailCommit: { _ in UUID() }); await model.start()
        XCTAssertThrowsError(try model.commitMailDelivery(parentID: original.id, replacements: [result], messageID: "<receipt@example.invalid>"))
        XCTAssertTrue(model.mailRecoveryNeeded)
        XCTAssertNotNil(try read(root).first?.mailDelivery)
        XCTAssertEqual(try read(root).map(\.id), [result.id])
        model.setAside(result.id)
        XCTAssertEqual(try read(root).first?.status, "ready")
    }

    func testRemovedEmailCannotBeResurrectedByLateDelivery() async throws {
        let (root, defaults) = try workspace(), original = try parent(root), result = try child(root)
        try save([original], root)
        let model = AppModel(support: root, preferences: defaults); await model.start()
        model.setAside(original.id)
        XCTAssertThrowsError(try model.commitMailDelivery(parentID: original.id, replacements: [result], messageID: "<receipt@example.invalid>"))
        XCTAssertFalse(try model.markMailDuplicate(parentID: original.id, messageID: "<receipt@example.invalid>"))
        XCTAssertEqual(try read(root).first?.status, "aside")
        XCTAssertFalse(model.mailRecoveryNeeded)
    }

    func testMailTransactionCannotFreezeInboxDuringExistingFilingOperation() async throws {
        let (root, defaults) = try workspace(), original = try parent(root), result = try child(root)
        try save([original], root)
        let model = AppModel(support: root, preferences: defaults); await model.start()
        let token = model.beginOperation(.libraryMutation)
        XCTAssertThrowsError(try model.commitMailDelivery(parentID: original.id, replacements: [result], messageID: "<receipt@example.invalid>"))
        XCTAssertThrowsError(try model.markMailDuplicate(parentID: original.id, messageID: "<receipt@example.invalid>"))
        XCTAssertFalse(model.mailRecoveryNeeded); XCTAssertEqual(try read(root).map(\.id), [original.id])
        model.endOperation(token)
        try model.commitMailDelivery(parentID: original.id, replacements: [result], messageID: "<receipt@example.invalid>")
        XCTAssertEqual(try read(root).map(\.id), [result.id])
    }
}
