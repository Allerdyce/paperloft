import Foundation
import SwiftData

@Model final class IndexedReceipt {
    @Attribute(.unique) var id: UUID
    var payload: Data
    var searchableText: String
    init(document: FiledDocument, text: String) throws {
        id = document.id
        payload = try JSONEncoder().encode(document)
        searchableText = ([document.receipt.vendor, document.receipt.category, document.receipt.date.formatted,
                           document.relativePath, text].joined(separator: "\n")).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}

public struct ReceiptQuery: Sendable {
    public var text: String
    public var year: Int?
    public var category: String?
    public var kind: DocumentKind?
    public init(text: String = "", year: Int? = nil, category: String? = nil, kind: DocumentKind? = nil) {
        self.text = text; self.year = year; self.category = category; self.kind = kind
    }
}
public struct IndexRebuildReport: Sendable {
    public let indexedDocuments: Int
    public let textFailures: [String]
}

/// A disposable local cache. The library's files and metadata remain authoritative.
@ModelActor public actor ReceiptIndex {
    private var generation: UInt64 = 0
    public static func open(at url: URL? = nil) throws -> ReceiptIndex {
        let schema = Schema([IndexedReceipt.self])
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ReceiptIndex(modelContainer: container)
    }

    public func replace(documents: [FiledDocument], text: [UUID: String]) throws {
        guard Set(documents.map(\.id)).count == documents.count else { throw LibraryError.conflict("duplicate receipt identifiers") }
        do {
            for row in try modelContext.fetch(FetchDescriptor<IndexedReceipt>()) { modelContext.delete(row) }
            for document in documents { modelContext.insert(try IndexedReceipt(document: document, text: text[document.id] ?? "")) }
            try modelContext.save()
            generation &+= 1
        } catch { modelContext.rollback(); throw error }
    }

    public func upsert(_ document: FiledDocument, text: String) throws {
        do {
            let id = document.id
            let rows = try modelContext.fetch(FetchDescriptor<IndexedReceipt>(predicate: #Predicate { $0.id == id }))
            let replacement = try IndexedReceipt(document: document, text: text)
            if let row = rows.first { row.payload = replacement.payload; row.searchableText = replacement.searchableText }
            else { modelContext.insert(replacement) }
            try modelContext.save()
            generation &+= 1
        } catch { modelContext.rollback(); throw error }
    }

    public func remove(ids: Set<UUID>) throws {
        do {
            for row in try modelContext.fetch(FetchDescriptor<IndexedReceipt>()) where ids.contains(row.id) { modelContext.delete(row) }
            try modelContext.save()
            generation &+= 1
        } catch { modelContext.rollback(); throw error }
    }

    public func search(_ query: ReceiptQuery = ReceiptQuery()) throws -> [FiledDocument] {
        let words = query.text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")).split(whereSeparator: \.isWhitespace)
        return try modelContext.fetch(FetchDescriptor<IndexedReceipt>()).compactMap { row in
            guard words.allSatisfy({ row.searchableText.contains($0) }) else { return nil }
            let document = try JSONDecoder().decode(FiledDocument.self, from: row.payload)
            guard query.year == nil || query.year == document.receipt.date.year,
                  query.category == nil || query.category == document.receipt.category,
                  query.kind == nil || query.kind == document.receipt.kind else { return nil }
            return document
        }.sorted {
            $0.receipt.date.formatted == $1.receipt.date.formatted ? $0.relativePath < $1.relativePath : $0.receipt.date.formatted > $1.receipt.date.formatted
        }
    }

    public func rebuild(from library: LibraryStore, reader: any DocumentTextRecognizing = DocumentRecognizer()) async throws -> IndexRebuildReport {
        let startingGeneration = generation
        let documents = try await library.documents()
        var text: [UUID: String] = [:], failures: [String] = []
        for document in documents {
            let url = library.root.appendingPathComponent(document.relativePath)
            do { text[document.id] = try await Task.detached { try reader.text(at: url) }.value }
            catch { failures.append(document.relativePath) }
        }
        let current = try await library.documents()
        guard startingGeneration == generation, current == documents else { throw LibraryError.busy }
        try replace(documents: documents, text: text)
        return IndexRebuildReport(indexedDocuments: documents.count, textFailures: failures)
    }
}
