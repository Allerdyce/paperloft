import XCTest
import PaperloftKit

/// Run alone on a quiet machine. Samples main-actor availability while delivering maximum-size input.
@MainActor final class AppModelWatchedPerformanceTests: XCTestCase {
    func testWorstBoundedDeliveryWallTime() async throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/WatchedPerformance/" + UUID().uuidString)
        let support = root.appendingPathComponent("support"), watched = root.appendingPathComponent("watch")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: watched, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "app.paperloft.watched-performance." + UUID().uuidString
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        var history: [String: WatchedDeliveryProof] = [:]
        for index in 1...24_999 {
            let key = String(format: "%064x", index)
            history[key] = WatchedDeliveryProof(sourceKey: key, contentHash: String(repeating: "a", count: 64), sequence: Int64(index))
        }
        try JSONEncoder().encode(history).write(to: support.appendingPathComponent("watched-deliveries.json"))
        let model = AppModel(support: support, preferences: preferences, proEntitlement: { true })
        var maximumGap = 0.0
        let heartbeat = Task { @MainActor in
            var previous = ContinuousClock.now
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(10)) } catch { break }
                let now = ContinuousClock.now, elapsed = previous.duration(to: now)
                let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                maximumGap = max(maximumGap, seconds); previous = now
            }
        }
        defer { heartbeat.cancel() }
        await Task.yield()
        try await model.installWatchedFolder(at: watched, schedule: false, stableInterval: .milliseconds(10))
        let source = watched.appendingPathComponent("large.pdf")
        var timings: [Double] = []
        for version in 1...3 {
            try await Task.detached {
                try Data(repeating: UInt8(version), count: WatchedFolderScanner.maximumFileBytes).write(to: source)
            }.value
            await model.scanWatchedFolder()
            try await Task.sleep(for: .milliseconds(30))
            let began = ContinuousClock.now
            await model.scanWatchedFolder()
            let elapsed = began.duration(to: .now)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            timings.append(seconds)
            XCTAssertEqual(model.items.count, version)
            XCTAssertTrue(model.watchedIssues.isEmpty)
        }
        try await Task.sleep(for: .milliseconds(20))
        heartbeat.cancel(); await heartbeat.value
        await model.disableWatchedFolder()
        print("WATCHED_DELIVERY_WALL_SECONDS=\(timings) MAIN_ACTOR_MAX_GAP_SECONDS=\(maximumGap)")
        XCTAssertLessThan(maximumGap, 0.250, "32 MB delivery plus near-capacity ledger stalled the main actor; move storage work off main actor before claiming responsiveness")
    }
}
