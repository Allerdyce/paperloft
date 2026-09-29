import Foundation
import XCTest
import PaperloftKit
import CryptoKit

@MainActor final class WatchedRenameRecoveryTests: XCTestCase {
    func testRenameAfterInboxCommitBeforeScannerAcknowledgmentDoesNotDuplicate() async throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/WatchedRenameRecovery/" + UUID().uuidString)
        let watched = root.appendingPathComponent("watch")
        try FileManager.default.createDirectory(at: watched, withIntermediateDirectories: true)
        let suite = "app.paperloft.rename." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { try? FileManager.default.removeItem(at: root); defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(support: root.appendingPathComponent("support"), preferences: defaults, proEntitlement: { true })
        try await model.installWatchedFolder(at: watched, schedule: false, stableInterval: .milliseconds(10))
        let original = watched.appendingPathComponent("first.pdf")
        try Data("version A".utf8).write(to: original)
        let scanner = try WatchedFolderScanner(root: watched, stateURL: root.appendingPathComponent("probe.json"), minimumStableInterval: .milliseconds(10))
        _ = try await scanner.scan()
        try await Task.sleep(for: .milliseconds(30))
        let initial = try await scanner.scan()
        let first = try XCTUnwrap(initial.candidates.first)
        // Durable Inbox commit occurs, but scanner acknowledgment never happens.
        try await model.queueWatchedCandidate(first)
        let renamed = watched.appendingPathComponent("renamed.pdf")
        try FileManager.default.moveItem(at: original, to: renamed)
        _ = try await scanner.scan()
        try await Task.sleep(for: .milliseconds(30))
        let afterRename = try await scanner.scan()
        let next = try XCTUnwrap(afterRename.candidates.first)
        XCTAssertEqual(next.fileIdentity, first.fileIdentity)
        try await model.queueWatchedCandidate(next)
        XCTAssertEqual(model.items.count, 1)
        // Changing content and later restoring older bytes must still create new deliveries.
        for bytes in ["version B", "version A"] {
            try Data(bytes.utf8).write(to: renamed)
            _ = try await scanner.scan()
            try await Task.sleep(for: .milliseconds(30))
            let changed = try await scanner.scan()
            try await model.queueWatchedCandidate(XCTUnwrap(changed.candidates.first))
        }
        XCTAssertEqual(model.items.count, 3)
        XCTAssertEqual(try Data(contentsOf: renamed), Data("version A".utf8))
        await model.disableWatchedFolder()
    }
    func testNewerInboxProofWinsAfterLedgerWriteFailureIncludingLegacyMigration() async throws {
        for legacy in [false, true] {
            let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            let root = repo.appendingPathComponent("build/WatchedRenameRecovery/" + UUID().uuidString)
            let watched = root.appendingPathComponent("watch"), support = root.appendingPathComponent("support")
            try FileManager.default.createDirectory(at: watched, withIntermediateDirectories: true)
            let suite = "app.paperloft.ledger-retry." + UUID().uuidString
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { try? FileManager.default.removeItem(at: root); defaults.removePersistentDomain(forName: suite) }
            let source = watched.appendingPathComponent("receipt.pdf")
            try Data("A".utf8).write(to: source)
            let scanner = try WatchedFolderScanner(root: watched, stateURL: root.appendingPathComponent("probe.json"), minimumStableInterval: .milliseconds(10))
            func candidate() async throws -> WatchedFolderScanner.Candidate {
                _ = try await scanner.scan()
                try await Task.sleep(for: .milliseconds(30))
                let scan = try await scanner.scan()
                return try XCTUnwrap(scan.candidates.first)
            }
            var model = AppModel(support: support, preferences: defaults, proEntitlement: { true })
            try await model.installWatchedFolder(at: watched, schedule: false, stableInterval: .milliseconds(10))
            try await model.queueWatchedCandidate(candidate())
            let ledger = support.appendingPathComponent("watched-deliveries.json")
            if legacy {
                await model.disableWatchedFolder()
                let key = SHA256.hash(data: Data((watched.path + "\0" + source.lastPathComponent).utf8)).map { String(format: "%02x", $0) }.joined()
                let old = try XCTUnwrap(model.items.first?.watchedDelivery)
                let proof = WatchedDeliveryProof(sourceKey: key, contentHash: old.contentHash, sequence: old.sequence)
                var items = model.items; items[0].watchedDelivery = proof
                try JSONEncoder().encode(items).write(to: support.appendingPathComponent("inbox.json"))
                try JSONEncoder().encode([key: proof]).write(to: ledger)
                model = AppModel(support: support, preferences: defaults, proEntitlement: { true })
                try await model.installWatchedFolder(at: watched, schedule: false, stableInterval: .milliseconds(10))
            }
            let backup = support.appendingPathComponent("ledger-backup.json")
            try FileManager.default.moveItem(at: ledger, to: backup)
            try FileManager.default.createDirectory(at: ledger, withIntermediateDirectories: false)
            try Data("B".utf8).write(to: source)
            do { try await model.queueWatchedCandidate(candidate()); XCTFail("Ledger write must fail") } catch { }
            XCTAssertEqual(model.items.count, 2)
            try FileManager.default.removeItem(at: ledger)
            try FileManager.default.moveItem(at: backup, to: ledger)
            try Data("A".utf8).write(to: source)
            try await model.queueWatchedCandidate(candidate())
            XCTAssertEqual(model.items.count, 3, "Newer pending proof must supersede old A, legacy=\(legacy)")
            XCTAssertEqual(model.items.compactMap(\.watchedDelivery?.sequence), [1, 2, 3])
            await model.disableWatchedFolder()
        }
    }

}
