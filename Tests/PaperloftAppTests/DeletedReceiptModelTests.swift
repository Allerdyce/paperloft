import Foundation
import XCTest
import PaperloftKit

@MainActor final class DeletedReceiptModelTests: XCTestCase {
    func testDeleteRefreshRestartRestoreAndBusyGuard() async throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/DeletedModelTests/" + UUID().uuidString)
        let support = root.appendingPathComponent("support")
        let suite = "app.paperloft.deleted-tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { try? FileManager.default.removeItem(at: root); UserDefaults.standard.removePersistentDomain(forName: suite) }
        let model = AppModel(support: support, preferences: defaults)
        try await model.newSampleLibrary()
        let libraryURL = try XCTUnwrap(model.libraryURL)
        let source = root.appendingPathComponent("original.pdf")
        try Data("not a real PDF, retained original".utf8).write(to: source)
        let receipt = try Receipt(vendor: "Test shop", date: ReceiptDate(iso8601: "2026-09-27"), totalMinorUnits: 1234, currency: "USD", category: "Office")
        let library = try LibraryStore(root: libraryURL)
        let batch = try await library.file([FilingRequest(source: source, receipt: receipt)])
        let document = try XCTUnwrap(batch.documents.first)
        await model.rebuildIndex()
        XCTAssertEqual(model.documents.count, 1)
        model.busy = true
        await model.deleteDocument(document)
        XCTAssertEqual(model.documents.count, 1)
        model.busy = false
        await model.deleteDocument(document)
        XCTAssertTrue(model.documents.isEmpty)
        XCTAssertTrue(model.allDocuments.isEmpty)
        XCTAssertEqual(model.deletedDocuments.count, 1)
        let restarted = AppModel(support: support, preferences: defaults)
        await restarted.start()
        XCTAssertEqual(restarted.deletedDocuments.count, 1)
        await restarted.restoreDocument(try XCTUnwrap(restarted.deletedDocuments.first))
        XCTAssertEqual(restarted.documents.count, 1)
        XCTAssertTrue(restarted.deletedDocuments.isEmpty)
        XCTAssertEqual(try Data(contentsOf: source), Data("not a real PDF, retained original".utf8))
    }
}
