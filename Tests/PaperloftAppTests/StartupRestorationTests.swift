import XCTest
import PaperloftKit

@MainActor final class StartupRestorationTests: XCTestCase {
    private func workspace() throws -> (URL, UserDefaults) {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/StartupRestoration/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "app.paperloft.startup-restoration." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { try FileManager.default.removeItem(at: root); UserDefaults.standard.removePersistentDomain(forName: suite) }
        return (root, defaults)
    }

    private func savedItems(_ root: URL, count: Int) throws -> [InboxItem] {
        let text = "Office Supply Store\n2026-09-20\nPaper 10.00\nPens 2.00\nTOTAL USD 12.00\nThank you for shopping with us."
        let fields = ParserBackend.parse(text)
        let source = root.appendingPathComponent("existing.png")
        try Data([1, 2, 3]).write(to: source)
        let review = StoredReview(ReviewedDocument(source: source, contentHash: "hash", text: text, fields: fields))
        return (0..<count).map { _ in InboxItem(id: UUID(), source: source, review: review, draft: ReceiptDraft(fields), status: "ready") }
    }

    func testConcurrentIntakeWaitsAndEditsCannotOverwriteRestoringSnapshot() async throws {
        let (root, defaults) = try workspace()
        let saved = try savedItems(root, count: 300)
        let inbox = root.appendingPathComponent("inbox.json")
        let original = try JSONEncoder().encode(saved)
        try original.write(to: inbox)
        let incoming = root.appendingPathComponent("incoming.png")
        try Data([4, 5, 6]).write(to: incoming)
        let model = AppModel(support: root, preferences: defaults)
        // A prior displayed value is deliberately present: stale UI actions must
        // not publish it while an authoritative disk snapshot is being restored.
        model.items = [saved[0]]
        let start = Task { await model.start() }
        let deadline = Date().addingTimeInterval(5)
        while !model.busy && Date() < deadline { await Task.yield() }
        XCTAssertTrue(model.busy, "Startup must yield the main actor during restoration")
        var edited = saved[0].draft; edited.vendor = "Must not overwrite restoration"
        model.edit(edited, id: saved[0].id)
        model.setAside(saved[0].id)
        XCTAssertEqual(model.items[0].draft.vendor, saved[0].draft.vendor)
        XCTAssertEqual(model.items[0].status, "ready")
        XCTAssertEqual(try Data(contentsOf: inbox), original)
        async let arrival: Void = model.intake([incoming])
        await start.value
        await arrival
        XCTAssertEqual(model.items.count, 301)
        XCTAssertEqual(Set(model.items.map(\.id)).intersection(Set(saved.map(\.id))).count, 300)
        XCTAssertEqual(model.items.filter { $0.source == incoming }.count, 1)
        XCTAssertFalse(model.items.contains { $0.status == "aside" || $0.draft.vendor == edited.vendor })
        let persisted = try JSONDecoder().decode([InboxItem].self, from: Data(contentsOf: inbox))
        XCTAssertEqual(persisted.count, 301)
    }

    func testCorruptInboxIsUnchangedByIntakeAndEditsThenRepairCanRetry() async throws {
        let (root, defaults) = try workspace()
        let saved = try savedItems(root, count: 1)
        let inbox = root.appendingPathComponent("inbox.json")
        let corrupt = Data("{broken inbox".utf8)
        try corrupt.write(to: inbox)
        let incoming = root.appendingPathComponent("incoming.png")
        try Data([4, 5, 6]).write(to: incoming)
        let model = AppModel(support: root, preferences: defaults)
        await model.intake([incoming])
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertNotNil(model.message)
        XCTAssertEqual(try Data(contentsOf: inbox), corrupt)
        model.items = saved
        var edited = saved[0].draft; edited.vendor = "Must not replace corrupt data"
        model.edit(edited, id: saved[0].id); model.setAside(saved[0].id)
        XCTAssertEqual(try Data(contentsOf: inbox), corrupt)
        XCTAssertEqual(model.items[0].draft.vendor, saved[0].draft.vendor)
        do { try await model.newSampleLibrary(discardInbox: true); XCTFail("Corrupt inbox must block library reset") }
        catch { /* The saved inbox remains the authority until repaired. */ }
        await model.refresh()
        XCTAssertEqual(try Data(contentsOf: inbox), corrupt)
        try JSONEncoder().encode(saved).write(to: inbox, options: .atomic)
        await model.intake([incoming])
        XCTAssertEqual(model.items.count, 2)
        XCTAssertEqual(model.items.first?.id, saved[0].id)
        XCTAssertEqual(try JSONDecoder().decode([InboxItem].self, from: Data(contentsOf: inbox)).count, 2)
    }
    func testDanglingInboxSymlinkIsNotTreatedAsMissingHistory() async throws {
        let (root, defaults) = try workspace()
        let inbox = root.appendingPathComponent("inbox.json")
        let missing = root.appendingPathComponent("missing-history.json")
        try FileManager.default.createSymbolicLink(at: inbox, withDestinationURL: missing)
        let incoming = root.appendingPathComponent("incoming.png")
        try Data([1, 2, 3]).write(to: incoming)
        let model = AppModel(support: root, preferences: defaults)
        await model.intake([incoming])
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertNotNil(model.message)
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: inbox.path), missing.path)
        do { try await model.newSampleLibrary(); XCTFail("Broken history link must block library reset") }
        catch { }
        await model.refresh()
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: inbox.path), missing.path)
    }

}
