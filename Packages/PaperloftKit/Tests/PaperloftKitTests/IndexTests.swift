import Foundation
import Testing
@testable import PaperloftKit

private struct PlainTestReader: DocumentTextRecognizing {
    func text(at url: URL) throws -> String { try String(contentsOf: url, encoding: .utf8) }
}

@Test func indexRebuildRestoresSearchFromLibraryAlone() async throws {
    let folder = try EngineTestFolder(); defer { folder.clean() }
    let source = try folder.source("receipt.pdf", bytes: Data("Notebook subscription renewal".utf8))
    let library = try LibraryStore(root: folder.library)
    let batch = try await library.file([FilingRequest(source: source, receipt: exampleReceipt(vendor: "Café Shop"))])
    let index = try ReceiptIndex.open()
    let report = try await index.rebuild(from: library, reader: PlainTestReader())
    #expect(report.indexedDocuments == 1)
    #expect(report.textFailures.isEmpty)
    #expect(try await index.search(ReceiptQuery(text: "cafe renewal", year: 2026)).map(\.id) == batch.documents.map(\.id))
    #expect(try await index.search(ReceiptQuery(year: 2025)).isEmpty)
    #expect(try await index.search(ReceiptQuery(kind: .invoice)).isEmpty)
    let replacement = try ReceiptIndex.open()
    _ = try await replacement.rebuild(from: library, reader: PlainTestReader())
    #expect(try await replacement.search().count == 1)
    try await replacement.replace(documents: [], text: [:])
    #expect(try await replacement.search().isEmpty)
}

@Test func engineReviewFileSearchUndoAndSourceChange() async throws {
    let folder = try EngineTestFolder(); defer { folder.clean() }
    let source = try folder.source("sample.pdf", bytes: Data("Example Shop\nDate: 2026-04-12\nTotal $15.90\nOffice paper".utf8))
    let library = try LibraryStore(root: folder.library), index = try ReceiptIndex.open()
    let backend = StubBackend(response: ExtractedFields(vendor: "Example Shop", date: "2026-04-12", total: "15.90", currency: "USD", category: "Office supplies", confidence: 1, backend: "stub"))
    let engine = ReceiptEngine(library: library, index: index, backend: backend, reader: PlainTestReader())
    let reviewed = try await engine.understand(source)
    let receipt = try #require(reviewed.assessment.receipt)
    #expect(!reviewed.assessment.canAutoFile)
    let outcome = try await engine.file(reviewed, confirmed: receipt)
    #expect(!outcome.indexNeedsRebuild)
    #expect(try await index.search(ReceiptQuery(text: "paper")).count == 1)
    #expect(try await engine.understand(source).duplicateOf != nil)
    #expect(try await engine.undo(outcome.batch))
    #expect(try await index.search().isEmpty)
    try Data("changed after review".utf8).write(to: source)
    await #expect(throws: LibraryError.self) { try await engine.file(reviewed, confirmed: receipt) }
}
