import XCTest
import PaperloftKit

/// Second design review (2026-09-30-r2) P1s: undoing a filing returns the document to the Inbox with
/// the confirmed values; Remove can be undone; filing says where it went and selects the next row.
@MainActor final class UndoFeedbackTests: XCTestCase {
    private func model() async throws -> AppModel {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/UndoFeedbackTests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "app.paperloft.undo-feedback." + UUID().uuidString
        addTeardownBlock { try? FileManager.default.removeItem(at: root); UserDefaults.standard.removePersistentDomain(forName: suite) }
        let model = AppModel(support: root, preferences: UserDefaults(suiteName: suite)!, extractionBackend: StubBackend())
        await model.start()
        await model.trySamples(resources: repo.appendingPathComponent("Apps/PaperloftApp"))
        try await waitUntil { model.items.allSatisfy { $0.status == "ready" } }
        return model
    }
    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<200 where !condition() { try await Task.sleep(for: .milliseconds(25)) }
        XCTAssertTrue(condition(), "timed out")
    }

    func testFilingSelectsNextRowAndUndoReturnsConfirmedValuesToInbox() async throws {
        let model = try await model()
        let order = model.items.map(\.id)
        model.inboxListOrder = order
        model.selectedItemID = order[1]
        let originalName = model.items[1].name
        var draft = model.items[1].draft; draft.vendor = "Edited Vendor"; draft.total = "13.75"
        model.edit(draft, id: order[1])
        await model.fileSelected()
        XCTAssertNil(model.message, model.message ?? "")
        XCTAssertEqual(model.selectedItemID, order[2], "the next row in list order is selected")
        XCTAssertTrue(model.notice?.text.hasPrefix("Filed to ") == true, "filing says where it went: \(model.notice?.text ?? "nil")")
        guard case .filing(let batchID) = model.notice?.undo else { return XCTFail("the notice offers Undo") }
        XCTAssertEqual(model.items.count, 4)

        await model.undoFiling(batchID)
        XCTAssertNil(model.message, model.message ?? "")
        XCTAssertEqual(model.items.filter { $0.status != "aside" }.count, 5, "the document is back in the Inbox")
        // Filed this session, so it comes back exactly: same name and place, ready at once (no re-read).
        let returned = model.items[1]
        XCTAssertEqual(returned.name, originalName, "the original name, not the filed one")
        XCTAssertEqual(model.selectedItemID, returned.id)
        XCTAssertEqual(returned.status, "ready", "no second reading")
        XCTAssertNotNil(returned.review)
        XCTAssertEqual(returned.draft.vendor, "Edited Vendor", "the confirmed values come back, not a fresh read")
        XCTAssertEqual(returned.draft.total, "13.75")
        XCTAssertEqual(model.notice?.text, "Returned \(originalName) to the Inbox")
        XCTAssertEqual(model.batches.first { $0.id == batchID }?.state, .undone)
    }

    func testRemoveCanBeUndoneWithTheUndoManagerOrTheNotice() async throws {
        let model = try await model()
        let undo = UndoManager(); undo.groupsByEvent = false
        model.undoManager = undo
        let order = model.items.map(\.id)
        model.inboxListOrder = order
        model.selectedItemID = order[0]
        undo.beginUndoGrouping(); model.setAside(order[0]); undo.endUndoGrouping()
        XCTAssertEqual(model.items.first { $0.id == order[0] }?.status, "aside")
        XCTAssertEqual(model.selectedItemID, order[1], "the next row is selected")
        XCTAssertTrue(model.notice?.text.hasPrefix("Removed ") == true)
        XCTAssertEqual(undo.undoActionName, "Remove from Inbox")
        undo.undo()
        XCTAssertEqual(model.items.first { $0.id == order[0] }?.status, "ready", "Edit › Undo brings it back")
        XCTAssertEqual(model.selectedItemID, order[0])

        // Bulk removal is one step, and the notice's Undo works too.
        undo.beginUndoGrouping(); model.setAside([order[1], order[2]]); undo.endUndoGrouping()
        XCTAssertEqual(model.notice?.text, "Removed 2 documents")
        await model.undoNotice()
        XCTAssertEqual(model.items.filter { [order[1], order[2]].contains($0.id) }.map(\.status), ["ready", "ready"])
    }
}
