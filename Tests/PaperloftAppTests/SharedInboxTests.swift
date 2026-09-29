import Foundation
import XCTest
import PaperloftKit
import PaperloftHandoff

@MainActor final class SharedInboxTests: XCTestCase {
    private func workspace() throws -> (URL, UserDefaults, String) {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/SharedInboxTests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "app.paperloft.shared-tests." + UUID().uuidString
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { try? FileManager.default.removeItem(at: root); UserDefaults.standard.removePersistentDomain(forName: suite) }
        return (root, preferences, suite)
    }
    func testShareBeforeLaunchIsDurableIdempotentAndOriginalUnchanged() async throws {
        let (root, preferences, _) = try workspace()
        let store = try HandoffStore(containerURL: root.appendingPathComponent("Group"))
        let original = root.appendingPathComponent("receipt.pdf")
        let bytes = try MailImport.bodyPDF("Synthetic shop\nTotal 12.00")
        try bytes.write(to: original)
        let id = UUID()
        _ = try await store.publish([HandoffInput(id: id, fileURL: original, type: .pdf, sourceApp: "Preview")])
        let support = root.appendingPathComponent("App")
        let model = AppModel(support: support, preferences: preferences)
        await model.receiveSharedItems(from: store)
        XCTAssertNil(model.message)
        XCTAssertEqual(model.items.map(\.id), [id])
        XCTAssertEqual(model.items[0].intakeSource, "Shared from Preview")
        XCTAssertEqual(model.items[0].name, "receipt.pdf")
        XCTAssertEqual(try Data(contentsOf: model.items[0].source), bytes)
        XCTAssertEqual(try Data(contentsOf: original), bytes)
        let pending = try await store.availableItems(); let claims = try await store.outstandingClaims()
        XCTAssertTrue(pending.isEmpty); XCTAssertTrue(claims.isEmpty)
        let restarted = AppModel(support: support, preferences: preferences)
        await restarted.receiveSharedItems(from: store)
        XCTAssertEqual(restarted.items.map(\.id), [id])
        // Even a repeated extension delivery retains its original identity.
        _ = try await store.publish([HandoffInput(id: id, fileURL: original, type: .pdf)])
        await restarted.receiveSharedItems(from: store)
        XCTAssertEqual(restarted.items.count, 1)
    }
    func testCrashAfterInboxCommitBeforeLedgerRecoversWithoutDuplicate() async throws {
        let (root, preferences, _) = try workspace()
        let store = try HandoffStore(containerURL: root.appendingPathComponent("Group"))
        let original = root.appendingPathComponent("receipt.pdf")
        try MailImport.bodyPDF("Receipt\nTotal 3.00").write(to: original)
        let id = UUID(); _ = try await store.publish([HandoffInput(id: id, fileURL: original, type: .pdf)])
        let claim = try await store.claim(id); XCTAssertNotNil(claim)
        let support = root.appendingPathComponent("App")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let owned = support.appendingPathComponent("owned.pdf"); try FileManager.default.copyItem(at: original, to: owned)
        let item = InboxItem(id: id, source: owned, status: "receiving", intakeSource: "Shared to Paperloft")
        try JSONEncoder().encode([item]).write(to: support.appendingPathComponent("inbox.json"))
        let model = AppModel(support: support, preferences: preferences)
        await model.receiveSharedItems(from: store)
        XCTAssertNil(model.message)
        XCTAssertEqual(model.items.count, 1)
        XCTAssertEqual(model.items.first?.status, "waiting")
        let claims = try await store.outstandingClaims(); XCTAssertTrue(claims.isEmpty)
    }
    func testAcceptedLedgerRecoversReceivingAndMalformedLedgerStopsIntake() async throws {
        let (root, preferences, _) = try workspace()
        let support = root.appendingPathComponent("App")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let owned = support.appendingPathComponent("owned.pdf"); try MailImport.bodyPDF("Receipt").write(to: owned)
        let id = UUID(); let item = InboxItem(id: id, source: owned, status: "receiving")
        try JSONEncoder().encode([item]).write(to: support.appendingPathComponent("inbox.json"))
        let ledger = support.appendingPathComponent("shared-accepted.json")
        try JSONEncoder().encode([id]).write(to: ledger)
        let model = AppModel(support: support, preferences: preferences); await model.start()
        XCTAssertEqual(model.items.first?.status, "waiting")
        try Data("broken".utf8).write(to: ledger)
        let broken = AppModel(support: support, preferences: preferences); await broken.start()
        XCTAssertNotNil(broken.message)
        XCTAssertEqual(try Data(contentsOf: ledger), Data("broken".utf8))
    }
    func testCompetingInboxOwnerCannotRestoreOrConsumeSharedItems() async throws {
        let (root, preferences, _) = try workspace()
        let support = root.appendingPathComponent("App")
        let ownership = try HandoffStore(containerURL: support.appendingPathComponent(".ownership"))
        let lease = try await ownership.acquireConsumerLease()
        XCTAssertNotNil(lease)
        let store = try HandoffStore(containerURL: root.appendingPathComponent("Group"))
        let original = root.appendingPathComponent("receipt.pdf")
        try MailImport.bodyPDF("Receipt").write(to: original)
        _ = try await store.publish([HandoffInput(fileURL: original, type: .pdf)])
        let model = AppModel(support: support, preferences: preferences)
        await model.receiveSharedItems(from: store)
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertTrue(model.message?.contains("already using this inbox") == true)
        let pending = try await store.availableItems()
        XCTAssertEqual(pending.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: support.appendingPathComponent("inbox.json").path))
        withExtendedLifetime(lease) {}
    }
    func testSourceMetadataReadsLegacyInboxAndScanSettingPersists() throws {
        let item = InboxItem(id: UUID(), source: URL(fileURLWithPath: "/synthetic.pdf"))
        let restored = try JSONDecoder().decode(InboxItem.self, from: JSONEncoder().encode(item))
        XCTAssertNil(restored.intakeSource); XCTAssertNil(restored.receivedAt); XCTAssertNil(restored.displayName)
        let (root, preferences, _) = try workspace()
        let model = AppModel(support: root, preferences: preferences)
        XCTAssertEqual(model.scannedPages, .separate)
        model.scannedPages = .combined
        XCTAssertEqual(AppModel(support: root, preferences: preferences).scannedPages, .combined)
    }
}
