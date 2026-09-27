import XCTest

@MainActor final class WatchedStartupSafetyTests: XCTestCase {
    func testCorruptDeliveryHistoryBlocksInboxMutationUntilRepair() async throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/WatchedStartup/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "app.paperloft.watched-startup." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { try FileManager.default.removeItem(at: root); UserDefaults.standard.removePersistentDomain(forName: suite) }
        let source = root.appendingPathComponent("saved.pdf")
        try Data("synthetic input".utf8).write(to: source)
        var saved = InboxItem(id: UUID(), source: source)
        saved.draft.vendor = "Preserved vendor"
        let inbox = root.appendingPathComponent("inbox.json")
        let bytes = try JSONEncoder().encode([saved]); try bytes.write(to: inbox)
        let history = root.appendingPathComponent("watched-deliveries.json")
        try Data("corrupt history".utf8).write(to: history)
        let model = AppModel(support: root, preferences: defaults)
        await model.start()
        XCTAssertNotNil(model.message)
        var changed = saved.draft; changed.vendor = "Must not replace saved data"
        model.edit(changed, id: saved.id); model.setAside(saved.id)
        XCTAssertEqual(try Data(contentsOf: inbox), bytes)
        XCTAssertEqual(model.items.first?.draft.vendor, saved.draft.vendor)
        XCTAssertEqual(model.items.first?.status, "waiting")
        try Data("{}".utf8).write(to: history, options: .atomic)
        await model.start()
        model.edit(changed, id: saved.id)
        let restored = try JSONDecoder().decode([InboxItem].self, from: Data(contentsOf: inbox))
        XCTAssertEqual(restored.first?.draft.vendor, changed.vendor)
        XCTAssertEqual(restored.first?.id, saved.id)
    }
}
