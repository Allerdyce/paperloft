import Foundation

public struct ReviewedDocument: Identifiable, Sendable {
    public let id: UUID
    public let source: URL
    public let contentHash: String
    public let text: String
    public let fields: ExtractedFields
    public let assessment: ExtractionAssessment
    public let duplicateOf: String?

    public init(id: UUID = UUID(), source: URL, contentHash: String, text: String, fields: ExtractedFields, duplicateOf: String? = nil) {
        self.id = id; self.source = source; self.contentHash = contentHash; self.text = text
        self.fields = fields; self.duplicateOf = duplicateOf
        self.assessment = ExtractionAssessment(fields: fields, parser: ParserBackend.parse(text))
    }
}
public struct FilingOutcome: Sendable {
    public let batch: FilingBatch
    public let indexNeedsRebuild: Bool
}

public actor ReceiptEngine {
    public let library: LibraryStore
    public let index: ReceiptIndex
    private let backend: any ExtractionBackend
    private let reader: any DocumentTextRecognizing

    public init(library: LibraryStore, index: ReceiptIndex, backend: any ExtractionBackend = SystemBackend(), reader: any DocumentTextRecognizing = DocumentRecognizer()) {
        self.library = library; self.index = index; self.backend = backend; self.reader = reader
    }

    public func understand(_ source: URL, emailBodyText: String? = nil, emailHints: MailEnvelope? = nil) async throws -> ReviewedDocument {
        guard LibraryFiles.extensions.contains(source.pathExtension.lowercased()) else { throw LibraryError.unsupportedFile }
        if let emailBodyText, emailBodyText.utf8.count > MailDocument.maximumBodyBytes { throw MailDocument.Failure.limit("1 MB text body") }
        let reader = reader
        let (hash, text) = try await Task.detached {
            let before = try LibraryFiles.hash(source)
            // Transport headers appear in the PDF but must not become confident
            // transaction dates or merchants during body-receipt extraction.
            let text = try emailBodyText ?? reader.text(at: source)
            guard try LibraryFiles.hash(source) == before else { throw LibraryError.sourceChanged(source.path) }
            return (before, text)
        }.value
        // Empty OCR is an unreadable candidate, not evidence that an attachment
        // is non-financial. Let intake preserve/retry it instead of silently
        // falling back to an accompanying cover note.
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RecognitionError.unreadableDocument }
        let extracted = try await backend.extract(text: text)
        let fields = MailFieldHints.apply(to: extracted, envelope: emailHints)
        let duplicate = try await library.documents().first { $0.contentHash == hash }?.relativePath
        return ReviewedDocument(source: source, contentHash: hash, text: text, fields: fields, duplicateOf: duplicate)
    }

    /// Explicit review can correct any field; the source hash still must match what was reviewed.
    public func file(_ reviewed: ReviewedDocument, confirmed receipt: Receipt, mode: FilingMode = .copy, filenameTemplate: String = ReceiptNameTemplate.defaultPattern) async throws -> FilingOutcome {
        let batch = try await library.file([FilingRequest(source: reviewed.source, receipt: receipt, mode: mode, expectedContentHash: reviewed.contentHash, filenameTemplate: filenameTemplate)])
        do {
            for document in batch.documents { try await index.upsert(document, text: reviewed.text) }
            return FilingOutcome(batch: batch, indexNeedsRebuild: false)
        } catch {
            // Filing already committed. Do not repeat it because an expendable cache failed.
            return FilingOutcome(batch: batch, indexNeedsRebuild: true)
        }
    }

    public func undo(_ batch: FilingBatch) async throws -> Bool {
        try await library.undo(batch: batch.id)
        do { try await index.remove(ids: Set(batch.documents.map(\.id))); return true }
        catch { return false }
    }
}
