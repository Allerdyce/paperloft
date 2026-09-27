import XCTest
import PaperloftKit
import Darwin

@MainActor private final class WatchedEntitlementState { var pro = false }

@MainActor final class AppModelWatchedFolderTests: XCTestCase {
    func workspace() throws -> (URL, URL, UserDefaults) {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/WatchedAdapterTests/" + UUID().uuidString)
        let watched = root.appendingPathComponent("watch")
        try FileManager.default.createDirectory(at: watched, withIntermediateDirectories: true)
        let suite = "app.paperloft.watched-tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { try FileManager.default.removeItem(at: root); UserDefaults.standard.removePersistentDomain(forName: suite) }
        return (root.appendingPathComponent("support"), watched, defaults)
    }
    func settle(_ model: AppModel) async throws {
        await model.scanWatchedFolder()
        try await Task.sleep(for: .milliseconds(30))
        await model.scanWatchedFolder()
    }
    func install(_ model: AppModel, _ watched: URL) async throws {
        try await model.installWatchedFolder(at: watched, schedule: false, stableInterval: .milliseconds(10))
    }

    func testStableBytesAreDurablyCopiedAndRequireReviewWithoutChangingSource() async throws {
        let (support, watched, defaults) = try workspace()
        let model = AppModel(support: support, preferences: defaults, proEntitlement: { true })
        let source = watched.appendingPathComponent("receipt.pdf"), bytes = Data("receipt bytes".utf8)
        try bytes.write(to: source)
        try await install(model, watched)
        await model.scanWatchedFolder()
        XCTAssertTrue(model.items.isEmpty)
        try await settle(model)
        XCTAssertEqual(model.items.count, 1)
        XCTAssertEqual(model.items[0].status, "waiting")
        XCTAssertNotNil(model.items[0].watchedDelivery)
        XCTAssertNotEqual(model.items[0].source, source)
        XCTAssertEqual(try Data(contentsOf: model.items[0].source), bytes)
        XCTAssertEqual(try Data(contentsOf: source), bytes)
        XCTAssertTrue(model.allDocuments.isEmpty)
        await model.disableWatchedFolder()
    }

    func testFailedScannerAckAndRestartDoNotDuplicateEvenAfterSetAside() async throws {
        let (support, watched, defaults) = try workspace()
        let model = AppModel(support: support, preferences: defaults, proEntitlement: { true })
        try Data("receipt".utf8).write(to: watched.appendingPathComponent("receipt.pdf"))
        try await install(model, watched)
        let stateFolder = support.appendingPathComponent("Watched-State")
        XCTAssertEqual(chmod(stateFolder.path, 0o500), 0)
        try await settle(model)
        XCTAssertEqual(model.items.count, 1)
        XCTAssertFalse(model.watchedIssues.isEmpty)
        let id = model.items[0].id
        model.setAside(id)
        try await model.newSampleLibrary(discardInbox: true)
        XCTAssertEqual(model.items[0].status, "aside")
        XCTAssertEqual(chmod(stateFolder.path, 0o700), 0)
        await model.disableWatchedFolder()
        let restored = AppModel(support: support, preferences: defaults, proEntitlement: { true })
        try await install(restored, watched)
        try await settle(restored)
        XCTAssertEqual(restored.items.count, 1)
        XCTAssertEqual(restored.items[0].id, id)
        XCTAssertEqual(restored.items[0].status, "aside")
        XCTAssertTrue(restored.watchedIssues.isEmpty)
        await restored.disableWatchedFolder()
    }

    func testInboxCommitBeforeLedgerFailureRecoversExactlyOnce() async throws {
        let (support, watched, defaults) = try workspace()
        let model = AppModel(support: support, preferences: defaults, proEntitlement: { true })
        try Data("receipt".utf8).write(to: watched.appendingPathComponent("receipt.pdf"))
        try await install(model, watched)
        let ledger = support.appendingPathComponent("watched-deliveries.json")
        try FileManager.default.createDirectory(at: ledger, withIntermediateDirectories: false)
        try await settle(model)
        XCTAssertEqual(model.items.count, 1)
        let id = model.items[0].id
        XCTAssertFalse(model.watchedIssues.isEmpty)
        await model.disableWatchedFolder()
        try FileManager.default.removeItem(at: ledger)
        let restored = AppModel(support: support, preferences: defaults, proEntitlement: { true })
        try await install(restored, watched)
        try await settle(restored)
        XCTAssertEqual(restored.items.map(\.id), [id])
        XCTAssertTrue(FileManager.default.fileExists(atPath: ledger.path))
        await restored.disableWatchedFolder()
    }

    func testContentChangesIncludingReturnToOlderBytesAreNewDeliveries() async throws {
        let (support, watched, defaults) = try workspace()
        let model = AppModel(support: support, preferences: defaults, proEntitlement: { true })
        let source = watched.appendingPathComponent("receipt.pdf")
        try await install(model, watched)
        for text in ["version A", "version B", "version A"] {
            try Data(text.utf8).write(to: source)
            try await settle(model)
        }
        XCTAssertEqual(model.items.count, 3)
        XCTAssertEqual(model.items.compactMap(\.watchedDelivery?.sequence), [1, 2, 3])
        await model.disableWatchedFolder()
    }

    func testFreeEntitlementAndDisablePreventIntakeAndMailRemainsPending() async throws {
        let (support, watched, defaults) = try workspace()
        let entitlement = WatchedEntitlementState()
        let model = AppModel(support: support, preferences: defaults, proEntitlement: { entitlement.pro })
        do { try await install(model, watched); XCTFail("Free account enabled watcher") } catch { }
        XCTAssertFalse(model.watchedEnabled)
        entitlement.pro = true
        try await install(model, watched)
        try Data("mail".utf8).write(to: watched.appendingPathComponent("receipt.eml"))
        try await settle(model)
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertTrue(model.watchedIssues.contains { $0.contains("unacknowledged") })
        entitlement.pro = false
        try Data("receipt".utf8).write(to: watched.appendingPathComponent("receipt.pdf"))
        try await settle(model)
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertTrue(model.watchedStatus.contains("Pro"))
        await model.disableWatchedFolder()
        entitlement.pro = true
        try await settle(model)
        XCTAssertTrue(model.items.isEmpty)
    }

    func testOverlappingDisableAndInstallCannotClearNewestFolder() async throws {
        let (support, watched, defaults) = try workspace()
        let model = AppModel(support: support, preferences: defaults, proEntitlement: { true })
        let newer = watched.deletingLastPathComponent().appendingPathComponent("newer")
        try FileManager.default.createDirectory(at: newer, withIntermediateDirectories: true)
        try await model.installWatchedFolder(at: watched)
        let disabling = Task { await model.disableWatchedFolder() }
        let disablingDeadline = ContinuousClock.now.advanced(by: .seconds(2))
        while model.watchedEnabled && ContinuousClock.now < disablingDeadline { await Task.yield() }
        XCTAssertFalse(model.watchedEnabled)
        try await model.installWatchedFolder(at: newer, schedule: false)
        await disabling.value
        XCTAssertTrue(model.watchedEnabled)
        XCTAssertEqual(model.watchedFolderURL, newer)
        await model.disableWatchedFolder()
        let installing = Task { try await model.installWatchedFolder(at: watched) }
        let installingDeadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !model.watchedConfigurationPending && !model.watchedEnabled && ContinuousClock.now < installingDeadline { await Task.yield() }
        XCTAssertTrue(model.watchedConfigurationPending || model.watchedEnabled)
        await model.disableWatchedFolder()
        do { try await installing.value } catch is CancellationError { }
        XCTAssertFalse(model.watchedEnabled)
    }

    func testOversizedDeliveryHistoryBlocksStartupWithoutChangingInbox() async throws {
        let (support, watched, defaults) = try workspace()
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let inbox = support.appendingPathComponent("inbox.json"), original = Data("[]".utf8)
        try original.write(to: inbox)
        let fd = open(support.appendingPathComponent("watched-deliveries.json").path, O_WRONLY | O_CREAT, 0o600)
        XCTAssertGreaterThanOrEqual(fd, 0)
        XCTAssertEqual(ftruncate(fd, 9 * 1024 * 1024), 0); close(fd)
        let model = AppModel(support: support, preferences: defaults, proEntitlement: { true })
        do { try await install(model, watched); XCTFail("Oversized history was ignored") } catch { }
        XCTAssertEqual(try Data(contentsOf: inbox), original)
        XCTAssertFalse(model.watchedEnabled)
    }

    func testBrokenLedgerSymlinkIsNotTreatedAsMissingHistory() async throws {
        let (support, watched, defaults) = try workspace()
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let ledger = support.appendingPathComponent("watched-deliveries.json")
        try FileManager.default.createSymbolicLink(atPath: ledger.path, withDestinationPath: "missing-history.json")
        let model = AppModel(support: support, preferences: defaults, proEntitlement: { true })
        do { try await install(model, watched); XCTFail("Broken ledger symlink was ignored") } catch { }
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: ledger.path), "missing-history.json")
        XCTAssertFalse(model.watchedEnabled)
    }

    func testFailedInboxCommitLeavesSourceAndAllowsRetry() async throws {
        let (support, watched, defaults) = try workspace()
        let model = AppModel(support: support, preferences: defaults, proEntitlement: { true })
        let source = watched.appendingPathComponent("receipt.pdf")
        try Data("receipt".utf8).write(to: source)
        try await install(model, watched)
        let inbox = support.appendingPathComponent("inbox.json")
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: false)
        try await settle(model)
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertFalse(model.watchedIssues.isEmpty)
        XCTAssertEqual(try Data(contentsOf: source), Data("receipt".utf8))
        try FileManager.default.removeItem(at: inbox)
        await model.scanWatchedFolder()
        XCTAssertEqual(model.items.count, 1)
        await model.disableWatchedFolder()
    }
}
