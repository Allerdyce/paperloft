import XCTest

@MainActor final class IntakeResponsivenessTests: XCTestCase {
    func testUnconfiguredIntakePersistsOneHundredDocuments() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/IntakeProfile/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "app.paperloft.intake-profile." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let model = AppModel(support: root, preferences: defaults)
        let urls = try (0..<100).map { index in
            let url = root.appendingPathComponent("input-\(index).png")
            try Data([1, 2, 3]).write(to: url); return url
        }
        // No engine is configured: isolate synchronous intake/grants/persistence
        // from OCR/extraction and view rendering without a product test hook.
        let started = ProcessInfo.processInfo.systemUptime
        model.intake(urls)
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        print("INTAKE_PROFILE synchronous100Seconds=\(elapsed)")
        XCTAssertEqual(model.items.count, 100)
        XCTAssertFalse(model.processing)
        let persisted = try JSONDecoder().decode([InboxItem].self, from: Data(contentsOf: root.appendingPathComponent("inbox.json")))
        XCTAssertEqual(persisted.count, 100)
    }
}
