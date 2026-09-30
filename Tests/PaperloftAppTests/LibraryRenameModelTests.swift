import XCTest
import PaperloftKit

/// QA-07: renaming the library folder while Paperloft runs, or between launches, keeps the library.
@MainActor final class LibraryRenameModelTests: XCTestCase {
    func testRenamedLibraryIsFollowedInSessionAndAfterRelaunch() async throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/LibraryRenameModelTests/" + UUID().uuidString)
        let support = root.appendingPathComponent("support"), library = root.appendingPathComponent("Receipts")
        try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let suite = "app.paperloft.library-rename." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { try? FileManager.default.removeItem(at: root); UserDefaults.standard.removePersistentDomain(forName: suite) }
        defaults.set(try LibraryAccess.bookmark(for: library), forKey: "paperloft.libraryBookmark")

        let model = AppModel(support: support, preferences: defaults, extractionBackend: StubBackend())
        await model.start()
        XCTAssertEqual(model.libraryURL?.lastPathComponent, "Receipts")
        // Renamed while open: the next activation (or filing) follows the bookmark.
        let renamed = root.appendingPathComponent("Receipts 2026")
        try FileManager.default.moveItem(at: library, to: renamed)
        let saved = defaults.data(forKey: "paperloft.libraryBookmark")
        await model.followMovedLibrary()
        XCTAssertEqual(model.libraryURL?.lastPathComponent, "Receipts 2026")
        XCTAssertNotEqual(defaults.data(forKey: "paperloft.libraryBookmark"), saved, "the renewed bookmark is saved")
        XCTAssertTrue(model.message?.contains("Receipts 2026") == true, "the user is told where the library is now: \(model.message ?? "nil")")
        XCTAssertNotEqual(model.filingUnavailableReason, LibraryAccessError.staleBookmark.localizedDescription)

        // Renamed between launches: startup follows the stale bookmark instead of refusing it.
        let again = root.appendingPathComponent("Receipts archive")
        try FileManager.default.moveItem(at: renamed, to: again)
        let relaunched = AppModel(support: support, preferences: defaults, extractionBackend: StubBackend())
        await relaunched.start()
        XCTAssertNil(relaunched.message, relaunched.message ?? "")
        XCTAssertEqual(relaunched.libraryURL?.lastPathComponent, "Receipts archive")
    }
}
