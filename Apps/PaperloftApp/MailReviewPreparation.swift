import Foundation
import PaperloftKit

@MainActor enum MailReviewPreparation {
    struct Candidate {
        let source: URL
        let review: ReviewedDocument?
        let issue: String?
    }
    struct Result {
        let candidates: [Candidate]
        let notices: [String]
    }
    static func prepare(attachments: [URL], body: URL?,
                        understand: (URL) async throws -> ReviewedDocument,
                        prepareBody: (URL) async throws -> Void) async throws -> Result {
        var candidates: [Candidate] = []
        var dispositions: [MailCandidateSelection.Disposition] = []
        for source in attachments {
            try Task.checkCancellation()
            do {
                let review = try await understand(source)
                candidates.append(Candidate(source: source, review: review, issue: nil))
                if review.fields.classificationError != nil {
                    dispositions.append(.unresolved)
                } else if DocumentKind(rawValue: review.fields.kind) != nil {
                    dispositions.append(.receipt)
                } else if review.fields.kind == "not_receipt" {
                    dispositions.append(.other)
                } else { dispositions.append(.unresolved) }
            } catch is CancellationError { throw CancellationError() }
            catch {
                candidates.append(Candidate(source: source, review: nil, issue: error.localizedDescription))
                dispositions.append(.unresolved)
            }
        }
        let selected = MailCandidateSelection.select(dispositions, hasBody: body != nil)
        var output = selected.attachmentIndices.map { candidates[$0] }
        if selected.includeBody, let body {
            try Task.checkCancellation()
            do {
                try await prepareBody(body)
                let review = try await understand(body)
                output.insert(Candidate(source: body, review: review, issue: nil), at: 0)
            } catch is CancellationError { throw CancellationError() }
            catch { output.insert(Candidate(source: body, review: nil, issue: error.localizedDescription), at: 0) }
        }
        try Task.checkCancellation()
        var notices: [String] = []
        let omitted = attachments.count - selected.attachmentIndices.count
        if omitted > 0 { notices.append("Skipped \(omitted) attachment(s) classified as non-receipts. The original email is unchanged.") }
        if body != nil && !selected.includeBody { notices.append("Used the receipt attachment(s); the accompanying email body was not added.") }
        return Result(candidates: output, notices: notices)
    }
}
