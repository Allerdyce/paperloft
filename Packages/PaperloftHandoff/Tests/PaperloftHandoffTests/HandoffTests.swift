import Foundation
import XCTest
@testable import PaperloftHandoff

final class HandoffTests: XCTestCase, @unchecked Sendable {
    private func workspace() throws -> URL {
        let base = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/test-data/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: base) }
        return base
    }
    private func file(_ base: URL, _ name: String = "receipt.pdf", data: Data = Data("synthetic receipt".utf8)) throws -> URL {
        let url = base.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }
    private func expectError(_ operation: () async throws -> Void, _ expected: HandoffError) async {
        do { try await operation(); XCTFail("Expected \(expected)") }
        catch { XCTAssertEqual(error as? HandoffError, expected) }
    }

    func testClaimRetryAfterDestinationCommitPreservesOriginal() async throws {
        let root = try workspace(), source = try file(root)
        let original = try Data(contentsOf: source), id = UUID()
        var store = try HandoffStore(containerURL: root)
        let input = HandoffInput(id: id, fileURL: source, type: .pdf, sourceApp: "Preview")
        _ = try await store.publish([input])
        let firstClaim = try await store.claim(id)
        let claim = try XCTUnwrap(firstClaim)
        XCTAssertEqual(try Data(contentsOf: claim.fileURL), original)
        XCTAssertEqual(claim.item.sourceApp, "Preview")
        // Destination commits its key, then consumer dies before acknowledgement.
        let destination = root.appendingPathComponent("durable-app-inbox.json")
        try JSONEncoder().encode([id]).write(to: destination, options: .atomic)
        store = try HandoffStore(containerURL: root)
        let resumed = try await store.outstandingClaims()
        XCTAssertEqual(resumed.map(\.item.id), [id])
        var destinationIDs = try JSONDecoder().decode(Set<UUID>.self, from: Data(contentsOf: destination))
        XCTAssertFalse(destinationIDs.insert(resumed[0].item.id).inserted)
        try await store.acknowledge(resumed[0])
        try await store.acknowledge(resumed[0])
        _ = try await store.publish([input])
        let available = try await store.availableItems(), remaining = try await store.outstandingClaims()
        XCTAssertTrue(available.isEmpty); XCTAssertTrue(remaining.isEmpty)
        XCTAssertEqual(try Data(contentsOf: source), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: claim.fileURL.path))
    }

    func testPartialStagesInvisibleAndOnlyStaleStagesRemoved() async throws {
        let root = try workspace(), store = try HandoffStore(containerURL: root)
        let now = Date()
        let old = root.appendingPathComponent("Inbox/.incoming/" + UUID().uuidString)
        let fresh = root.appendingPathComponent("Inbox/.incoming/" + UUID().uuidString)
        for dir in [old, fresh] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
            try Data("half-written".utf8).write(to: dir.appendingPathComponent("document.pdf"))
        }
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-86_401)], ofItemAtPath: old.path)
        let source = try file(root), id = UUID()
        _ = try await store.publish([HandoffInput(id: id, fileURL: source, type: .pdf)])
        let visible = try await store.availableItems()
        XCTAssertEqual(visible.map(\.id), [id])
        let removed = try await store.cleanupStaleIncoming(now: now)
        XCTAssertEqual(removed, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        let published = try await store.availableItems()
        XCTAssertEqual(published.count, 1)
    }

    func testReceiptWrittenBeforeCrashSuppressesOrphanedClaim() async throws {
        let root = try workspace(), source = try file(root), id = UUID()
        let store = try HandoffStore(containerURL: root)
        _ = try await store.publish([HandoffInput(id: id, fileURL: source, type: .pdf)])
        let result = try await store.claim(id), claim = try XCTUnwrap(result)
        // Reproduce durable receipt followed by process death before copy deletion.
        try JSONEncoder().encode(claim.item).write(to: root.appendingPathComponent("Inbox/.receipts/" + id.uuidString), options: .atomic)
        let restarted = try HandoffStore(containerURL: root)
        let replay = try await restarted.outstandingClaims()
        XCTAssertTrue(replay.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: claim.fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testBoundsTypesAndSymlinks() async throws {
        let root = try workspace(), source = try file(root), store = try HandoffStore(containerURL: root)
        await expectError({ _ = try await store.publish((0..<21).map { _ in HandoffInput(fileURL: source, type: .pdf) }) }, .tooManyFiles)
        let text = try file(root, "note.txt")
        await expectError({ _ = try await store.publish([HandoffInput(fileURL: text, type: .pdf)]) }, .unsupportedType)
        let link = root.appendingPathComponent("linked.pdf")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        await expectError({ _ = try await store.publish([HandoffInput(fileURL: link, type: .pdf)]) }, .unsafePath)
        let parentLink = root.appendingPathComponent("linked-folder")
        try FileManager.default.createSymbolicLink(at: parentLink, withDestinationURL: root)
        await expectError({ _ = try await store.publish([HandoffInput(fileURL: parentLink.appendingPathComponent("receipt.pdf"), type: .pdf)]) }, .unsafePath)
        let large = try file(root, "large.pdf", data: Data())
        let handle = try FileHandle(forWritingTo: large)
        try handle.truncate(atOffset: UInt64(HandoffStore.maximumFileBytes + 1)); try handle.close()
        await expectError({ _ = try await store.publish([HandoffInput(fileURL: large, type: .pdf)]) }, .fileTooLarge)
        let visible = try await store.availableItems()
        XCTAssertTrue(visible.isEmpty)
    }

    func testTamperedManifestAndPartialPublishedPayloadRejected() async throws {
        let root = try workspace(), source = try file(root), store = try HandoffStore(containerURL: root), id = UUID()
        _ = try await store.publish([HandoffInput(id: id, fileURL: source, type: .pdf)])
        let directory = root.appendingPathComponent("Inbox/" + id.uuidString)
        let metadata = directory.appendingPathComponent("item.json")
        let original = try Data(contentsOf: metadata)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        json["originalName"] = "../../receipt.pdf"
        try JSONSerialization.data(withJSONObject: json).write(to: metadata)
        await expectError({ _ = try await store.claim(id) }, .unsafePath)
        try original.write(to: metadata)
        try Data().write(to: directory.appendingPathComponent("document.pdf"))
        await expectError({ _ = try await store.claim(id) }, .invalidItem)
    }

    func testPartialBatchFailureCanRetryStableIDs() async throws {
        let root = try workspace(), first = try file(root), store = try HandoffStore(containerURL: root)
        let second = root.appendingPathComponent("later.pdf")
        let inputs = [HandoffInput(fileURL: first, type: .pdf), HandoffInput(fileURL: second, type: .pdf)]
        do { _ = try await store.publish(inputs); XCTFail("Missing source must fail") } catch {}
        let beforeRetry = try await store.availableItems()
        XCTAssertEqual(beforeRetry.map(\.id), [inputs[0].id])
        try Data("second synthetic receipt".utf8).write(to: second)
        _ = try await store.publish(inputs)
        let afterRetry = try await store.availableItems()
        XCTAssertEqual(Set(afterRetry.map(\.id)), Set(inputs.map(\.id)))
        let partial = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Inbox/.incoming"), includingPropertiesForKeys: nil)
        XCTAssertTrue(partial.isEmpty)
    }

    func testTwentyFilesTotalOneHundredMBStreamThrough() async throws {
        let root = try workspace(), store = try HandoffStore(containerURL: root)
        let source = try file(root, data: Data(repeating: 0x31, count: 5_000_000))
        let inputs = (0..<20).map { _ in HandoffInput(fileURL: source, type: .pdf) }
        _ = try await store.publish(inputs)
        let items = try await store.availableItems()
        XCTAssertEqual(items.count, 20)
        XCTAssertEqual(items.reduce(Int64(0)) { $0 + $1.byteCount }, 100_000_000)
        let originalAttributes = try FileManager.default.attributesOfItem(atPath: source.path)
        XCTAssertEqual((originalAttributes[.size] as? NSNumber)?.intValue, 5_000_000)
    }

    func testThousandDeterministicRandomizedCrashRetries() async throws {
        let root = try workspace(), source = try file(root), before = try Data(contentsOf: source)
        var store = try HandoffStore(containerURL: root)
        var committed = Set<UUID>(), commits = 0
        var seed: UInt64 = 0x9a123bc
        for _ in 0..<1_000 {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1
            let id = UUID(), input = HandoffInput(id: id, fileURL: source, type: .pdf)
            _ = try await store.publish([input])
            if seed % 3 == 0 { _ = try await store.publish([input]) }
            let result = try await store.claim(id), claim = try XCTUnwrap(result)
            if seed % 2 == 0 {
                if committed.insert(id).inserted { commits += 1 }
            }
            // New actor represents a new consumer process, replaying the same key.
            store = try HandoffStore(containerURL: root)
            let recovery = try await store.outstandingClaims()
            XCTAssertEqual(recovery.map(\.item.id), [id])
            if committed.insert(recovery[0].item.id).inserted { commits += 1 }
            try await store.acknowledge(claim)
            _ = try await store.publish([input])
        }
        XCTAssertEqual(commits, 1_000)
        XCTAssertEqual(try Data(contentsOf: source), before)
        let visible = try await store.availableItems(), pending = try await store.outstandingClaims()
        XCTAssertTrue(visible.isEmpty); XCTAssertTrue(pending.isEmpty)
    }
}
