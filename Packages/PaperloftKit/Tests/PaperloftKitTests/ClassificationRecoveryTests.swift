import Foundation
import Testing
@testable import PaperloftKit

@Test func partialClassificationFailurePreservesReviewButNeverAutoFiles() throws {
    let fields = ExtractedFields(kind: "invoice", vendor: "Example Supplier", date: "2026-06-10",
        total: "40.25", currency: "USD", category: "Office supplies", confidence: 1,
        backend: "system", classificationError: "model unavailable")
    let parser = ExtractedFields(date: "2026-06-10", total: "40.25", backend: "parser")
    let restored = try JSONDecoder().decode(ExtractedFields.self, from: JSONEncoder().encode(fields))
    let assessment = ExtractionAssessment(fields: restored, parser: parser)
    #expect(assessment.receipt?.totalMinorUnits == 4025)
    #expect(assessment.receipt?.kind == .invoice)
    #expect(!assessment.canAutoFile)
    #expect(assessment.reasons.contains(.classificationUnavailable))
}

@Test func extractionPayloadWithoutClassificationDiagnosticRemainsReadable() throws {
    let payload = Data(#"{"kind":"receipt","confidence":0.5,"backend":"system"}"#.utf8)
    let fields = try JSONDecoder().decode(ExtractedFields.self, from: payload)
    #expect(fields.classificationError == nil)
    #expect(!ExtractionAssessment(fields: fields, parser: fields).canAutoFile)
}
