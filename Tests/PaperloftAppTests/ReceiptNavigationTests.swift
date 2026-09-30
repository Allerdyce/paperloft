import XCTest
import PaperloftKit

/// Receipt › Next/Previous Document follow the Inbox list as filtered on screen.
@MainActor final class ReceiptNavigationTests: XCTestCase {
    private func model(itemCount: Int) -> AppModel {
        let suite = "app.paperloft.receipt-navigation." + UUID().uuidString
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReceiptNavigationTests-" + UUID().uuidString)
        let model = AppModel(support: root, preferences: UserDefaults(suiteName: suite)!, extractionBackend: StubBackend())
        model.items = (0..<itemCount).map { InboxItem(id: UUID(), source: URL(fileURLWithPath: "/doc-\($0).pdf")) }
        return model
    }

    func testNavigationClampsAndSkipsRemovedItems() {
        let model = model(itemCount: 3)
        let ids = model.items.map(\.id)
        model.items[1].status = "aside"
        model.selectedItemID = ids[0]
        model.selectAdjacentItem(1)
        XCTAssertEqual(model.selectedItemID, ids[2], "removed documents are skipped")
        model.selectAdjacentItem(1)
        XCTAssertEqual(model.selectedItemID, ids[2], "Next stops at the last document")
        model.selectAdjacentItem(-1); model.selectAdjacentItem(-1)
        XCTAssertEqual(model.selectedItemID, ids[0], "Previous stops at the first document")
    }

    func testNavigationStaysWithinTheFilteredList() {
        let model = model(itemCount: 4)
        let ids = model.items.map(\.id)
        model.inboxListOrder = [ids[3], ids[1], UUID()]
        model.selectedItemID = ids[3]
        model.selectAdjacentItem(1)
        XCTAssertEqual(model.selectedItemID, ids[1], "Next follows the on-screen order, not the Inbox's")
        model.selectAdjacentItem(1)
        XCTAssertEqual(model.selectedItemID, ids[1], "documents no longer in the Inbox are ignored")
    }
}
