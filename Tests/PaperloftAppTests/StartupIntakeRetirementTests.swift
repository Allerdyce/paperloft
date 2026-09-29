import Foundation
import XCTest
import PaperloftKit
import PaperloftHandoff

@MainActor final class StartupIntakeRetirementTests: XCTestCase {
    private func workspace() throws -> (URL, UserDefaults, IntakeQueue, URL) {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/StartupRetirement/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "app.paperloft.retirement." + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { try FileManager.default.removeItem(at: root); UserDefaults.standard.removePersistentDomain(forName: suite) }
        let original = root.appendingPathComponent("original.pdf"); try MailImport.bodyPDF("Synthetic receipt").write(to: original)
        return (root, defaults, try IntakeQueue(directory: root.appendingPathComponent("IntakeQueue")), original)
    }
    private func save(_ items: [InboxItem], _ root: URL) throws {
        try JSONEncoder().encode(items).write(to: root.appendingPathComponent("inbox.json"), options: .atomic)
    }
    private func item(_ record: IntakeRecord, _ source: URL, status: String = "failed") -> InboxItem {
        InboxItem(id: record.id, source: source, intakeRecord: record, usesOriginalForMove: true, status: status, displayName: record.displayName)
    }
    func testColdStartupRetiresExplicitRemovalButPreservesLiveAndOrphanedRecords() async throws {
        let (root, defaults, queue, original) = try workspace(), bytes = try Data(contentsOf: original)
        let live = try await queue.enqueue(source: original, origin: .fileImport)
        let removed = try await queue.enqueue(source: original, origin: .fileImport)
        let abandoned = try await queue.enqueue(source: original, origin: .mail)
        try save([item(live, original), item(removed, original, status: "aside")], root)
        let app = AppModel(support: root, preferences: defaults); await app.start()
        let liveURL = try await queue.payloadURL(for: live)
        XCTAssertEqual(app.items.first?.documentURL, liveURL)
        XCTAssertNil(app.items.last?.intakeRecord)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("IntakeQueue/" + removed.relativePayloadPath).path))
        let orphanURL = try await queue.payloadURL(for: abandoned)
        XCTAssertTrue(FileManager.default.fileExists(atPath: orphanURL.path), "Unknown or failed-publication records have no retirement authority")
        let disk = try JSONDecoder().decode([InboxItem].self, from: Data(contentsOf: root.appendingPathComponent("inbox.json")))
        XCTAssertNil(disk.last?.intakeRecord); XCTAssertEqual(try Data(contentsOf: original), bytes)
    }
    func testCorruptInboxPreventsAllRetirement() async throws {
        let (root, defaults, queue, original) = try workspace(), record = try await queue.enqueue(source: original, origin: .fileImport)
        try Data("corrupt".utf8).write(to: root.appendingPathComponent("inbox.json"))
        let app = AppModel(support: root, preferences: defaults); await app.start()
        let url = try await queue.payloadURL(for: record); XCTAssertTrue(FileManager.default.fileExists(atPath: url.path)); XCTAssertFalse(app.canFile)
    }
    func testAmbiguousRetirementSnapshotFailurePreservesAllPayloadsAndRecoverySkipsGC() async throws {
        let (root, defaults, queue, original) = try workspace(), record = try await queue.enqueue(source: original, origin: .fileImport)
        try save([item(record, original, status: "aside")], root)
        let app = AppModel(support: root, preferences: defaults, retirementSnapshotWriter: { data, url in
            try data.write(to: url, options: .atomic); throw AppIssue("Synthetic sync uncertainty")
        }); await app.start()
        XCTAssertTrue(app.mailRecoveryNeeded)
        let url = try await queue.payloadURL(for: record); XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        await app.retryMailRecovery()
        XCTAssertFalse(app.mailRecoveryNeeded); XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Same-model recovery cannot collect live-process storage")
    }
    func testMissingSnapshotAndCorruptProofLedgerPreventRetirement() async throws {
        let (root, defaults, queue, original) = try workspace(), record = try await queue.enqueue(source: original, origin: .fileImport)
        let absent = AppModel(support: root, preferences: defaults); await absent.start()
        let url = try await queue.payloadURL(for: record); XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        // A separate support tests proof failure without the same-process-model safeguard.
        let other = root.appendingPathComponent("Other"); try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        let secondQueue = try IntakeQueue(directory: other.appendingPathComponent("IntakeQueue")), second = try await secondQueue.enqueue(source: original, origin: .mail)
        try save([], other); try Data("corrupt".utf8).write(to: other.appendingPathComponent("watched-deliveries.json"))
        let corrupt = AppModel(support: other, preferences: defaults); await corrupt.start()
        let secondURL = try await secondQueue.payloadURL(for: second); XCTAssertTrue(FileManager.default.fileExists(atPath: secondURL.path))
    }
    func testAnotherLiveModelAndConsumerLeasePreventRetirement() async throws {
        let (root, defaults, queue, original) = try workspace(), record = try await queue.enqueue(source: original, origin: .fileImport)
        try save([], root)
        let first = AppModel(support: root, preferences: defaults)
        let second = AppModel(support: root, preferences: defaults); await second.start()
        let url = try await queue.payloadURL(for: record); XCTAssertTrue(FileManager.default.fileExists(atPath: url.path)); withExtendedLifetime(first) {}
        let lockedRoot = root.appendingPathComponent("Locked"); try FileManager.default.createDirectory(at: lockedRoot, withIntermediateDirectories: true)
        let lockedQueue = try IntakeQueue(directory: lockedRoot.appendingPathComponent("IntakeQueue")), lockedRecord = try await lockedQueue.enqueue(source: original, origin: .fileImport)
        try save([], lockedRoot)
        let ownership = try HandoffStore(containerURL: lockedRoot.appendingPathComponent(".ownership"))
        let lease = try await ownership.acquireConsumerLease(); XCTAssertNotNil(lease)
        let blocked = AppModel(support: lockedRoot, preferences: defaults); await blocked.start()
        XCTAssertTrue(blocked.message?.contains("another") == true)
        let lockedURL = try await lockedQueue.payloadURL(for: lockedRecord); XCTAssertTrue(FileManager.default.fileExists(atPath: lockedURL.path)); withExtendedLifetime(lease) {}
    }
    func testActualRemovedReceiptRetiresOnlyAfterModelIsReleasedAndRelaunched() async throws {
        let (root, defaults, queue, original) = try workspace()
        var app: AppModel? = AppModel(support: root, preferences: defaults)
        await app?.intake([original]); let receipt = try XCTUnwrap(app?.items.first), record = try XCTUnwrap(receipt.intakeRecord)
        app?.setAside(receipt.id); let url = try await queue.payloadURL(for: record)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        weak let prior = app; app = nil; XCTAssertNil(prior)
        let reopened = AppModel(support: root, preferences: defaults); await reopened.start()
        XCTAssertNil(reopened.items.first?.intakeRecord); XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
    }
    func testFiledReceiptWithoutRetirementProofRemainsStoredAfterRestart() async throws {
        let (root, defaults, queue, original) = try workspace()
        let fields = ExtractedFields(kind: "receipt", vendor: "Synthetic", date: "2026-09-29", total: "12.00", currency: "USD", category: "Office supplies", confidence: 1, backend: "stub")
        var app: AppModel? = AppModel(support: root, preferences: defaults, extractionBackend: StubBackend(response: fields))
        await app?.intake([original]); let item = try XCTUnwrap(app?.items.first), record = try XCTUnwrap(item.intakeRecord)
        try await app?.newSampleLibrary()
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while app?.processing == true && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        app?.selectedItemID = item.id; await app?.fileSelected()
        XCTAssertTrue(app?.items.isEmpty == true)
        let document = try XCTUnwrap(app?.documents.first), library = try XCTUnwrap(app?.libraryURL)
        let url = try await queue.payloadURL(for: record); XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        weak let prior = app; app = nil; XCTAssertNil(prior)
        let reopened = AppModel(support: root, preferences: defaults); await reopened.start()
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Filing currently writes no durable cleanup disposition")
        XCTAssertEqual(try Data(contentsOf: library.appendingPathComponent(document.relativePath)), try Data(contentsOf: original))
    }
    func testUnrecordedActiveOwnedReferencePreventsRetirement() async throws {
        let (root, defaults, queue, original) = try workspace(), record = try await queue.enqueue(source: original, origin: .fileImport)
        let url = try await queue.payloadURL(for: record)
        try save([InboxItem(id: UUID(), source: url, status: "failed")], root)
        let app = AppModel(support: root, preferences: defaults); await app.start()
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testCorruptRemovedRecordAndUnknownQueuePathsArePreserved() async throws {
        let (root, defaults, queue, original) = try workspace(), record = try await queue.enqueue(source: original, origin: .fileImport)
        let url = try await queue.payloadURL(for: record); try Data("changed payload".utf8).write(to: url)
        let unknown = root.appendingPathComponent("IntakeQueue/.incoming-unknown")
        try FileManager.default.createDirectory(at: unknown, withIntermediateDirectories: false)
        try Data("unproven bytes".utf8).write(to: unknown.appendingPathComponent("payload"))
        try save([item(record, original, status: "aside")], root)
        let app = AppModel(support: root, preferences: defaults); await app.start()
        XCTAssertEqual(app.items.first?.intakeRecord, record)
        XCTAssertEqual(try Data(contentsOf: url), Data("changed payload".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unknown.path))
    }

}
