import Foundation
import XCTest
@testable import PaperloftKit

final class IntakeQueueReviewTests: XCTestCase, @unchecked Sendable {
    private func fixture() throws -> (URL, URL, IntakeQueue) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("source.pdf")
        try Data(repeating: 42, count: 600_000).write(to: source)
        return (root, source, try IntakeQueue(directory: root.appendingPathComponent("queue")))
    }

    func testSymlinkedSourceAncestorCannotPublish() async throws {
        let (root, source, queue) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let alias = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: root)
        do {
            _ = try await queue.enqueue(source: alias.appendingPathComponent(source.lastPathComponent), origin: .drop)
            XCTFail("Source ancestor symlink must fail closed")
        } catch { }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("queue").path).isEmpty)
        XCTAssertEqual(try Data(contentsOf: source), Data(repeating: 42, count: 600_000))
    }

    func testSourcePathReplacementDuringCopyCannotPublish() async throws {
        let (root, source, queue) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("original.pdf")
        await queue.observeCopy {
            guard !FileManager.default.fileExists(atPath: original.path) else { return }
            try FileManager.default.moveItem(at: source, to: original)
            // Same byte count and content do not make a replacement inode the
            // same original that a later Move operation may be asked to move.
            try Data(repeating: 42, count: 600_000).write(to: source)
        }
        do {
            _ = try await queue.enqueue(source: source, origin: .fileImport)
            XCTFail("A replaced source path must fail closed")
        } catch IntakeQueue.Failure.changed { }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("queue").path).isEmpty)
        XCTAssertEqual(try Data(contentsOf: original), Data(repeating: 42, count: 600_000))
        XCTAssertEqual(try Data(contentsOf: source), Data(repeating: 42, count: 600_000))
    }

    func testSymlinkedManifestCannotAuthorizeDiscard() async throws {
        let (root, source, queue) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let record = try await queue.enqueue(source: source, origin: .share)
        let folder = root.appendingPathComponent("queue/" + record.id.uuidString)
        let manifest = folder.appendingPathComponent("record.json")
        let outside = root.appendingPathComponent("external.json")
        let originalMetadata = try Data(contentsOf: manifest)
        try FileManager.default.moveItem(at: manifest, to: outside)
        try FileManager.default.createSymbolicLink(at: manifest, withDestinationURL: outside)
        do { try await queue.discard(record); XCTFail("Symlinked proof must not authorize deletion") } catch { }
        XCTAssertEqual(try Data(contentsOf: outside), originalMetadata)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("payload.pdf").path))
        XCTAssertEqual(try Data(contentsOf: source), Data(repeating: 42, count: 600_000))
    }
}
