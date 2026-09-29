import Foundation
import XCTest
import PaperloftKit

@MainActor final class MailReviewPreparationTests: XCTestCase {
    func testInvoiceAndBillSuppressBodyAndAreReadExactlyOnce() async throws {
        let invoice = URL(fileURLWithPath: "/invoice.pdf"), bill = URL(fileURLWithPath: "/bill.pdf")
        let terms = URL(fileURLWithPath: "/terms.pdf"), body = URL(fileURLWithPath: "/body.pdf")
        var reads: [URL] = []; var renders = 0
        let result = try await MailReviewPreparation.prepare(attachments: [invoice, terms, bill], body: body, understand: { url in
            reads.append(url)
            return ReviewedDocument(source: url, contentHash: "hash", text: "", fields: ExtractedFields(kind: url == terms ? "not_receipt" : url == bill ? "bill" : "invoice", backend: "stub"))
        }, prepareBody: { _ in renders += 1 })
        XCTAssertEqual(reads, [invoice, terms, bill]); XCTAssertEqual(renders, 0)
        XCTAssertEqual(result.candidates.map(\.source), [invoice, bill])
        XCTAssertEqual(result.notices.count, 2)
    }
    func testUnreadableAttachmentRemainsVisibleWhileNonReceiptFallsBackToBody() async throws {
        let broken = URL(fileURLWithPath: "/broken.pdf"), other = URL(fileURLWithPath: "/other.pdf"), body = URL(fileURLWithPath: "/body.pdf")
        var rendered: [URL] = []
        let result = try await MailReviewPreparation.prepare(attachments: [broken, other], body: body, understand: { url in
            if url == broken { throw CocoaError(.fileReadCorruptFile) }
            return ReviewedDocument(source: url, contentHash: "hash", text: "", fields: ExtractedFields(kind: "not_receipt", backend: "stub"))
        }, prepareBody: { rendered.append($0) })
        XCTAssertEqual(result.candidates.map(\.source), [body, broken])
        XCTAssertNotNil(result.candidates.last?.issue)
        XCTAssertEqual(rendered, [body])
    }
    func testCancellationDoesNotBecomeAnUnresolvedReceipt() async throws {
        do {
            _ = try await MailReviewPreparation.prepare(attachments: [URL(fileURLWithPath: "/receipt.pdf")], body: nil, understand: { _ in throw CancellationError() }, prepareBody: { _ in })
            XCTFail("Cancellation must propagate")
        } catch is CancellationError { }
    }
}
