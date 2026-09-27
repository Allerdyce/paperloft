import Foundation
import Testing
@testable import PaperloftKit

@Test func exactMoneyRejectsRoundingAndOverflow() throws {
    #expect(try Money(decimal: "12.5", currency: "USD").minorUnits == 1250)
    #expect(try Money(decimal: "0.01", currency: "USD").decimal == "0.01")
    for invalid in ["-1", "1.999", "1,23", "NaN", "1e2", ".50", "1.", "9223372036854775808"] {
        #expect(throws: ReceiptError.self) { try Money(decimal: invalid, currency: "USD") }
    }
    #expect(throws: ReceiptError.self) { try Money(minorUnits: 1, currency: "ZZZ") }
}

@Test func currencyPrecisionAndUnicodeFilenames() throws {
    #expect(try Money(decimal: "500", currency: "JPY").decimal == "500")
    #expect(try Money(decimal: "1.234", currency: "KWD").minorUnits == 1234)
    let receipt = try Receipt(vendor: String(repeating: "商", count: 100), date: ReceiptDate(iso8601: "2026-01-02"), totalMinorUnits: 1234, currency: "USD", category: "Office supplies")
    #expect(ReceiptFilename.safeComponent(receipt.vendor).utf8.count <= 80)
    #expect(try ReceiptFilename.name(for: receipt, fileExtension: "JPEG").hasSuffix("_12.34.jpeg"))
    #expect(throws: ReceiptError.self) { try ReceiptFilename.name(for: receipt, fileExtension: "../txt") }
    #expect(try JSONDecoder().decode(Receipt.self, from: JSONEncoder().encode(receipt)) == receipt)
}

@Test func assessmentRequiresAgreementAndValidFields() {
    let fields = ExtractedFields(vendor: "Example Shop", date: "2026-04-12", total: "15.50", tax: "1.00", currency: "USD", category: "Meals", confidence: 0.99, backend: "system")
    var parser = fields; parser.backend = "parser"
    #expect(ExtractionAssessment(fields: fields, parser: parser).canAutoFile)
    parser.total = "14.50"
    let disagreement = ExtractionAssessment(fields: fields, parser: parser)
    #expect(disagreement.receipt != nil)
    #expect(disagreement.reasons.contains(.parserDisagreement))
    var invalid = fields; invalid.date = "2026-02-30"; invalid.confidence = .nan
    let assessment = ExtractionAssessment(fields: invalid, parser: parser)
    #expect(assessment.receipt == nil)
    #expect(assessment.reasons.contains(.invalidDate))
    #expect(assessment.reasons.contains(.lowConfidence))
}
