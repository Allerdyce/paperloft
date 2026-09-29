import Foundation
import Testing
@testable import PaperloftKit

struct MailFieldHintsTests {
    @Test func absentFieldsUseReviewableHintsAndPreserveLocalDay() throws {
        let envelope = MailEnvelope(headers: ["from": "Example Shop <orders@example-shop.com>", "date": "Tue, 29 Sep 2026 00:15:00 +1400"])
        let fields = ExtractedFields(total: "12.50", currency: "USD", category: "Software", confidence: 1, backend: "system")
        let result = MailFieldHints.apply(to: fields, envelope: envelope)
        #expect(result.vendor == "Example Shop")
        #expect(result.date == "2026-09-29")
        #expect(result.emailDateHint == true)
        #expect(result.emailVendorHint == true)
        let assessment = ExtractionAssessment(fields: result, parser: result)
        #expect(assessment.receipt != nil)
        #expect(!assessment.canAutoFile)
        #expect(assessment.reasons.contains(.emailDateHint))
        #expect(assessment.reasons.contains(.emailVendorHint))
        let restored = try JSONDecoder().decode(ExtractedFields.self, from: JSONEncoder().encode(result))
        #expect(restored == result)
    }

    @Test func neverReplacesDocumentFieldsOrPromotesNonReceipts() {
        let envelope = MailEnvelope(headers: ["from": "Forwarding Company <billing@forwarder.com>", "date": "29 Sep 2026 23:00:00 -1200"])
        let original = ExtractedFields(vendor: "Actual Merchant", date: "2023-08-24", confidence: 0.2, backend: "system")
        #expect(MailFieldHints.apply(to: original, envelope: envelope) == original)
        let newsletter = ExtractedFields(kind: "not_receipt", backend: "system")
        #expect(MailFieldHints.apply(to: newsletter, envelope: envelope) == newsletter)
    }

    @Test func domainFallbackAndInvalidHeaders() {
        let empty = ExtractedFields(backend: "system")
        let result = MailFieldHints.apply(to: empty, envelope: MailEnvelope(headers: ["from": "orders@example-shop.com", "date": "31 Feb 2026 12:00:00 +0000"]))
        #expect(result.vendor == "Example Shop")
        #expect(result.date == nil)
        #expect(result.emailDateHint == nil)
        let invalid = MailFieldHints.apply(to: empty, envelope: MailEnvelope(headers: ["from": "Fake\nName <orders@example.com>", "date": "garbage"]))
        #expect(invalid == empty)
    }
}
