import Foundation
import XCTest
import PaperloftKit
import PaperloftHandoff
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

@MainActor final class OwnedIntakeIntegrationTests: XCTestCase {
    private let fields = ExtractedFields(kind: "receipt", vendor: "Synthetic shop", date: "2026-09-29", total: "12.00", currency: "USD", category: "Office supplies", confidence: 1, backend: "stub")
    private func workspace() throws -> (URL, UserDefaults) {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/OwnedIntake/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "app.paperloft.owned-intake." + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { try FileManager.default.removeItem(at: root); UserDefaults.standard.removePersistentDomain(forName: suite) }
        return (root, defaults)
    }
    private func source(_ root: URL) throws -> (URL, Data) {
        let url = root.appendingPathComponent("Original receipt.pdf")
        let bytes = try MailImport.bodyPDF("Synthetic shop\nSeptember 29, 2026\nOffice supplies\nTotal USD 12.00")
        try bytes.write(to: url); return (url, bytes)
    }
    private func model(_ root: URL, _ defaults: UserDefaults) -> AppModel {
        AppModel(support: root.appendingPathComponent("support"), preferences: defaults, extractionBackend: StubBackend(response: fields))
    }
    private func finish(_ app: AppModel) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while (app.processing || app.items.contains { $0.status == "waiting" || $0.status == "processing" }) && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(app.processing); XCTAssertEqual(app.items.first?.status, "ready")
    }

    func testDeletedOriginalStillProcessesAndCopiesOwnedBytes() async throws {
        let (root, defaults) = try workspace(), (original, bytes) = try source(root), app = model(root, defaults)
        await app.intake([original])
        let queued = try XCTUnwrap(app.items.first), owned = try XCTUnwrap(queued.documentURL)
        XCTAssertEqual(queued.source, original); XCTAssertNotEqual(owned, original)
        XCTAssertEqual(queued.name, "Original receipt.pdf"); XCTAssertEqual(queued.intakeRecord?.origin, .fileImport)
        try FileManager.default.removeItem(at: original)
        try await app.newSampleLibrary(); try await finish(app)
        app.mode = .copy; app.selectedItemID = queued.id; await app.fileSelected()
        XCTAssertTrue(app.items.isEmpty)
        let document = try XCTUnwrap(app.documents.first), library = try XCTUnwrap(app.libraryURL)
        XCTAssertEqual(try Data(contentsOf: library.appendingPathComponent(document.relativePath)), bytes)
        XCTAssertEqual(try Data(contentsOf: owned), bytes)
    }

    func testRenamedOriginalSurvivesRestartMoveFailsAndCopyRemainsAvailable() async throws {
        let (root, defaults) = try workspace(), (original, bytes) = try source(root), app = model(root, defaults)
        await app.intake([original], origin: .drop)
        let queued = try XCTUnwrap(app.items.first), owned = try XCTUnwrap(queued.documentURL)
        let renamed = root.appendingPathComponent("Renamed elsewhere.pdf"); try FileManager.default.moveItem(at: original, to: renamed)
        let restarted = model(root, defaults); await restarted.start()
        XCTAssertEqual(restarted.items.first?.source, original); XCTAssertEqual(restarted.items.first?.documentURL, owned)
        try await restarted.newSampleLibrary(); try await finish(restarted)
        restarted.selectedItemID = queued.id; restarted.mode = .move; await restarted.fileSelected()
        XCTAssertEqual(restarted.items.count, 1); XCTAssertTrue(restarted.documents.isEmpty)
        XCTAssertTrue(restarted.message?.contains("Choose Copy") == true)
        XCTAssertEqual(try Data(contentsOf: owned), bytes); XCTAssertEqual(try Data(contentsOf: renamed), bytes)
        restarted.mode = .copy; await restarted.fileSelected()
        XCTAssertTrue(restarted.items.isEmpty); XCTAssertEqual(restarted.documents.count, 1)
    }

    func testChangedOriginalCannotBeMovedUsingStagedReviewHash() async throws {
        let (root, defaults) = try workspace(), (original, bytes) = try source(root), app = model(root, defaults)
        await app.intake([original]); try await app.newSampleLibrary(); try await finish(app)
        let item = try XCTUnwrap(app.items.first), owned = try XCTUnwrap(item.documentURL)
        let changed = try MailImport.bodyPDF("A different receipt total USD 99.00"); try changed.write(to: original)
        app.selectedItemID = item.id; app.mode = .move; await app.fileSelected()
        XCTAssertEqual(app.items.count, 1); XCTAssertTrue(app.documents.isEmpty)
        XCTAssertNotNil(app.message); XCTAssertEqual(try Data(contentsOf: owned), bytes); XCTAssertEqual(try Data(contentsOf: original), changed)
        app.mode = .copy; await app.fileSelected()
        let document = try XCTUnwrap(app.documents.first), library = try XCTUnwrap(app.libraryURL)
        XCTAssertEqual(try Data(contentsOf: library.appendingPathComponent(document.relativePath)), bytes)
    }

    func testUnchangedOriginalMoveAndUndoStillUseOriginalLocation() async throws {
        let (root, defaults) = try workspace(), (original, bytes) = try source(root), app = model(root, defaults)
        await app.intake([original]); try await app.newSampleLibrary(); try await finish(app)
        let item = try XCTUnwrap(app.items.first), owned = try XCTUnwrap(item.documentURL)
        app.selectedItemID = item.id; app.mode = .move; await app.fileSelected()
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.path)); XCTAssertEqual(try Data(contentsOf: owned), bytes)
        let batch = try XCTUnwrap(app.batches.first); await app.undo(batch)
        XCTAssertEqual(try Data(contentsOf: original), bytes); XCTAssertTrue(app.documents.isEmpty)
    }

    func testCorruptPayloadDoesNotFallBackToOriginalOrSerializedAbsoluteURL() async throws {
        let (root, defaults) = try workspace(), (original, _) = try source(root), app = model(root, defaults)
        await app.intake([original])
        let item = try XCTUnwrap(app.items.first), owned = try XCTUnwrap(item.documentURL)
        let snapshot = app.support.appendingPathComponent("inbox.json")
        var objects = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: snapshot)) as? [[String: Any]])
        objects[0]["stagedSource"] = original.absoluteString // old/untrusted extra keys never become a validated accessor
        try JSONSerialization.data(withJSONObject: objects).write(to: snapshot)
        try Data("corrupt payload".utf8).write(to: owned)
        let reopened = model(root, defaults); await reopened.start()
        XCTAssertEqual(reopened.items.first?.status, "failed"); XCTAssertNil(reopened.items.first?.documentURL)
        XCTAssertTrue(reopened.items.first?.issue?.contains("Reimport") == true)
        XCTAssertFalse(reopened.canFile); XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
    }

    func testAmbiguousSnapshotPublicationRestoresValidatedOwnedRecord() async throws {
        let (root, defaults) = try workspace(), (original, bytes) = try source(root)
        let app = AppModel(support: root.appendingPathComponent("support"), preferences: defaults, intakeSnapshotWriter: { data, url in
            try data.write(to: url, options: .atomic); throw AppIssue("Synthetic sync failure after publication")
        })
        await app.intake([original])
        XCTAssertTrue(app.mailRecoveryNeeded); XCTAssertTrue(app.items.isEmpty)
        let snapshot = app.support.appendingPathComponent("inbox.json")
        let stored = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: snapshot)) as? [[String: Any]])
        XCTAssertNotNil(stored.first?["intakeRecord"]); XCTAssertNil(stored.first?["stagedSource"])
        let reopened = model(root, defaults); await reopened.start()
        XCTAssertFalse(reopened.mailRecoveryNeeded)
        let owned = try XCTUnwrap(reopened.items.first?.documentURL)
        XCTAssertNotEqual(owned, original); XCTAssertEqual(try Data(contentsOf: owned), bytes)
        XCTAssertEqual(try Data(contentsOf: original), bytes)
    }

    func testSharedTIFFRetryUsesSameOwnedIdentityBeforeAcknowledgment() async throws {
        let (root, defaults) = try workspace()
        let context = try XCTUnwrap(CGContext(data: nil, width: 240, height: 240, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let data = NSMutableData(), destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.tiff.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil); XCTAssertTrue(CGImageDestinationFinalize(destination))
        let original = root.appendingPathComponent("Shared receipt.tiff"); try (data as Data).write(to: original)
        let handoff = try HandoffStore(containerURL: root.appendingPathComponent("Group")), id = UUID()
        _ = try await handoff.publish([HandoffInput(id: id, fileURL: original, type: .tiff)])
        var fail = true
        let app = AppModel(support: root.appendingPathComponent("support"), preferences: defaults, intakeSnapshotWriter: { data, url in
            if fail { throw AppIssue("Synthetic failure before inbox publication") }; try data.write(to: url, options: .atomic)
        })
        await app.receiveSharedItems(from: handoff)
        XCTAssertTrue(app.items.isEmpty); XCTAssertTrue(app.mailRecoveryNeeded)
        let pending = try await handoff.outstandingClaims(); XCTAssertEqual(pending.count, 1)
        let queue = try IntakeQueue(directory: app.support.appendingPathComponent("IntakeQueue"))
        let first = try await queue.record(id: id)
        fail = false; await app.receiveSharedItems(from: handoff)
        XCTAssertEqual(app.items.count, 1); XCTAssertEqual(app.items.first?.intakeRecord, first)
        XCTAssertEqual(app.items.first?.name, "Shared receipt.tiff"); XCTAssertEqual(app.items.first?.documentURL?.pathExtension, "png")
        let remaining = try await handoff.outstandingClaims(); XCTAssertTrue(remaining.isEmpty)
        XCTAssertEqual(try Data(contentsOf: original), data as Data)
    }

    func testCorruptOwnedSharedCopyNeverAcknowledgesRetainedUpstreamClaim() async throws {
        let (root, defaults) = try workspace(), (original, _) = try source(root), id = UUID()
        let handoff = try HandoffStore(containerURL: root.appendingPathComponent("Group"))
        _ = try await handoff.publish([HandoffInput(id: id, fileURL: original, type: .pdf)])
        let app = AppModel(support: root.appendingPathComponent("support"), preferences: defaults, intakeSnapshotWriter: { data, url in
            try data.write(to: url, options: .atomic); throw AppIssue("Synthetic failure after inbox publication")
        })
        await app.receiveSharedItems(from: handoff)
        let queue = try IntakeQueue(directory: app.support.appendingPathComponent("IntakeQueue")), record = try await queue.record(id: id)
        let owned = try await queue.payloadURL(for: record); try Data("corrupt".utf8).write(to: owned)
        let reopened = model(root, defaults); await reopened.receiveSharedItems(from: handoff)
        XCTAssertEqual(reopened.items.first?.status, "failed"); XCTAssertNil(reopened.items.first?.documentURL)
        let remaining = try await handoff.outstandingClaims(); XCTAssertEqual(remaining.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: reopened.support.appendingPathComponent("shared-accepted.json").path))
    }

    func testPasteAndScanOriginsUseOwnedRecordsAndVisibleNames() async throws {
        let (root, defaults) = try workspace(), (original, bytes) = try source(root), app = model(root, defaults)
        await app.intake([original], sourceLabel: "Pasted image", origin: .paste)
        let item = try XCTUnwrap(app.items.first)
        XCTAssertEqual(item.intakeRecord?.origin, .paste); XCTAssertEqual(item.usesOriginalForMove, false)
        XCTAssertEqual(item.name, original.lastPathComponent); XCTAssertNotEqual(item.source, original)
        let scan = root.appendingPathComponent("Scan output.pdf"); try bytes.write(to: scan)
        await app.intake([scan], sourceLabel: "Scanned from iPhone or iPad", origin: .scan)
        XCTAssertEqual(app.items.last?.intakeRecord?.origin, .scan)
        XCTAssertTrue(app.items.allSatisfy { $0.documentURL != nil && $0.intakeRecord != nil })
    }
}
