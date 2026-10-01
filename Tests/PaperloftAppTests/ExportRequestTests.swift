import XCTest
import PaperloftKit

/// File › Tax & Accountant Export… (⇧⌘E) pressed while Paperloft is still starting opens the sheet
/// once startup has opened the library, instead of doing nothing.
@MainActor final class ExportRequestTests: XCTestCase {
    func testExportRequestedDuringStartupOpensWhenReady() async throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/ExportRequestTests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "app.paperloft.export-request." + UUID().uuidString
        addTeardownBlock { try? FileManager.default.removeItem(at: root); UserDefaults.standard.removePersistentDomain(forName: suite) }
        let model = AppModel(support: root, preferences: UserDefaults(suiteName: suite)!, extractionBackend: StubBackend())
        model.requestExport()
        XCTAssertTrue(model.exportRequested, "queued before startup")
        XCTAssertFalse(model.showExport)
        await model.start()
        await model.trySamples(resources: repo.appendingPathComponent("Apps/PaperloftApp"))
        XCTAssertNotNil(model.libraryURL)
        model.openRequestedExport()
        XCTAssertTrue(model.showExport, "the sheet opens once the library is ready")
        XCTAssertFalse(model.exportRequested)
    }
}
