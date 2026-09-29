import XCTest
import PaperloftKit

@MainActor final class AppModelIntentTests: XCTestCase {
    func workspace() throws -> (URL, UserDefaults) {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/IntentAdapterTests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "app.paperloft.intent-tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { try FileManager.default.removeItem(at: root); UserDefaults.standard.removePersistentDomain(forName: suite) }
        return (root, defaults)
    }
    func testFirstStartConcurrentIntakeIsDurableAndRestoresForReview() async throws {
        let (root, defaults) = try workspace()
        let model = AppModel(support: root, preferences: defaults)
        // Both enter through startup before either call has explicitly initialized the model.
        async let first: Void = model.queueDocumentForReview(data: Data([1, 2, 3]), filename: "first.pdf")
        async let second: Void = model.queueDocumentForReview(data: Data([4, 5, 6]), filename: "second.pdf")
        _ = try await (first, second)
        XCTAssertEqual(model.items.count, 2)
        XCTAssertTrue(model.items.allSatisfy { $0.intakeRecord?.origin == .shortcut && $0.usesOriginalForMove == false })
        XCTAssertTrue(model.items.allSatisfy { $0.documentURL == $0.source })
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Intent-Scratch").path), [])
        XCTAssertTrue(model.items.allSatisfy { $0.status == "waiting" })
        let persisted = try JSONDecoder().decode([InboxItem].self, from: Data(contentsOf: root.appendingPathComponent("inbox.json")))
        XCTAssertEqual(persisted.count, 2)
        XCTAssertEqual(Set(try persisted.map { try Data(contentsOf: $0.source) }), Set([Data([1, 2, 3]), Data([4, 5, 6])]))
        let restored = AppModel(support: root, preferences: defaults)
        await restored.start()
        XCTAssertEqual(Set(restored.items.map(\.id)), Set(persisted.map(\.id)))
        XCTAssertTrue(restored.items.allSatisfy { $0.status == "waiting" })
        XCTAssertTrue(restored.allDocuments.isEmpty)
    }
    func testFailedInboxCommitThrowsAndDoesNotExposeSuccess() async throws {
        let (root, defaults) = try workspace()
        let model = AppModel(support: root, preferences: defaults)
        await model.start()
        try FileManager.default.createDirectory(at: root.appendingPathComponent("inbox.json"), withIntermediateDirectories: false)
        do { try await model.queueDocumentForReview(data: Data([1]), filename: "receipt.pdf"); XCTFail("Failed persistence reported success") } catch { }
        XCTAssertTrue(model.items.isEmpty)
        let imports = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("IntakeQueue"), includingPropertiesForKeys: nil)
        XCTAssertEqual(imports.count, 1, "Input copy remains recoverable after inbox-write failure")
        XCTAssertEqual(try Data(contentsOf: imports[0].appendingPathComponent("payload.pdf")), Data([1]))
    }
    func testAmbiguousCommitThrowsThenRestoresOwnedReceipt() async throws {
        let (root, defaults) = try workspace()
        let model = AppModel(support: root, preferences: defaults, intakeSnapshotWriter: { data, url in
            try data.write(to: url, options: .atomic)
            throw NSError(domain: "IntentSnapshot", code: 1)
        })
        do { try await model.queueDocumentForReview(data: Data([7, 8, 9]), filename: "ambiguous.pdf"); XCTFail("Ambiguous commit acknowledged") } catch { }
        XCTAssertTrue(model.mailRecoveryNeeded)
        XCTAssertTrue(model.items.isEmpty)
        let restored = AppModel(support: root, preferences: defaults)
        await restored.start()
        let item = try XCTUnwrap(restored.items.first)
        XCTAssertEqual(item.intakeRecord?.origin, .shortcut)
        XCTAssertEqual(item.usesOriginalForMove, false)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(item.documentURL)), Data([7, 8, 9]))
        XCTAssertTrue(restored.allDocuments.isEmpty)
    }
    func testUnreadableStartupCannotOverwriteExistingInbox() async throws {
        let (root, defaults) = try workspace()
        let original = Data("invalid inbox".utf8)
        let inbox = root.appendingPathComponent("inbox.json")
        try original.write(to: inbox)
        let model = AppModel(support: root, preferences: defaults)
        do { try await model.queueDocumentForReview(data: Data([1]), filename: "receipt.pdf"); XCTFail("Corrupt startup was ignored") } catch { }
        XCTAssertEqual(try Data(contentsOf: inbox), original)
        XCTAssertTrue(model.items.isEmpty)
    }
    func testFailedStartupCanRetryAfterInboxIsRepaired() async throws {
        let (root, defaults) = try workspace()
        let inbox = root.appendingPathComponent("inbox.json")
        try Data("invalid".utf8).write(to: inbox)
        let model = AppModel(support: root, preferences: defaults)
        do { try await model.queueDocumentForReview(data: Data([1]), filename: "receipt.pdf"); XCTFail("Corrupt startup accepted") } catch { }
        try Data("[]".utf8).write(to: inbox, options: .atomic)
        try await model.queueDocumentForReview(data: Data([2]), filename: "repaired.pdf")
        XCTAssertEqual(model.items.count, 1)
        XCTAssertEqual(model.items[0].name, "repaired.pdf")
        XCTAssertEqual(try Data(contentsOf: model.items[0].source), Data([2]))
    }
    func testTotalsAndZipReadFullCommittedLibraryAndPreserveResults() async throws {
        let (root, defaults) = try workspace()
        let libraryRoot = root.appendingPathComponent("Library")
        try FileManager.default.createDirectory(at: libraryRoot, withIntermediateDirectories: true)
        let store = try LibraryStore(root: libraryRoot)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = repo.appendingPathComponent("Apps/PaperloftApp/Resources/Samples/01-office.pdf")
        let receipt = try Receipt(vendor: "Sample", date: ReceiptDate(iso8601: "2026-02-01"), totalMinorUnits: 321, currency: "USD", category: "Office")
        _ = try await store.file([FilingRequest(source: source, receipt: receipt)])
        defaults.set(libraryRoot.path, forKey: "paperloft.demoLibraryPath")
        let model = AppModel(support: root, preferences: defaults, proEntitlement: { true })
        model.search = "a-filter-with-no-matches"
        let receipts = try await model.intentReceipts()
        XCTAssertEqual(receipts, [receipt])
        XCTAssertTrue(model.documents.isEmpty)
        let zip = try await model.exportAccountantPack(range: .year(2026))
        let bytes = try Data(contentsOf: zip)
        XCTAssertEqual(Array(bytes.prefix(2)), [0x50, 0x4b])
        XCTAssertTrue(zip.path.hasPrefix(root.appendingPathComponent("Intent-Exports").path))
        model.beginExport() // Clearing an unrelated interactive export cannot invalidate this result.
        XCTAssertEqual(try Data(contentsOf: zip), bytes)
        let free = AppModel(support: root, preferences: defaults, proEntitlement: { false })
        do { _ = try await free.exportAccountantPack(range: .year(2026)); XCTFail("Free export accepted") } catch { XCTAssertTrue(error is PaperloftIntentError) }
    }
}
