import Foundation
import Testing
@testable import PaperloftKit

@Test(arguments: ["receipt", "invoice", "bill", "not_receipt", "unknown"])
func partialClassificationDiagnosticSurvivesEveryKind(_ kind: String) throws {
    let fields = ExtractedFields(kind: kind, vendor: "Example Supplier", date: "2026-06-10",
        total: "40.25", currency: "USD", category: "Office supplies", confidence: 1,
        backend: "system", classificationError: "FoundationModels.LanguageModelError.refusal")
    let restored = try JSONDecoder().decode(ExtractedFields.self, from: JSONEncoder().encode(fields))
    let assessment = ExtractionAssessment(fields: restored, parser: fields)
    #expect(restored == fields)
    #expect(!assessment.canAutoFile)
    #expect(assessment.reasons.filter { $0 == .classificationUnavailable }.count == 1)
    if let expectedKind = DocumentKind(rawValue: kind) {
        #expect(assessment.receipt?.kind == expectedKind)
        #expect(assessment.receipt?.totalMinorUnits == 4025)
    } else {
        #expect(assessment.receipt == nil)
        #expect(assessment.reasons.contains(kind == "not_receipt" ? .notReceipt : .invalidKind))
    }
}

@Test func successfulNegativeClassificationKeepsExistingAssessment() {
    let fields = ExtractedFields(kind: "not_receipt", confidence: 1, backend: "system")
    let assessment = ExtractionAssessment(fields: fields, parser: fields)
    #expect(assessment.reasons == [.notReceipt])
    #expect(assessment.receipt == nil)
    #expect(!assessment.canAutoFile)
}

@Test func successfulReceiptClassificationStillAllowsValidatedAutoFiling() {
    let fields = ExtractedFields(kind: "receipt", vendor: "Example Supplier", date: "2026-06-10",
        total: "40.25", currency: "USD", category: "Office supplies", confidence: 1, backend: "system")
    let assessment = ExtractionAssessment(fields: fields, parser: fields)
    #expect(assessment.reasons.isEmpty)
    #expect(assessment.canAutoFile)
    #expect(assessment.receipt?.totalMinorUnits == 4025)
}
