import Foundation
import Testing
@testable import PaperloftKit

@Test func deletedReceiptSurvivesRestartAndRestoresWithoutTouchingOriginal() async throws {
    let folder = try EngineTestFolder(); defer { folder.clean() }
    let source = try folder.source("receipt.pdf", bytes: Data("preserve me".utf8))
    let store = try LibraryStore(root: folder.library)
    let batch = try await store.file([FilingRequest(source: source, receipt: exampleReceipt())])
    let document = try #require(batch.documents.first)
    try await store.delete(document)
    #expect(try await store.documents().isEmpty)
    #expect(try Data(contentsOf: source) == Data("preserve me".utf8))
    let reopened = try LibraryStore(root: folder.library)
    try await reopened.recover()
    let deleted = try #require(try await reopened.deletedDocuments().first)
    #expect(deleted.document == document)
    try await reopened.restore(deleted)
    #expect(try await reopened.documents() == [document])
    #expect(try await reopened.deletedDocuments().isEmpty)
    try await reopened.undo(batch: batch.id)
    #expect(try await reopened.documents().isEmpty)
}

@Test func undoAlreadyDeletedMoveRestoresOriginalAndConsumesRecoveryEntry() async throws {
    let folder = try EngineTestFolder(); defer { folder.clean() }
    let source = try folder.source("receipt.png", bytes: Data("move me".utf8))
    let store = try LibraryStore(root: folder.library)
    let batch = try await store.file([FilingRequest(source: source, receipt: exampleReceipt(), mode: .move)])
    try await store.delete(try #require(batch.documents.first))
    try await store.undo(batch: batch.id)
    #expect(try await store.deletedDocuments().isEmpty)
    #expect(try await store.documents().isEmpty)
    #expect(try Data(contentsOf: source) == Data("move me".utf8))
    try await store.undo(batch: batch.id)
}

@Test func restoreConflictPreservesBothFilesAndCanRetry() async throws {
    let folder = try EngineTestFolder(); defer { folder.clean() }
    let source = try folder.source("receipt.pdf", bytes: Data("receipt bytes".utf8))
    let store = try LibraryStore(root: folder.library)
    let document = try #require(try await store.file([FilingRequest(source: source, receipt: exampleReceipt())]).documents.first)
    try await store.delete(document)
    let deleted = try #require(try await store.deletedDocuments().first)
    let destination = folder.library.appendingPathComponent(document.relativePath)
    try Data("foreign file".utf8).write(to: destination)
    await #expect(throws: (any Error).self) { try await store.restore(deleted) }
    #expect(try Data(contentsOf: destination) == Data("foreign file".utf8))
    #expect(try await store.deletedDocuments() == [deleted])
    try FileManager.default.moveItem(at: destination, to: folder.base.appendingPathComponent("foreign-preserved"))
    try await store.restore(deleted)
    #expect(try Data(contentsOf: destination) == Data("receipt bytes".utf8))
}

@Test func deletedReceiptRejectsChangedBytesAndSymlinkPayload() async throws {
    let folder = try EngineTestFolder(); defer { folder.clean() }
    let source = try folder.source("receipt.pdf", bytes: Data("receipt".utf8))
    let store = try LibraryStore(root: folder.library)
    let document = try #require(try await store.file([FilingRequest(source: source, receipt: exampleReceipt())]).documents.first)
    let target = folder.library.appendingPathComponent(document.relativePath)
    try Data("modified".utf8).write(to: target)
    await #expect(throws: (any Error).self) { try await store.delete(document) }
    #expect(try await store.deletedDocuments().isEmpty)
    try Data("receipt".utf8).write(to: target)
    try LibraryFiles.setMetadata(document, at: target)
    try await store.delete(document)
    let deleted = try #require(try await store.deletedDocuments().first)
    let payload = folder.library.appendingPathComponent(".paperloft/deleted/\(deleted.id.uuidString).receipt")
    try FileManager.default.moveItem(at: payload, to: folder.base.appendingPathComponent("preserved"))
    try FileManager.default.createSymbolicLink(at: payload, withDestinationURL: source)
    await #expect(throws: (any Error).self) { try await store.restore(deleted) }
    #expect(try Data(contentsOf: source) == Data("receipt".utf8))
}

@Test func interruptedDeletionAndRestoreReplayAfterRename() async throws {
    let folder = try EngineTestFolder(); defer { folder.clean() }
    let source = try folder.source("receipt.pdf", bytes: Data("durable".utf8))
    let store = try LibraryStore(root: folder.library)
    let document = try #require(try await store.file([FilingRequest(source: source, receipt: exampleReceipt())]).documents.first)
    try await store.delete(document)
    let deleted = try #require(try await store.deletedDocuments().first)
    let journalURL = folder.library.appendingPathComponent(".paperloft/deleted/\(deleted.id.uuidString).json")
    func setState(_ state: String) throws {
        var object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: journalURL)) as? [String: Any])
        object["state"] = state
        try JSONSerialization.data(withJSONObject: object).write(to: journalURL, options: .atomic)
    }
    try setState("deleting") // Rename committed; final journal save was interrupted.
    let reopened = try LibraryStore(root: folder.library)
    try await reopened.recover()
    #expect(try await reopened.deletedDocuments() == [deleted])
    try setState("restoring") // Journal committed; rename has not happened yet.
    try await reopened.recover()
    #expect(try await reopened.documents() == [document])
    try setState("restoring") // Rename committed; final journal save was interrupted.
    try await reopened.recover()
    #expect(try await reopened.deletedDocuments().isEmpty)
    #expect(try await reopened.documents() == [document])
}

@Test func finderRenamedReceiptCanBeDeletedAndRestoredAtCurrentPath() async throws {
    let folder = try EngineTestFolder(); defer { folder.clean() }
    let source = try folder.source("receipt.pdf", bytes: Data("renamed receipt".utf8))
    let store = try LibraryStore(root: folder.library)
    let filed = try #require(try await store.file([FilingRequest(source: source, receipt: exampleReceipt())]).documents.first)
    let original = folder.library.appendingPathComponent(filed.relativePath)
    let renamed = original.deletingLastPathComponent().appendingPathComponent("Finder name.pdf")
    try FileManager.default.moveItem(at: original, to: renamed)
    let current = try #require(try await store.documents().first)
    #expect(current.relativePath != filed.relativePath)
    try await store.delete(current)
    let deleted = try #require(try await store.deletedDocuments().first)
    try await store.restore(deleted)
    #expect(try await store.documents() == [current])
    #expect(try Data(contentsOf: renamed) == Data("renamed receipt".utf8))
}
