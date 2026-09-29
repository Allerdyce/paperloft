import Foundation
import XCTest
import Darwin
@testable import PaperloftKit

final class IntakeQueueTests: XCTestCase, @unchecked Sendable {
    private func setup() throws -> (URL, URL, IntakeQueue) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("receipt.pdf")
        try Data("synthetic receipt".utf8).write(to: source)
        return (root, source, try IntakeQueue(directory: root.appendingPathComponent("queue")))
    }
    func testOwnedPublicationRetryRecoveryAndExplicitDiscard() async throws {
        let (root, source, queue) = try setup(); defer { try? FileManager.default.removeItem(at: root) }
        let id = UUID(), date = Date(timeIntervalSince1970: 123)
        let metadata = IntakeSourceMetadata(detail: "Import", mailSubject: "Synthetic")
        let record = try await queue.enqueue(source: source, id: id, origin: .fileImport, metadata: metadata, receivedAt: date)
        let retry = try await queue.enqueue(source: source, id: id, origin: .fileImport, metadata: metadata)
        XCTAssertEqual(record, retry)
        let restored = try JSONDecoder().decode(IntakeRecord.self, from: JSONEncoder().encode(record))
        let reopened = try IntakeQueue(directory: root.appendingPathComponent("queue"))
        let payload = try await reopened.payloadURL(for: restored)
        try Data("changed original".utf8).write(to: source)
        XCTAssertEqual(try Data(contentsOf: payload), Data("synthetic receipt".utf8))
        try await reopened.discard(restored)
        XCTAssertFalse(FileManager.default.fileExists(atPath: payload.path))
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "changed original")
    }
    func testConflictPreservesFirstPublicationAndCleansStage() async throws {
        let (root, source, queue) = try setup(); defer { try? FileManager.default.removeItem(at: root) }
        let record = try await queue.enqueue(source: source, origin: .drop)
        try Data("other receipt".utf8).write(to: source)
        do { _ = try await queue.enqueue(source: source, id: record.id, origin: .drop); XCTFail("conflicting publication") } catch IntakeQueue.Failure.conflict { }
        let stored = try await queue.record(id: record.id)
        XCTAssertEqual(stored, record)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("queue").path), [record.id.uuidString])
    }
    func testBoundsEmptyAndSymlinkFailWithoutPublication() async throws {
        let (root, source, queue) = try setup(); defer { try? FileManager.default.removeItem(at: root) }
        do { _ = try await queue.enqueue(source: source, origin: .scan, maximumBytes: 2); XCTFail("limit") } catch IntakeQueue.Failure.tooLarge { }
        let link = root.appendingPathComponent("link.pdf")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        do { _ = try await queue.enqueue(source: link, origin: .paste); XCTFail("symlink") } catch { }
        let fifo = root.appendingPathComponent("pipe.pdf")
        XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
        do { _ = try await queue.enqueue(source: fifo, origin: .paste); XCTFail("fifo") } catch { }
        try Data().write(to: source)
        do { _ = try await queue.enqueue(source: source, origin: .mail); XCTFail("empty") } catch IntakeQueue.Failure.empty { }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("queue").path).isEmpty)
    }
    func testCorruptionAndUnexpectedDiscardContentsFailClosed() async throws {
        let (root, source, queue) = try setup(); defer { try? FileManager.default.removeItem(at: root) }
        let record = try await queue.enqueue(source: source, origin: .share)
        let payload = try await queue.payloadURL(for: record)
        let unexpected = payload.deletingLastPathComponent().appendingPathComponent("extra")
        try Data("keep".utf8).write(to: unexpected)
        do { try await queue.discard(record); XCTFail("unknown contents") } catch IntakeQueue.Failure.corrupt { }
        XCTAssertTrue(FileManager.default.fileExists(atPath: unexpected.path))
        try Data("bad".utf8).write(to: payload)
        do { _ = try await queue.payloadURL(for: record); XCTFail("corrupt bytes") } catch IntakeQueue.Failure.corrupt { }
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }
    func testCancellationBeforeEnqueueLeavesNoPublication() async throws {
        let (root, source, queue) = try setup(); defer { try? FileManager.default.removeItem(at: root) }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await queue.enqueue(source: source, origin: .fileImport)
        }
        do { _ = try await task.value; XCTFail("cancelled") } catch is CancellationError { }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("queue").path).isEmpty)
    }
    func testConcurrentSameIDPublishesOneRecord() async throws {
        let (root, source, queue) = try setup(); defer { try? FileManager.default.removeItem(at: root) }
        let other = try IntakeQueue(directory: root.appendingPathComponent("queue")), id = UUID()
        async let first = queue.enqueue(source: source, id: id, origin: .share)
        async let second = other.enqueue(source: source, id: id, origin: .share)
        let (a, b) = try await (first, second)
        XCTAssertEqual(a, b)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("queue").path), [id.uuidString])
    }
    func testTraversalOnlySourceAncestor() async throws {
        let (root, source, queue) = try setup(); defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("traverse")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let nested = folder.appendingPathComponent("receipt.pdf")
        try FileManager.default.copyItem(at: source, to: nested)
        XCTAssertEqual(chmod(folder.path, 0o100), 0)
        defer { _ = chmod(folder.path, 0o700) }
        let record = try await queue.enqueue(source: nested, origin: .watchedFolder)
        XCTAssertEqual(record.byteCount, 17)
    }
    func testCancellationAfterPartialCopyCleansStage() async throws {
        let (root, source, queue) = try setup(); defer { try? FileManager.default.removeItem(at: root) }
        try Data(repeating: 7, count: 600_000).write(to: source)
        await queue.observeCopy { withUnsafeCurrentTask { $0?.cancel() } }
        do { _ = try await queue.enqueue(source: source, origin: .scan); XCTFail("partial cancellation") } catch is CancellationError { }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("queue").path).isEmpty)
        XCTAssertEqual(try Data(contentsOf: source).count, 600_000)
    }
    func testSourceMutationDuringCopyFailsAndCleansStage() async throws {
        let (root, source, queue) = try setup(); defer { try? FileManager.default.removeItem(at: root) }
        try Data(repeating: 7, count: 600_000).write(to: source)
        await queue.observeCopy { try Data(repeating: 8, count: 600_000).write(to: source) }
        do { _ = try await queue.enqueue(source: source, origin: .drop); XCTFail("changed source") } catch IntakeQueue.Failure.changed { }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("queue").path).isEmpty)
    }
    func testUnpublishedCrashStageIsNotARecordAndDoesNotBlockRetry() async throws {
        let (root, source, queue) = try setup(); defer { try? FileManager.default.removeItem(at: root) }
        let id = UUID(), partial = root.appendingPathComponent("queue/.incoming-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: partial, withIntermediateDirectories: true)
        try Data("partial".utf8).write(to: partial.appendingPathComponent("payload.pdf"))
        do { _ = try await queue.record(id: id); XCTFail("unpublished") } catch { }
        let record = try await queue.enqueue(source: source, id: id, origin: .share)
        let restored = try await queue.record(id: id)
        XCTAssertEqual(record, restored)
        XCTAssertTrue(FileManager.default.fileExists(atPath: partial.path))
    }

    func testEscapedMetadataExpansionCannotPublishUnreadableRecord() async throws {
        let (root, source, queue) = try setup(); defer { try? FileManager.default.removeItem(at: root) }
        let metadata = IntakeSourceMetadata(detail: String(repeating: "\u{0001}", count: 4096))
        do { _ = try await queue.enqueue(source: source, origin: .mail, metadata: metadata); XCTFail("metadata expansion") } catch IntakeQueue.Failure.tooLarge { }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("queue").path).isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testFailedPublicationSyncIsRetriedForExistingID() async throws {
        let (root, source, queue) = try setup(); defer { try? FileManager.default.removeItem(at: root) }
        let id = UUID(), originalDate = Date(timeIntervalSince1970: 123)
        await queue.observePublicationSync { throw POSIXError(.EIO) }
        do { _ = try await queue.enqueue(source: source, id: id, origin: .share, receivedAt: originalDate); XCTFail("sync error") } catch let error as POSIXError { XCTAssertEqual(error.code, .EIO) }
        let published = try await queue.record(id: id)
        XCTAssertEqual(published.receivedAt, originalDate)
        do { _ = try await queue.enqueue(source: source, id: id, origin: .share); XCTFail("retry must sync") } catch let error as POSIXError { XCTAssertEqual(error.code, .EIO) }
        await queue.observePublicationSync(nil)
        let retry = try await queue.enqueue(source: source, id: id, origin: .share)
        XCTAssertEqual(retry, published)
    }

    func testInitializationRequiresExistingOwnedParent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try IntakeQueue(directory: root.appendingPathComponent("nested/queue")))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

}
