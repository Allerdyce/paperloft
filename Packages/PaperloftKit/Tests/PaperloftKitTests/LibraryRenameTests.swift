import Foundation
import Testing
@testable import PaperloftKit

/// QA-07: a library folder renamed in Finder keeps working through its bookmark.
struct LibraryRenameTests {
    @Test func staleBookmarkForRenamedFolderResolvesToTheNewNameAndRenews() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/LibraryRenameTests/" + UUID().uuidString)
        let original = root.appendingPathComponent("Receipts"), renamed = root.appendingPathComponent("Receipts 2026")
        try FileManager.default.createDirectory(at: original, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let bookmark = try LibraryAccess.bookmark(for: original)
        let first = try LibraryAccess(bookmark: bookmark)
        #expect(first.refreshedBookmark == nil, "an unchanged folder needs no new bookmark")
        try FileManager.default.moveItem(at: original, to: renamed)
        let moved = try LibraryAccess(bookmark: bookmark)
        #expect(moved.url.lastPathComponent == "Receipts 2026")
        let renewed = try #require(moved.refreshedBookmark, "a renamed folder gets a renewed bookmark")
        let again = try LibraryAccess(bookmark: renewed)
        #expect(again.url.standardizedFileURL.path == moved.url.standardizedFileURL.path)
        #expect(again.refreshedBookmark == nil, "the renewed bookmark is current")
    }
}
