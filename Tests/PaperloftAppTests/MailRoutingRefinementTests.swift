import Foundation
import XCTest
import PaperloftKit

/// Routing after the optional document-type refinement fails. A successful read with a
/// financial kind keeps the attachment and suppresses the cover body; the failure is
/// preserved and still blocks auto-filing. Negative, invalid and unreadable results stay
/// unresolved and visible.
@MainActor final class MailRoutingRefinementTests: XCTestCase {
    private let refusal = "FoundationModels.LanguageModelError.refusal"
    private let attachment = URL(fileURLWithPath: "/attachment.pdf")
    private let body = URL(fileURLWithPath: "/body.pdf")

    private func run(kinds: [URL: (kind: String, error: String?)], attachments: [URL],
                     failing: Set<URL> = []) async throws -> (MailReviewPreparation.Result, reads: [URL], renders: [URL]) {
        var reads: [URL] = [], renders: [URL] = []
        let result = try await MailReviewPreparation.prepare(attachments: attachments, body: body, understand: { url in
            reads.append(url)
            if failing.contains(url) { throw CocoaError(.fileReadCorruptFile) }
            let entry = kinds[url] ?? (kind: "not_receipt", error: nil)
            let fields = ExtractedFields(kind: entry.kind, vendor: "Example Supplier", date: "2026-09-01", total: "40.25",
                                         currency: "USD", category: "Office", confidence: 0.3, backend: "system",
                                         classificationError: entry.error)
            return ReviewedDocument(source: url, contentHash: "hash", text: "", fields: fields)
        }, prepareBody: { renders.append($0) })
        return (result, reads, renders)
    }

    func testFinancialKindsRouteAsReceiptsWithOrWithoutRefinementFailure() async throws {
        for kind in ["receipt", "invoice", "bill"] {
            for error in [nil, refusal] {
                let (result, reads, renders) = try await run(kinds: [attachment: (kind, error)], attachments: [attachment])
                XCTAssertEqual(result.candidates.map(\.source), [attachment], "\(kind) error=\(error ?? "nil")")
                XCTAssertEqual(reads, [attachment], "attachment read exactly once, body never read")
                XCTAssertEqual(renders, [], "cover body must not be rendered for \(kind)")
                XCTAssertTrue(result.notices.contains { $0.contains("email body was not added") })
                let review = try XCTUnwrap(result.candidates.first?.review)
                XCTAssertEqual(review.fields.kind, kind)
                XCTAssertEqual(review.fields.classificationError, error)
                XCTAssertFalse(review.assessment.canAutoFile)
                XCTAssertEqual(review.assessment.reasons.contains(.classificationUnavailable), error != nil)
            }
        }
    }

    func testNegativeWithRefinementFailureStaysVisibleAndAddsBody() async throws {
        let (result, reads, renders) = try await run(kinds: [attachment: ("not_receipt", refusal)], attachments: [attachment])
        XCTAssertEqual(result.candidates.map(\.source), [body, attachment])
        XCTAssertEqual(renders, [body]); XCTAssertEqual(reads, [attachment, body])
        let review = try XCTUnwrap(result.candidates.last?.review)
        XCTAssertEqual(review.fields.classificationError, refusal)
        XCTAssertEqual(review.assessment.reasons, [.notReceipt, .classificationUnavailable])
        XCTAssertFalse(review.assessment.canAutoFile)
    }

    func testConfirmedNegativeWithoutFailureIsStillOmitted() async throws {
        let (result, _, renders) = try await run(kinds: [attachment: ("not_receipt", nil)], attachments: [attachment])
        XCTAssertEqual(result.candidates.map(\.source), [body])
        XCTAssertEqual(renders, [body])
    }

    func testInvalidKindWithOrWithoutFailureRemainsUnresolved() async throws {
        for error in [nil, refusal] {
            let (result, _, renders) = try await run(kinds: [attachment: ("statement", error)], attachments: [attachment])
            XCTAssertEqual(result.candidates.map(\.source), [body, attachment])
            XCTAssertEqual(renders, [body])
            let review = try XCTUnwrap(result.candidates.last?.review)
            XCTAssertTrue(review.assessment.reasons.contains(.invalidKind))
            XCTAssertEqual(review.fields.classificationError, error)
        }
    }

    func testReadFailureRemainsUnresolved() async throws {
        let (result, _, renders) = try await run(kinds: [:], attachments: [attachment], failing: [attachment])
        XCTAssertEqual(result.candidates.map(\.source), [body, attachment])
        XCTAssertNil(result.candidates.last?.review)
        XCTAssertNotNil(result.candidates.last?.issue)
        XCTAssertEqual(renders, [body])
    }

    func testFailedRefinementInvoiceKeepsFailedNegativeVisibleAndDropsConfirmedNegative() async throws {
        let failedNegative = URL(fileURLWithPath: "/failed-negative.pdf"), terms = URL(fileURLWithPath: "/terms.pdf")
        let (result, reads, renders) = try await run(
            kinds: [attachment: ("invoice", refusal), failedNegative: ("not_receipt", refusal), terms: ("not_receipt", nil)],
            attachments: [attachment, failedNegative, terms])
        XCTAssertEqual(result.candidates.map(\.source), [attachment, failedNegative])
        XCTAssertEqual(reads, [attachment, failedNegative, terms]); XCTAssertEqual(renders, [])
        XCTAssertTrue(result.candidates.allSatisfy { $0.review?.fields.classificationError == refusal })
        XCTAssertTrue(result.candidates.allSatisfy { $0.review?.assessment.canAutoFile == false })
    }
}
