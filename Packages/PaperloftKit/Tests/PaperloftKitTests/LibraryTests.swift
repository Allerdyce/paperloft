import Foundation
import Testing
@testable import PaperloftKit

struct EngineTestFolder {
    let base: URL
    let library: URL
    let inbox: URL
    init() throws {
        var repo = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { repo.deleteLastPathComponent() }
        base = repo.appendingPathComponent("build/EngineTests/" + UUID().uuidString)
        library = base.appendingPathComponent("Library"); inbox = base.appendingPathComponent("Inbox")
        for directory in [library, inbox] { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
    }
    func clean() { try? FileManager.default.removeItem(at: base) }
    func source(_ name: String, bytes: Data) throws -> URL {
        let url = inbox.appendingPathComponent(name); try bytes.write(to: url); return url
    }
}

func exampleReceipt(vendor: String = "Example Shop", cents: Int64 = 1590) throws -> Receipt {
    try Receipt(vendor: vendor, date: ReceiptDate(iso8601: "2026-04-12"), totalMinorUnits: cents, currency: "USD", category: "Office supplies")
}

@Test func copyCollisionsAndUndoPreserveExistingFiles() async throws {
    let folder = try EngineTestFolder(); defer { folder.clean() }
    let store = try LibraryStore(root: folder.library)
    let first = try folder.source("one.pdf", bytes: Data("original one".utf8))
    let second = try folder.source("two.pdf", bytes: Data("original two".utf8))
    let receipt = try exampleReceipt()
    let a = try await store.file([FilingRequest(source: first, receipt: receipt)])
    let b = try await store.file([FilingRequest(source: second, receipt: exampleReceipt())])
    #expect(a.documents[0].relativePath != b.documents[0].relativePath)
    #expect(b.documents[0].relativePath.contains(" (2).pdf"))
    #expect(try Data(contentsOf: first) == Data("original one".utf8))
    #expect(try Data(contentsOf: second) == Data("original two".utf8))
    #expect(try await store.documents().count == 2)
    try await store.undo(batch: b.id)
    #expect(try await store.documents().count == 1)
    #expect(try Data(contentsOf: folder.library.appendingPathComponent(a.documents[0].relativePath)) == Data("original one".utf8))
    try await store.undo(batch: a.id)
    try await store.undo(batch: a.id)
    #expect(try await store.documents().isEmpty)
    #expect(!FileManager.default.fileExists(atPath: folder.library.appendingPathComponent("2026").path))
}

@Test func moveAndUndoRestoreOriginalIdentityAndBytes() async throws {
    let folder = try EngineTestFolder(); defer { folder.clean() }
    let source = try folder.source("move.png", bytes: Data("move original".utf8))
    let originalIdentity = try LibraryFiles.identity(source)
    let store = try LibraryStore(root: folder.library)
    let batch = try await store.file([FilingRequest(source: source, receipt: exampleReceipt(), mode: .move)])
    #expect(!FileManager.default.fileExists(atPath: source.path))
    let reopened = try LibraryStore(root: folder.library)
    try await reopened.recover()
    #expect(try await reopened.documents().count == 1)
    try await reopened.undo(batch: batch.id)
    #expect(try LibraryFiles.identity(source) == originalIdentity)
    #expect(try Data(contentsOf: source) == Data("move original".utf8))
    #expect(try await reopened.documents().isEmpty)
}

@Test func duplicatesAndModifiedDestinationsAreNeverOverwritten() async throws {
    let folder = try EngineTestFolder(); defer { folder.clean() }
    let source = try folder.source("original.pdf", bytes: Data("same content".utf8))
    let duplicate = try folder.source("renamed.pdf", bytes: Data("same content".utf8))
    let store = try LibraryStore(root: folder.library)
    let batch = try await store.file([FilingRequest(source: source, receipt: exampleReceipt())])
    await #expect(throws: LibraryError.self) { try await store.file([FilingRequest(source: duplicate, receipt: exampleReceipt())]) }
    let target = folder.library.appendingPathComponent(batch.documents[0].relativePath)
    try Data("externally changed".utf8).write(to: target)
    await #expect(throws: LibraryError.self) { try await store.undo(batch: batch.id) }
    #expect(try Data(contentsOf: target) == Data("externally changed".utf8))
    #expect(try Data(contentsOf: source) == Data("same content".utf8))
}

@Test func symlinkedCategoryCannotEscapeLibrary() async throws {
    let folder = try EngineTestFolder(); defer { folder.clean() }
    let outside = folder.base.appendingPathComponent("Outside")
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    let year = folder.library.appendingPathComponent("2026")
    try FileManager.default.createDirectory(at: year, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: year.appendingPathComponent("Office supplies"), withDestinationURL: outside)
    let store = try LibraryStore(root: folder.library)
    let source = try folder.source("source.pdf", bytes: Data("untouched".utf8))
    await #expect(throws: LibraryError.self) { try await store.file([FilingRequest(source: source, receipt: exampleReceipt())]) }
    #expect(try FileManager.default.contentsOfDirectory(atPath: outside.path).isEmpty)
    #expect(try Data(contentsOf: source) == Data("untouched".utf8))
}

@Test func randomizedThousandFileOperationsPreserveEveryOriginal() async throws {
    let folder = try EngineTestFolder(); defer { folder.clean() }
    let store = try LibraryStore(root: folder.library)
    var random: UInt64 = 0x7265636569707473
    func next() -> UInt64 { random ^= random << 13; random ^= random >> 7; random ^= random << 17; return random }
    for round in 0..<10 {
        var requests: [FilingRequest] = []
        var expected: [URL: Data] = [:]
        for item in 0..<100 {
            let length = 32 + Int(next() % 1000)
            let data = Data((0..<length).map { _ in UInt8(truncatingIfNeeded: next()) })
            let source = try folder.source("\(round)-\(item).pdf", bytes: data)
            expected[source] = data
            let receipt = try exampleReceipt(vendor: ["Same Merchant", "商店", "../Unsafe/Name"][Int(next() % 3)], cents: Int64(next() % 5))
            requests.append(FilingRequest(source: source, receipt: receipt, mode: next() % 3 == 0 ? .move : .copy))
        }
        let batch = try await store.file(requests)
        #expect(batch.documents.count == 100)
        #expect(Set(batch.documents.map(\.relativePath)).count == 100)
        for (request, document) in zip(requests, batch.documents) {
            #expect(try Data(contentsOf: folder.library.appendingPathComponent(document.relativePath)) == expected[request.source])
            if request.mode == .copy { #expect(try Data(contentsOf: request.source) == expected[request.source]) }
        }
        try await store.undo(batch: batch.id)
        for (source, data) in expected { #expect(try Data(contentsOf: source) == data) }
        #expect(try await store.documents().isEmpty)
    }
}
