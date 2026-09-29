import Foundation
import XCTest
import PaperloftKit

final class StoredClassificationProvenanceTests: XCTestCase {
    func testRestoredPartialClassificationsRetainFieldsAndReviewReasons() throws {
        for kind in ["receipt", "invoice", "bill", "not_receipt", "unknown"] {
            let fields = ExtractedFields(kind: kind, vendor: "Example Supplier", date: "2026-06-10",
                total: "40.25", currency: "USD", category: "Office supplies", confidence: 1,
                backend: "system", classificationError: "FoundationModels.LanguageModelError.refusal")
            let stored = StoredReview(ReviewedDocument(source: URL(fileURLWithPath: "/example.pdf"),
                contentHash: "source-hash", text: "Example Supplier\nRECEIPT\nDate: 2026-06-10\nTotal USD 40.25", fields: fields))
            let encoded = try JSONEncoder().encode(stored)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
            XCTAssertNil(object["assessment"], "Restoration must derive assessment from persisted original fields")
            let restored = try JSONDecoder().decode(StoredReview.self, from: encoded)
            XCTAssertEqual(restored.fields, fields)
            XCTAssertEqual(restored.hash, "source-hash")
            XCTAssertTrue(restored.assessment.reasons.contains(.classificationUnavailable), kind)
            XCTAssertFalse(restored.assessment.canAutoFile, kind)
            if kind == "not_receipt" {
                XCTAssertEqual(restored.assessment.reasons, [.notReceipt, .classificationUnavailable])
                XCTAssertNil(restored.assessment.receipt)
            }
        }
    }

    func testExistingSavedNegativeWithPartialClassificationGetsCurrentReasons() throws {
        // Existing schema has original fields, not derived assessment; no migration
        // or re-extraction is needed when this saved inbox is reopened.
        let payload = Data(#"{"hash":"saved-hash","text":"Newsletter","fields":{"kind":"not_receipt","confidence":0.3,"backend":"system","classificationError":"FoundationModels.LanguageModelError.refusal"}}"#.utf8)
        let restored = try JSONDecoder().decode(StoredReview.self, from: payload)
        XCTAssertEqual(restored.assessment.reasons, [.notReceipt, .classificationUnavailable])
        XCTAssertFalse(restored.assessment.canAutoFile)
        XCTAssertEqual(restored.fields.kind, "not_receipt")
        XCTAssertEqual(restored.fields.classificationError, "FoundationModels.LanguageModelError.refusal")
    }
}
