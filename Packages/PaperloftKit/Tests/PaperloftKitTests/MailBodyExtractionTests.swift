import Foundation
import Testing
@testable import PaperloftKit

private actor BodyTextBackend: ExtractionBackend {
    var text = ""
    func extract(text: String) async throws -> ExtractedFields {
        self.text = text
        return ExtractedFields(kind: "receipt", backend: "capture")
    }
}
struct MailBodyExtractionTests {
    @Test func transportHeadersAreNotUsedAsConfidentReceiptFields() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/MailBodyTests/" + UUID().uuidString)
        let libraryURL = root.appendingPathComponent("library")
        try FileManager.default.createDirectory(at: libraryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("body.pdf")
        let body = "Actual Shop\nReceipt date 2023-08-24\nTotal USD 12.50"
        let bytes = try MailImport.bodyPDF("From: Forwarding Service\nDate: 2026-09-29\nSubject: order\n\n" + body)
        try bytes.write(to: source)
        let backend = BodyTextBackend()
        let engine = ReceiptEngine(library: try LibraryStore(root: libraryURL), index: try ReceiptIndex.open(at: root.appendingPathComponent("index.sqlite")), backend: backend)
        let review = try await engine.understand(source, emailBodyText: body)
        #expect(await backend.text == body)
        #expect(review.text == body)
        #expect(review.contentHash == (try LibraryFiles.hash(source)))
        #expect(try Data(contentsOf: source) == bytes)
    }
}
