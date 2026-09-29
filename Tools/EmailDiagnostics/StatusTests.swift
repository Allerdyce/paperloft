import Foundation
import PaperloftKit

@main struct StatusTests {
    @MainActor static func main() async throws {
        let failure = ExtractedFields(kind: "invoice", vendor: "Example Supplier", total: "40.25", confidence: 0.3,
            backend: "system", classificationError: "FoundationModels.LanguageModelError.refusal")
        let partial = EmailDiagnosticCandidate(source: "attachment", attachmentIndex: 0, selected: true,
            contentHash: "source-hash", fields: failure, error: nil)
        let data = try JSONEncoder().encode(partial)
        let restored = try JSONDecoder().decode(EmailDiagnosticCandidate.self, from: data)
        var status = EmailDiagnosticStatus()
        status.record(candidates: [restored, restored], error: nil, sourcePreserved: true)
        precondition(status.exitCode == 1 && status.failedMessages == 1)
        precondition(status.processingErrorMessages == 0 && status.classificationFailureMessages == 1)
        precondition(status.classificationFailureCandidates == 2 && status.sourceChangedMessages == 0)
        precondition(restored.fields?.kind == "invoice" && restored.fields?.total == "40.25")
        precondition(restored.fields?.classificationError == failure.classificationError && restored.selected)
        status.record(candidates: [], error: "materialization failed", sourcePreserved: false)
        precondition(status.failedMessages == 2 && status.processingErrorMessages == 1 && status.sourceChangedMessages == 1)
        precondition(status.classificationFailureCandidates == 2 && status.completedMessages == 2)
        var healthy = EmailDiagnosticStatus()
        let complete = EmailDiagnosticCandidate(source: "body", attachmentIndex: nil, selected: true,
            contentHash: "body-hash", fields: ExtractedFields(kind: "not_receipt", backend: "system"), error: nil)
        healthy.record(candidates: [complete], error: nil, sourcePreserved: true)
        precondition(healthy.exitCode == 0 && healthy.completedMessages == 1 && healthy.failedMessages == 0)
        var unselected = EmailDiagnosticStatus()
        unselected.record(candidates: [EmailDiagnosticCandidate(source: "attachment", attachmentIndex: 1,
            selected: false, contentHash: nil, fields: failure, error: nil)], error: nil, sourcePreserved: true)
        precondition(unselected.exitCode == 1 && unselected.classificationFailureCandidates == 1)
        let receipt = URL(fileURLWithPath: "/receipt.pdf")
        let unresolved = URL(fileURLWithPath: "/unresolved.pdf")
        let body = URL(fileURLWithPath: "/body.pdf")
        var renderedBodies = 0
        for failedKind in ["invoice", "not_receipt"] {
            let prepare: (URL) async throws -> ReviewedDocument = { url in
                let fields = url == unresolved
                    ? ExtractedFields(kind: failedKind, total: "40.25", backend: "system", classificationError: failure.classificationError)
                    : ExtractedFields(kind: "receipt", backend: "system")
                return ReviewedDocument(source: url, contentHash: "original", text: "Receipt", fields: fields)
            }
            let withReceipt = try await MailReviewPreparation.prepare(attachments: [receipt, unresolved], body: body,
                understand: prepare, prepareBody: { _ in renderedBodies += 1 })
            precondition(withReceipt.candidates.map(\.source) == [receipt, unresolved] && renderedBodies == 0)
            precondition(withReceipt.candidates[1].review?.fields.classificationError == failure.classificationError)
            precondition(withReceipt.candidates[1].review?.assessment.canAutoFile == false)
            let withoutReceipt = try await MailReviewPreparation.prepare(attachments: [unresolved], body: body,
                understand: prepare, prepareBody: { _ in renderedBodies += 1 })
            precondition(withoutReceipt.candidates.map(\.source) == [body, unresolved])
            precondition(withoutReceipt.candidates[1].review?.fields.total == "40.25")
            renderedBodies = 0
        }
        print("Diagnostic status and unresolved candidate regressions PASS; raw partial fields retained, failures counted separately, no model invoked.")
    }
}
