import Foundation
import CryptoKit
import XCTest
import PaperloftKit

@MainActor final class ConcurrentReceiptConfirmationTests: XCTestCase {
    private func readyModel() async throws -> (AppModel, URL) {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/ConcurrentConfirmation/" + UUID().uuidString)
        let suite = "app.paperloft.concurrent-confirmation." + UUID().uuidString
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { try FileManager.default.removeItem(at: root); UserDefaults.standard.removePersistentDomain(forName: suite) }
        let model = AppModel(support: root, preferences: preferences, proEntitlement: { true })
        try await model.newSampleLibrary()
        let source = root.appendingPathComponent("receipt.pdf")
        try Data("preserved source document".utf8).write(to: source)
        let fields = ExtractedFields(vendor: "Synthetic shop", date: "2026-04-01", total: "12.00", currency: "USD", category: "Office supplies", confidence: 1, backend: "system")
        let review = StoredReview(ReviewedDocument(source: source, contentHash: SHA256.hash(data: try Data(contentsOf: source)).map { String(format: "%02x", $0) }.joined(), text: "Synthetic shop\n2026-04-01\nTotal 12.00", fields: fields))
        let item = InboxItem(id: UUID(), source: source, review: review, draft: ReceiptDraft(fields), status: "ready")
        model.items = [item]; model.selectedItemID = item.id
        return (model, source)
    }

    func testReadyReceiptFilesDuringBackgroundWorkAndKeepsItsBusyOwnership() async throws {
        let (model, source) = try await readyModel()
        let first = model.beginOperation(.background), second = model.beginOperation(.background)
        model.processing = true
        XCTAssertTrue(model.busy)
        XCTAssertTrue(model.canFile, "A different receipt or background job must not disable this ready receipt")
        await model.fileSelected()
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertEqual(model.documents.count, 1)
        XCTAssertTrue(model.busy, "Filing completion must not clear other jobs' busy state")
        model.endOperation(first)
        XCTAssertTrue(model.busy)
        model.endOperation(second)
        XCTAssertFalse(model.busy)
        XCTAssertEqual(try Data(contentsOf: source), Data("preserved source document".utf8))
    }

    func testLibraryMutationStillBlocksReadyReceiptWithoutLosingIt() async throws {
        let (model, _) = try await readyModel()
        let token = model.beginOperation(.libraryMutation)
        XCTAssertFalse(model.canFile)
        await model.fileSelected()
        XCTAssertEqual(model.items.count, 1)
        XCTAssertTrue(model.documents.isEmpty)
        model.endOperation(token)
        XCTAssertTrue(model.canFile)
        await model.fileSelected()
        XCTAssertEqual(model.documents.count, 1)
    }

    func testBackgroundCompletionCannotClearConcurrentFilingConflict() async throws {
        let (model, _) = try await readyModel()
        let background = model.beginOperation(.background)
        let filing = model.beginOperation(.libraryMutation)
        model.endOperation(background)
        XCTAssertTrue(model.busy)
        XCTAssertFalse(model.canFile)
        model.endOperation(filing)
        XCTAssertFalse(model.busy)
        XCTAssertTrue(model.canFile)
    }
    func testWatchedIntakeAndConfirmationPreserveBothDeliveryProofs() async throws {
        let (model, source) = try await readyModel()
        let root = source.deletingLastPathComponent()
        let watched = root.appendingPathComponent("watch")
        try FileManager.default.createDirectory(at: watched, withIntermediateDirectories: true)
        let incoming = watched.appendingPathComponent("incoming.pdf")
        try Data(repeating: 65, count: 1_000_000).write(to: incoming)
        try await model.installWatchedFolder(at: watched, schedule: false, stableInterval: .milliseconds(1))
        let scanner = try WatchedFolderScanner(root: watched, stateURL: root.appendingPathComponent("candidate-state.json"), minimumStableInterval: .milliseconds(1))
        _ = try await scanner.scan()
        try await Task.sleep(for: .milliseconds(10))
        let scan = try await scanner.scan()
        let candidate = try XCTUnwrap(scan.candidates.first)
        let existingKey = String(repeating: "a", count: 64)
        model.items[0].watchedDelivery = WatchedDeliveryProof(sourceKey: existingKey, contentHash: SHA256.hash(data: try Data(contentsOf: source)).map { String(format: "%02x", $0) }.joined(), sequence: 1)
        let intake = Task { try await model.queueWatchedCandidate(candidate) }
        let deadline = Date().addingTimeInterval(5)
        while !model.busy && Date() < deadline { await Task.yield() }
        XCTAssertTrue(model.busy)
        XCTAssertTrue(model.canFile)
        await model.fileSelected()
        try await intake.value
        XCTAssertEqual(model.documents.count, 1)
        let ledger = try JSONDecoder().decode([String: WatchedDeliveryProof].self, from: Data(contentsOf: root.appendingPathComponent("watched-deliveries.json")))
        XCTAssertEqual(ledger.count, 2)
        XCTAssertNotNil(ledger[existingKey])
        XCTAssertTrue(ledger.values.contains { $0.contentHash == candidate.contentHash })
        XCTAssertEqual(try Data(contentsOf: source), Data("preserved source document".utf8))
        await model.disableWatchedFolder()
    }

}
