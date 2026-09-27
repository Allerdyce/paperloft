import Foundation
import Darwin
import Testing
@testable import PaperloftKit

struct WatchedFolderTests {
    private func workspace() throws -> URL {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/WatchedFolderTests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("watch"), withIntermediateDirectories: true)
        return root
    }
    private func scanner(_ root: URL) throws -> WatchedFolderScanner {
        try WatchedFolderScanner(root: root.appendingPathComponent("watch"), stateURL: root.appendingPathComponent("state.json"), minimumStableInterval: .milliseconds(15))
    }
    private func settle(_ scanner: WatchedFolderScanner) async throws -> WatchedFolderScanner.Scan {
        _ = try await scanner.scan()
        try await Task.sleep(for: .milliseconds(30))
        return try await scanner.scan()
    }

    @Test func partialWritesNeedTwoSpacedStableObservations() async throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("watch/receipt.pdf"), watcher = try scanner(root)
        try Data("partial".utf8).write(to: source)
        #expect(try await watcher.scan().candidates.isEmpty)
        #expect(try await watcher.scan().candidates.isEmpty)
        try await Task.sleep(for: .milliseconds(30))
        try Data("complete receipt".utf8).write(to: source)
        #expect(try await watcher.scan().candidates.isEmpty)
        let result = try await settle(watcher)
        #expect(result.candidates.count == 1)
        #expect(result.candidates[0].data == Data("complete receipt".utf8))
        #expect(try Data(contentsOf: source) == result.candidates[0].data)
        #expect(try await watcher.scan().candidates[0].id == result.candidates[0].id)
    }

    @Test func durableAcknowledgmentSurvivesRestartAndChangedContentRequeues() async throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("watch/receipt.pdf")
        try Data("first".utf8).write(to: source)
        var watcher: WatchedFolderScanner? = try scanner(root)
        let initial = try await settle(watcher!)
        try await watcher!.acknowledge(initial.candidates[0])
        #expect(try await watcher!.scan().candidates.isEmpty)
        watcher = nil
        watcher = try scanner(root)
        #expect(try await settle(watcher!).candidates.isEmpty)
        try Data("second".utf8).write(to: source)
        let changed = try await settle(watcher!)
        #expect(changed.candidates.count == 1)
        #expect(changed.candidates[0].contentHash != initial.candidates[0].contentHash)
        watcher = nil
        watcher = try scanner(root)
        #expect(try await settle(watcher!).candidates.count == 1) // Unacknowledged bytes are never lost.
    }

    @Test func ignoresDirectoriesHiddenAndUnsupportedFilesAndReportsUnsafeOnEveryScan() async throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        let watched = root.appendingPathComponent("watch")
        try Data("outside".utf8).write(to: root.appendingPathComponent("outside.pdf"))
        try FileManager.default.createSymbolicLink(atPath: watched.appendingPathComponent("link.pdf").path, withDestinationPath: "../outside.pdf")
        try FileManager.default.createDirectory(at: watched.appendingPathComponent("folder.pdf"), withIntermediateDirectories: false)
        for name in [".hidden.pdf", "unsupported.exe"] { try Data("ignored".utf8).write(to: watched.appendingPathComponent(name)) }
        let fifo = watched.appendingPathComponent("pipe.pdf")
        #expect(mkfifo(fifo.path, 0o600) == 0)
        let watcher = try scanner(root)
        for _ in 0..<2 {
            let result = try await watcher.scan()
            #expect(result.candidates.isEmpty)
            #expect(Set(result.issues.map(\.filename)) == ["link.pdf", "pipe.pdf"])
        }
        #expect(try Data(contentsOf: root.appendingPathComponent("outside.pdf")) == Data("outside".utf8))
    }

    @Test func corruptHistoryAndUnsafePathsFailClearly() async throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        try Data("not JSON".utf8).write(to: root.appendingPathComponent("state.json"))
        #expect(throws: WatchedFolderScanner.Failure.self) { try scanner(root) }
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("alias"), withDestinationURL: root.appendingPathComponent("watch"))
        #expect(throws: WatchedFolderScanner.Failure.self) {
            try WatchedFolderScanner(root: root.appendingPathComponent("alias"), stateURL: root.appendingPathComponent("other.json"))
        }
        #expect(throws: WatchedFolderScanner.Failure.self) {
            try WatchedFolderScanner(root: root.appendingPathComponent("watch"), stateURL: root.appendingPathComponent("watch/history.json"))
        }
        #expect(throws: WatchedFolderScanner.Failure.self) {
            try WatchedFolderScanner(root: URL(fileURLWithPath: root.path + "/watch/../watch"), stateURL: root.appendingPathComponent("other.json"))
        }
    }

    @Test func failedAcknowledgmentDoesNotConsumeCandidate() async throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        try Data("receipt".utf8).write(to: root.appendingPathComponent("watch/invoice.pdf"))
        let watcher = try scanner(root), result = try await settle(watcher)
        let candidate = try #require(result.candidates.first)
        #expect(chmod(root.path, 0o500) == 0)
        do { try await watcher.acknowledge(candidate); Issue.record("Acknowledgment unexpectedly succeeded in unwritable state directory") }
        catch { #expect(error is WatchedFolderScanner.Failure) }
        #expect(chmod(root.path, 0o700) == 0)
        #expect(try await watcher.scan().candidates.first?.id == candidate.id)
        try await watcher.acknowledge(candidate)
        #expect(try await watcher.scan().candidates.isEmpty)
    }

    @Test func stateTamperingIsNotOverwrittenAndSecondScannerIsExcluded() async throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        try Data("receipt".utf8).write(to: root.appendingPathComponent("watch/invoice.pdf"))
        let watcher = try scanner(root), result = try await settle(watcher)
        #expect(throws: WatchedFolderScanner.Failure.self) { try scanner(root) }
        let state = root.appendingPathComponent("state.json"), corrupt = Data("external change".utf8)
        try corrupt.write(to: state)
        do { try await watcher.acknowledge(result.candidates[0]); Issue.record("Changed state was overwritten") }
        catch { #expect(error is WatchedFolderScanner.Failure) }
        #expect(try Data(contentsOf: state) == corrupt)
        do { _ = try await watcher.scan(); Issue.record("Changed state did not stop scanning") }
        catch { #expect(error is WatchedFolderScanner.Failure) }
        try FileManager.default.removeItem(at: state)
        #expect(try await watcher.scan().candidates.count == 1)
    }

    @Test func acknowledgedFilesDoNotStarveLaterFilesUnderMemoryBudget() async throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        let bytes = Data(repeating: 42, count: 24 * 1024 * 1024)
        for name in ["a.pdf", "b.pdf", "c.pdf"] { try bytes.write(to: root.appendingPathComponent("watch/" + name)) }
        let watcher = try scanner(root), first = try await settle(watcher)
        #expect(first.candidates.count == 2)
        #expect(first.candidates.reduce(0) { $0 + $1.data.count } <= WatchedFolderScanner.maximumScanBytes)
        #expect(first.issues.contains { $0.message.contains("64 MB") })
        for candidate in first.candidates { try await watcher.acknowledge(candidate) }
        let next = try await watcher.scan()
        #expect(next.candidates.count == 1)
        #expect(!Set(first.candidates.map(\.filename)).contains(next.candidates[0].filename))
    }

    @Test func replacedRootAndStateSymlinkAreRejected() async throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        var watcher: WatchedFolderScanner? = try scanner(root)
        try FileManager.default.moveItem(at: root.appendingPathComponent("watch"), to: root.appendingPathComponent("old"))
        try FileManager.default.createDirectory(at: root.appendingPathComponent("watch"), withIntermediateDirectories: false)
        do { _ = try await watcher!.scan(); Issue.record("Replaced root was scanned") }
        catch { #expect(error is WatchedFolderScanner.Failure) }
        watcher = nil
        let outside = root.appendingPathComponent("outside.json")
        try Data("outside unchanged".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("state.json"), withDestinationURL: outside)
        #expect(throws: WatchedFolderScanner.Failure.self) { try scanner(root) }
        #expect(try String(contentsOf: outside, encoding: .utf8) == "outside unchanged")
    }

    @Test func byteAndEntryBudgetsAreBounded() async throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        let huge = root.appendingPathComponent("watch/huge.pdf")
        let descriptor = open(huge.path, O_WRONLY | O_CREAT, 0o600)
        #expect(descriptor >= 0)
        #expect(ftruncate(descriptor, off_t(WatchedFolderScanner.maximumFileBytes + 1)) == 0)
        close(descriptor)
        let watcher = try scanner(root)
        #expect(try await watcher.scan().issues.first?.filename == "huge.pdf")
        for index in 0...WatchedFolderScanner.maximumEntries {
            try Data().write(to: root.appendingPathComponent("watch/ignored-\(index).txt"))
        }
        #expect(try await watcher.scan().issues.contains { $0.message.contains("1,000") })
    }
}
