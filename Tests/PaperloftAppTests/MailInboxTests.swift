import Foundation
import XCTest

final class MailInboxTests: XCTestCase {
    func testImportNoticesRoundTripAndOldInboxRemainsReadable() throws {
        let item = InboxItem(id: UUID(), source: URL(fileURLWithPath: "/receipt.pdf"), importNotices: ["Original email unchanged", "Ignored image/png"])
        let data = try JSONEncoder().encode(item)
        XCTAssertEqual(try JSONDecoder().decode(InboxItem.self, from: data).importNotices, item.importNotices)
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        old.removeValue(forKey: "importNotices")
        XCTAssertNil(try JSONDecoder().decode(InboxItem.self, from: JSONSerialization.data(withJSONObject: old)).importNotices)
    }
}
