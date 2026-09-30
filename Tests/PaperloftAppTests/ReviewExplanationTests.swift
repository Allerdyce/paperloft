import XCTest
import PaperloftKit

/// QA-04: Issue reasons without a field message are explained in plain words.
final class ReviewExplanationTests: XCTestCase {
    func testReasonsMapToPlainExplanations() {
        XCTAssertNil(ReviewExplanation.summary(for: []))
        XCTAssertNil(ReviewExplanation.summary(for: [.missingVendor]), "field-level reasons have their own messages")
        let summary = ReviewExplanation.summary(for: [.parserDisagreement, .classificationUnavailable])
        XCTAssertEqual(summary, "Worth a check: Two independent readings of this document didn't agree. The document type couldn't be confirmed. Compare the fields with the document, then confirm.")
        XCTAssertTrue(ReviewExplanation.summary(for: [.emailVendorHint])?.contains("came from the email") == true)
        XCTAssertFalse(ReviewExplanation.summary(for: [.lowConfidence, .taxSourceUnverified])?.contains("!") ?? true, "calm copy")
    }
}
