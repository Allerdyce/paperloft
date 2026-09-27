import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import PaperloftKit
import UniformTypeIdentifiers
import XCTest

@MainActor final class AppModelResilienceTests: XCTestCase {
    private func workspace() throws -> (URL, UserDefaults) {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/AppResilience/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "app.paperloft.resilience." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock {
            try FileManager.default.removeItem(at: root)
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        return (root, defaults)
    }
    private func pdf(_ url: URL, pages: Int, locked: Bool = false) throws {
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let options: [CFString: Any] = locked ? [kCGPDFContextUserPassword: "synthetic", kCGPDFContextOwnerPassword: "synthetic-owner"] : [:]
        let consumer = try XCTUnwrap(CGDataConsumer(url: url as CFURL))
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &box, options as CFDictionary))
        for _ in 0..<pages { context.beginPDFPage(nil); context.endPDFPage() }
        context.closePDF()
    }
    private func oversizedImage(_ url: URL) throws {
        let bytes = Data(repeating: 255, count: 50_000_000)
        let provider = try XCTUnwrap(CGDataProvider(data: bytes as CFData))
        let image = try XCTUnwrap(CGImage(width: 10_000, height: 5_000, bitsPerComponent: 8, bitsPerPixel: 8,
                                         bytesPerRow: 10_000, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: [],
                                         provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
    func testInvalidDocumentsReachDurableActionableFailureWithoutChangingOriginals() async throws {
        let (root, defaults) = try workspace()
        let library = root.appendingPathComponent("Library")
        try FileManager.default.createDirectory(at: library, withIntermediateDirectories: false)
        defaults.set(library.path, forKey: "paperloft.demoLibraryPath")
        let empty = root.appendingPathComponent("empty.pdf")
        let corrupt = root.appendingPathComponent("corrupt.pdf")
        let locked = root.appendingPathComponent("locked.pdf")
        let long = root.appendingPathComponent("long.pdf")
        let large = root.appendingPathComponent("large.png")
        try Data().write(to: empty); try Data("not a PDF".utf8).write(to: corrupt)
        try pdf(locked, pages: 1, locked: true); try pdf(long, pages: 200); try oversizedImage(large)
        let sources = [empty, corrupt, locked, long, large]
        let originals = try sources.map { SHA256.hash(data: try Data(contentsOf: $0)) }
        let model = AppModel(support: root, preferences: defaults)
        await model.start()
        XCTAssertNil(model.message)
        let began = ContinuousClock.now
        model.intake(sources)
        while model.items.contains(where: { $0.status == "waiting" || $0.status == "processing" }), began.duration(to: .now) < .seconds(20) {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertLessThan(began.duration(to: .now), .seconds(20), "Invalid-input pipeline must finish")
        XCTAssertEqual(model.items.count, 5)
        XCTAssertFalse(model.processing)
        let expected = ["empty", "could not be read", "password protected", "200 or more", "50 megapixels"]
        for (index, item) in model.items.prefix(expected.count).enumerated() {
            XCTAssertEqual(item.status, "failed")
            XCTAssertTrue(item.issue?.contains(expected[index]) == true, item.issue ?? "No actionable message")
            XCTAssertNil(item.review)
            XCTAssertEqual(SHA256.hash(data: try Data(contentsOf: sources[index])), originals[index])
        }
        XCTAssertFalse(model.canFile)
        XCTAssertTrue(model.allDocuments.isEmpty)
        let restored = AppModel(support: root, preferences: defaults)
        await restored.start()
        XCTAssertEqual(restored.items.map(\.issue), model.items.map(\.issue))
        XCTAssertEqual(restored.items.map(\.status), Array(repeating: "failed", count: 5))
        XCTAssertTrue(restored.allDocuments.isEmpty)
    }
    private func persistedInbox(_ root: URL) throws -> Data {
        let source = root.appendingPathComponent("previous.pdf")
        try Data("previous unreadable document".utf8).write(to: source)
        var item = InboxItem(id: UUID(), source: source)
        item.status = "failed"; item.issue = "Previous review must be preserved"
        return try JSONEncoder().encode([item])
    }
    func testMissingLibraryPreservesInboxAndReportsRecoveryAction() async throws {
        let (root, defaults) = try workspace()
        let inbox = root.appendingPathComponent("inbox.json")
        let original = try persistedInbox(root); try original.write(to: inbox)
        defaults.set(root.appendingPathComponent("MissingLibrary").path, forKey: "paperloft.demoLibraryPath")
        let model = AppModel(support: root, preferences: defaults)
        await model.start()
        XCTAssertTrue(model.message?.contains("Choose it again") == true)
        XCTAssertNil(model.libraryURL)
        XCTAssertFalse(model.busy)
        XCTAssertEqual(try Data(contentsOf: inbox), original)
        XCTAssertEqual(model.items.count, 1)
        XCTAssertEqual(model.items.first?.issue, "Previous review must be preserved")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("MissingLibrary").path))
    }
    func testInvalidBookmarkPreservesInboxAndRequestsFolderRenewal() async throws {
        let (root, defaults) = try workspace()
        let inbox = root.appendingPathComponent("inbox.json")
        let original = try persistedInbox(root); try original.write(to: inbox)
        defaults.set(Data("invalid bookmark".utf8), forKey: "paperloft.libraryBookmark")
        let model = AppModel(support: root, preferences: defaults)
        await model.start()
        XCTAssertTrue(model.message?.contains("Choose the folder again") == true)
        XCTAssertNil(model.libraryURL)
        XCTAssertFalse(model.busy)
        XCTAssertEqual(try Data(contentsOf: inbox), original)
        XCTAssertEqual(model.items.count, 1)
        XCTAssertEqual(model.items.first?.issue, "Previous review must be preserved")
    }
}
