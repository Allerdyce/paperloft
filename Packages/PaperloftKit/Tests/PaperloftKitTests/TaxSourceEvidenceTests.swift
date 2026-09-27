import Foundation
import Testing
@testable import PaperloftKit

private func assessedTax(_ tax: String?, text: String) -> (ExtractedFields, ExtractionAssessment) {
    var fields = ExtractedFields(vendor: "Synthetic merchant", date: "2026-04-01", total: "237.00", tax: tax,
                                 currency: "USD", category: "Travel", confidence: 1, backend: "system")
    let parser = fields
    TaxSourceEvidence.requireReviewIfNeeded(fields: &fields, text: text)
    return (fields, ExtractionAssessment(fields: fields, parser: parser))
}

@Test func unsupportedTaxInMultipleChargesRequiresReview() {
    let (fields, assessment) = assessedTax("53.76", text: """
    Airfare 200.00
    Transportation Tax: 15.00
    Segment Tax: 8.00
    Security fee 5.00
    Facility fee 9.00
    Total 237.00
    Credit 100.00
    Charged 137.00
    Additional seat 40.00
    Transportation Tax: 3.00
    Total 43.00
    """)
    #expect(fields.tax == "53.76")
    #expect(fields.taxNeedsReview == true)
    #expect(assessment.reasons.contains(.taxSourceUnverified))
    #expect(!assessment.canAutoFile)
}

@Test func explicitZeroAndSingleTaxRemainSupported() {
    for (tax, text) in [("0.00", "Sales Tax $0.00"), ("2.50", "Sales Tax\n$2.50"), ("12.00", "VAT 20% $12.00") ] {
        let (fields, assessment) = assessedTax(tax, text: text)
        #expect(fields.taxNeedsReview == false)
        #expect(assessment.canAutoFile)
    }
}

@Test func combinedTaxesRetainedButNeverAutomaticallyApproved() {
    let (fields, assessment) = assessedTax("8.00", text: "State tax $5.00\nLocal tax $3.00\nTotal tax $8.00")
    #expect(fields.tax == "8.00")
    #expect(fields.taxNeedsReview == true)
    #expect(!assessment.canAutoFile)
}

@Test func RatesInvoiceTitlesAndOtherAmountsDoNotGroundTax() {
    for text in ["Tax 5.00%\nTotal $5.00", "Tax invoice total $5.00", "Subtotal $5.00", "Sales tax $2.00\nTotal $5.00"] {
        #expect(assessedTax("5.00", text: text).0.taxNeedsReview == true)
    }
    #expect(assessedTax(nil, text: "Total $5.00").0.taxNeedsReview == nil)
}

@Test func taxReviewDiagnosticPersistsAndOlderExtractionStillDecodes() throws {
    let fields = assessedTax("5.00", text: "Total $5.00").0
    let restored = try JSONDecoder().decode(ExtractedFields.self, from: JSONEncoder().encode(fields))
    #expect(restored.taxNeedsReview == true)
    let old = Data(#"{"kind":"receipt","confidence":1,"backend":"system"}"#.utf8)
    #expect(try JSONDecoder().decode(ExtractedFields.self, from: old).taxNeedsReview == nil)
}

@Test func surroundingTotalsAndRepeatedTaxLinesStayUnderReview() {
    for text in ["Subtotal before tax 5.00", "Total including VAT 5.00", "Price includes tax 5.00",
                 "Net tax rate 5.00", "Tax $5.00\nTax $5.00"] {
        let (fields, assessment) = assessedTax("5.00", text: text)
        #expect(fields.taxNeedsReview == true)
        #expect(!assessment.canAutoFile)
    }
}

@Test func explicitForeignTaxCurrencyRequiresReview() {
    for text in ["VAT 5.00 EUR", "VAT EUR 5.00", "VAT eur 5.00", "VAT\nEUR 5.00", "VAT €5.00", "Tax £5.00"] {
        #expect(assessedTax("5.00", text: text).0.taxNeedsReview == true)
    }
}
