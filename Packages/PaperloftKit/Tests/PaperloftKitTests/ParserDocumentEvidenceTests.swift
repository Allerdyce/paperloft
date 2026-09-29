import Foundation
import Testing
@testable import PaperloftKit

struct ParserDocumentEvidenceTests {
    @Test func incidentalFinancialWordsDoNotClassifyTermsOrCoverNotes() {
        for text in [
            "Terms and conditions\nThis is not a receipt or invoice.\nContact support for help.",
            "Hello customer,\nYour receipt is attached.\nThank you.",
            "Please read the invoice instructions before requesting a bill.",
            "Invoice attached\nPlease see the enclosed document.",
            "Bill of rights\nReceipt of this notice confirms delivery.",
            "This is not a receipt or  invoice",
            "Read more about  invoice"
        ] { #expect(ParserBackend.parse(text).kind == "not_receipt") }
    }
    @Test func explicitNonFinancialHeadingWinsEvenWithPricesAndTotals() {
        for heading in ["Terms and conditions", "Quotation", "Estimate", "Price list", "Menu"] {
            #expect(ParserBackend.parse("\(heading)\nExample price\nTotal USD 125.00\nRequest an invoice after ordering.").kind == "not_receipt")
        }
    }
    @Test func paidInvoiceAndItsTermsRetainInvoiceType() {
        let fields = ParserBackend.parse("Example Services\nTAX INVOICE #INV-284\nIssued: 2026-05-06\nTotal USD 80.00\nPAID\nTerms and conditions\nKeep this payment receipt for your records.")
        #expect(fields.kind == "invoice"); #expect(fields.total == "80")
        for heading in ["PAID INVOICE", "Paid tax invoice", "INVOICE - PAID", "INVOICE (PAID)", "INVOICE — PAID", "INVOICE (UNPAID)", "Unpaid invoice"] {
            #expect(ParserBackend.parse("Example Services\n\(heading)\nTotal USD 80.00").kind == "invoice")
            #expect(ParserBackend.parse("Example Services\n\(heading)\nUnreadable amount").kind == "invoice")
        }
        #expect(ParserBackend.parse("Example Services  INVOICE\nTotal USD 80.00\nReceipt included with payment").kind == "invoice")
        #expect(ParserBackend.parse("This Is Not A Receipt Or  INVOICE\nTotal USD 12.00").kind != "invoice")
        #expect(ParserBackend.parse("Example Shop\nDate: 2026-05-06\nTotal USD 12.00\nTerms and conditions\nAsk for an invoice when needed.").kind == "receipt")
    }
    @Test func documentHeadingsAndTransactionEvidenceRemainRecognized() {
        for (heading, kind) in [("RECEIPT", "receipt"), ("Payment confirmation", "receipt"), ("Invoice INV-482", "invoice"), ("Utility bill", "bill"), ("Account statement", "bill")] {
            #expect(ParserBackend.parse("Example Merchant\n\(heading)\nDate: 2026-04-08\nTotal USD 12.00").kind == kind)
        }
        #expect(ParserBackend.parse("Example Merchant\nDate: 2026-04-08\nAmount paid USD 12.00").kind == "receipt")
        #expect(ParserBackend.parse("Example Merchant\nReceipt\nUnreadable amount").kind == "receipt")
    }
    @Test func emptyRecognizedTextThrowsBeforeBackendAndPreservesSource() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/EmptyRecognition/" + UUID().uuidString)
        let library = root.appendingPathComponent("library")
        try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("input.pdf"), bytes = try MailImport.bodyPDF("A readable receipt\nTotal USD 12.00")
        try bytes.write(to: source)
        let backend = EvidenceBackend()
        let engine = ReceiptEngine(library: try LibraryStore(root: library), index: try ReceiptIndex.open(at: root.appendingPathComponent("index.sqlite")), backend: backend, reader: EmptyEvidenceReader())
        do { _ = try await engine.understand(source); Issue.record("Blank OCR must remain an unreadable candidate") }
        catch RecognitionError.unreadableDocument { }
        #expect(await backend.calls == 0)
        #expect(try Data(contentsOf: source) == bytes)
    }
}
private struct EmptyEvidenceReader: DocumentTextRecognizing {
    func text(at url: URL) throws -> String { " \n\t" }
}
private actor EvidenceBackend: ExtractionBackend {
    var calls = 0
    func extract(text: String) async throws -> ExtractedFields {
        calls += 1; return ExtractedFields(kind: "not_receipt", backend: "test")
    }
}
