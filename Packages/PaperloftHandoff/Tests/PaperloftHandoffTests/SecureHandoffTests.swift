import Foundation
import Darwin
import XCTest
@testable import PaperloftHandoff

final class SecureHandoffTests: XCTestCase, @unchecked Sendable {
    private func workspace() throws -> URL {
        let base = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/test-data/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: base) }
        return base
    }

    func testConsumerLeaseExcludesActorsAndProcessesAndReleases() async throws {
        let root = try workspace()
        let one = try HandoffStore(containerURL: root), two = try HandoffStore(containerURL: root)
        var lease = try await one.acquireConsumerLease()
        XCTAssertNotNil(lease)
        let blocked = try await two.acquireConsumerLease()
        XCTAssertNil(blocked)
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        child.arguments = ["-c", "import fcntl,sys\nf=open(sys.argv[1],'r+')\ntry:\n fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)\nexcept BlockingIOError:\n sys.exit(0)\nsys.exit(1)", root.appendingPathComponent("Inbox/.consumer.lock").path]
        try child.run(); child.waitUntilExit()
        XCTAssertEqual(child.terminationStatus, 0)
        withExtendedLifetime(lease) {}
        lease = nil
        let next = try await two.acquireConsumerLease()
        XCTAssertNotNil(next)
        withExtendedLifetime(next) {}
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Inbox/.consumer.lock").path))
    }

    func testConsumerLeaseRejectsSymlinkWithoutTouchingTarget() async throws {
        let root = try workspace(), store = try HandoffStore(containerURL: root)
        let target = root.appendingPathComponent("original.pdf"), original = Data("unchanged".utf8)
        try original.write(to: target)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("Inbox/.consumer.lock"), withDestinationURL: target)
        do { _ = try await store.acquireConsumerLease(); XCTFail("Symlink lock must fail closed") }
        catch { XCTAssertEqual(error as? HandoffError, .unsafePath) }
        XCTAssertEqual(try Data(contentsOf: target), original)
    }

    func testCopyRejectsSymlinkAndFIFOAndDoesNotOverwriteDestination() throws {
        let root = try workspace(), source = root.appendingPathComponent("source.pdf")
        let original = Data("synthetic receipt".utf8)
        try original.write(to: source)
        let link = root.appendingPathComponent("link.pdf")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        XCTAssertThrowsError(try HandoffFileCopy.copy(source: link, destination: root.appendingPathComponent("copy.pdf"))) {
            XCTAssertEqual($0 as? HandoffError, .unsafePath)
        }
        let directoryLink = root.appendingPathComponent("linked-parent")
        try FileManager.default.createSymbolicLink(at: directoryLink, withDestinationURL: root)
        XCTAssertThrowsError(try HandoffFileCopy.copy(source: directoryLink.appendingPathComponent("source.pdf"), destination: root.appendingPathComponent("copy.pdf"))) {
            XCTAssertEqual($0 as? HandoffError, .unsafePath)
        }
        let fifo = root.appendingPathComponent("pipe.pdf")
        XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
        XCTAssertThrowsError(try HandoffFileCopy.copy(source: fifo, destination: root.appendingPathComponent("copy.pdf"))) {
            XCTAssertEqual($0 as? HandoffError, .unsafePath)
        }
        XCTAssertThrowsError(try HandoffFileCopy.copy(source: source, destination: link))
        XCTAssertEqual(try Data(contentsOf: source), original)
    }

    func testSwappedSourceSymlinkNeverReadsReplacement() throws {
        let root = try workspace(), source = root.appendingPathComponent("source.pdf")
        let replacement = root.appendingPathComponent("replacement.pdf"), copy = root.appendingPathComponent("copy.pdf")
        let original = Data("the opened receipt".utf8), unexpected = Data("must never be copied".utf8)
        try original.write(to: source); try unexpected.write(to: replacement)
        XCTAssertThrowsError(try HandoffFileCopy.copy(source: source, destination: copy, didOpen: {
            try FileManager.default.moveItem(at: source, to: root.appendingPathComponent("moved.pdf"))
            try FileManager.default.createSymbolicLink(at: source, withDestinationURL: replacement)
        })) { error in
            // Rename changes inode ctime; otherwise the final no-follow reopen rejects it.
            XCTAssertTrue([HandoffError.sourceChanged, .unsafePath].contains(error as? HandoffError ?? .invalidItem))
        }
        XCTAssertEqual(try Data(contentsOf: copy), original)
        XCTAssertEqual(try Data(contentsOf: replacement), unexpected)
    }

    func testOpenedFileMutationIsRejected() throws {
        let root = try workspace(), source = root.appendingPathComponent("source.pdf")
        try Data("before".utf8).write(to: source)
        XCTAssertThrowsError(try HandoffFileCopy.copy(source: source, destination: root.appendingPathComponent("copy.pdf"), didOpen: {
            let writer = try FileHandle(forWritingTo: source)
            try writer.seekToEnd(); try writer.write(contentsOf: Data(" changed".utf8)); try writer.close()
        })) { XCTAssertEqual($0 as? HandoffError, .sourceChanged) }
    }
}
