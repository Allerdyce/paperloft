import XCTest
import PaperloftKit

final class StoredReviewAssessmentTests: XCTestCase {
    func testExistingInboxSchemaRestoresAssessmentAndKeepsDraftIndependent() throws {
        let text = "Coffee Shop\n2026-09-20\nTOTAL USD 12.00"
        var fields = ParserBackend.parse(text)
        fields.backend = "system"; fields.confidence = 0.99
        let reviewed = ReviewedDocument(source: URL(fileURLWithPath: "/sample.pdf"), contentHash: "hash", text: text, fields: fields)
        let stored = StoredReview(reviewed)
        let encoded = try JSONEncoder().encode(stored)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(object["assessment"], "Derived assessment must not change the legacy inbox schema")
        var restored = try JSONDecoder().decode(StoredReview.self, from: encoded)
        XCTAssertEqual(restored.assessment.reasons, reviewed.assessment.reasons)
        XCTAssertEqual(restored.assessment.canAutoFile, reviewed.assessment.canAutoFile)
        restored.duplicate = "existing.pdf"
        var item = InboxItem(id: UUID(), source: reviewed.source, review: restored)
        item.draft.vendor = "User correction"
        XCTAssertEqual(item.review?.assessment.reasons, reviewed.assessment.reasons)
        XCTAssertEqual(item.review?.fields.vendor, fields.vendor)
    }

    func testDifferentImmutableReviewsNeverShareStaleAssessment() throws {
        let text = "Shop\n2026-09-20\nTOTAL USD 12.00"
        var fields = ParserBackend.parse(text)
        fields.kind = "not_receipt"
        let first = StoredReview(ReviewedDocument(source: URL(fileURLWithPath: "/first.pdf"), contentHash: "same", text: text, fields: fields))
        fields.kind = "receipt"; fields.confidence = 0.1
        let second = StoredReview(ReviewedDocument(source: URL(fileURLWithPath: "/second.pdf"), contentHash: "same", text: text, fields: fields))
        XCTAssertEqual(first.assessment.reasons, [.notReceipt])
        XCTAssertFalse(second.assessment.reasons.contains(.notReceipt))
        XCTAssertTrue(second.assessment.reasons.contains(.lowConfidence))
        let restored = try JSONDecoder().decode(StoredReview.self, from: JSONEncoder().encode(second))
        XCTAssertEqual(restored.assessment.reasons, second.assessment.reasons)
    }
}
