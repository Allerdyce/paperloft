import Foundation
import XCTest

final class AppModelOperationTests: XCTestCase {
    @MainActor func testLibrarySwitchIsRejectedWhileOperationIsSuspended() async throws {
        let model = AppModel()
        let previous = URL(fileURLWithPath: "/original-library")
        model.libraryURL = previous
        model.busy = true
        // A file/export task holds busy while suspended at an actor or open panel.
        // Both public library-switch entry points must leave that transaction alone.
        await model.chooseLibrary()
        XCTAssertEqual(model.libraryURL, previous)
        XCTAssertTrue(model.busy)
        do {
            try await model.newSampleLibrary(discardInbox: true)
            XCTFail("A suspended operation must prevent changing the library")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("current operation"))
        }
        XCTAssertEqual(model.libraryURL, previous)
        XCTAssertTrue(model.busy)
    }

    @MainActor func testExportCannotReplaceActiveResultDuringOperation() {
        let model = AppModel()
        model.busy = true
        model.showExport = false
        let preview = URL(fileURLWithPath: "/export/summary.pdf")
        model.quickLookURL = preview
        model.beginExport()
        XCTAssertFalse(model.showExport)
        XCTAssertEqual(model.quickLookURL, preview)
    }
}
