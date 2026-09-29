import Foundation
import XCTest
import PaperloftKit
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

@MainActor final class WatchedMailIntakeTests: XCTestCase {
    private let fields = ExtractedFields(kind: "receipt", vendor: "Synthetic shop", date: "2026-09-29", total: "12.00", currency: "USD", category: "Office supplies", confidence: 1, backend: "stub")
    private func workspace() throws -> (URL, URL, UserDefaults) {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/WatchedMailIntake/" + UUID().uuidString), watched = root.appendingPathComponent("watch")
        try FileManager.default.createDirectory(at: watched, withIntermediateDirectories: true)
        let suite = "app.paperloft.watch-mail." + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { try FileManager.default.removeItem(at: root); UserDefaults.standard.removePersistentDomain(forName: suite) }
        return (root.appendingPathComponent("support"), watched, defaults)
    }
    private func image(type: UTType = .png) throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: 240, height: 240, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 0.3, green: 0.6, blue: 0.2, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 240, height: 240))
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 240, height: 240))
        let text = NSAttributedString(string: "Synthetic shop\nRECEIPT\n2026-09-29\nTotal USD 12.00", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 16, nil)])
        let frame = CTFramesetterCreateFrame(CTFramesetterCreateWithAttributedString(text), CFRange(location: 0, length: 0), CGPath(rect: CGRect(x: 15, y: 15, width: 210, height: 210), transform: nil), nil)
        CTFrameDraw(frame, context)
        let data = NSMutableData(), destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination)); return data as Data
    }
    private func mail(_ image: Data, brokenPDF: Bool = false, extraHeader: String = "") -> Data {
        let invalid = brokenPDF ? "--parts\r\nContent-Type: application/pdf\r\nContent-Disposition: attachment; filename=broken.pdf\r\n\r\n%PDF-not-a-readable-document\r\n" : ""
        return Data(("Message-ID: <watched@example.invalid>\r\nSubject: Synthetic receipt\r\n" + extraHeader + "Content-Type: multipart/mixed; boundary=parts\r\n\r\n--parts\r\nContent-Type: image/png\r\nContent-Disposition: attachment; filename=receipt.png\r\nContent-Transfer-Encoding: base64\r\n\r\n" + image.base64EncodedString() + "\r\n" + invalid + "--parts--\r\n").utf8)
    }
    private func model(_ support: URL, _ watched: URL, _ defaults: UserDefaults) async throws -> AppModel {
        let result = AppModel(support: support, preferences: defaults, proEntitlement: { true }, extractionBackend: StubBackend(response: fields))
        try await result.newSampleLibrary()
        try await result.installWatchedFolder(at: watched, schedule: false, stableInterval: .milliseconds(10))
        return result
    }
    private func settle(_ model: AppModel) async throws {
        await model.scanWatchedFolder(); try await Task.sleep(for: .milliseconds(30)); await model.scanWatchedFolder()
    }
    private func finish(_ model: AppModel) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while (model.processing || model.items.contains { $0.status == "waiting" || $0.status == "processing" }) && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(model.processing); XCTAssertFalse(model.items.contains { $0.status == "waiting" || $0.status == "processing" })
    }

    func testStableMailUsesCommonPipelineThenRenameAndRelaunchDoNotRepeat() async throws {
        let (support, watched, defaults) = try workspace(), png = try image(), bytes = mail(png)
        let source = watched.appendingPathComponent("first.eml"); try bytes.write(to: source)
        let app = try await model(support, watched, defaults)
        await app.scanWatchedFolder(); XCTAssertTrue(app.items.isEmpty)
        try await Task.sleep(for: .milliseconds(30)); await app.scanWatchedFolder(); try await finish(app)
        let receipt = try XCTUnwrap(app.items.first)
        XCTAssertEqual(app.items.count, 1); XCTAssertEqual(receipt.status, "ready")
        XCTAssertNotNil(receipt.mailDelivery); XCTAssertNotNil(receipt.watchedDelivery)
        XCTAssertTrue(receipt.intakeSource?.contains("Watched folder") == true)
        XCTAssertEqual(try Data(contentsOf: receipt.source), png); XCTAssertEqual(try Data(contentsOf: source), bytes)
        let renamed = watched.appendingPathComponent("renamed.eml"); try FileManager.default.moveItem(at: source, to: renamed)
        try await settle(app); XCTAssertEqual(app.items.map(\.id), [receipt.id])
        await app.disableWatchedFolder()
        // Simulate a lost watched-ledger commit: only the child inbox proof remains.
        let watchedLedger = support.appendingPathComponent("watched-deliveries.json")
        try FileManager.default.removeItem(at: watchedLedger)
        let reopened = AppModel(support: support, preferences: defaults, proEntitlement: { true }, extractionBackend: StubBackend(response: fields))
        try await reopened.installWatchedFolder(at: watched, schedule: false, stableInterval: .milliseconds(10))
        try await settle(reopened); try await finish(reopened)
        XCTAssertEqual(reopened.items.map(\.id), [receipt.id]); XCTAssertEqual(try Data(contentsOf: renamed), bytes)
        XCTAssertTrue(FileManager.default.fileExists(atPath: watchedLedger.path), "Startup must replay the watched proof carried by the Mail child")
        // Different bytes and filename, same Message-ID: source delivery occurs once,
        // while the common Mail ledger exposes it as a duplicate, not another receipt.
        let other = watched.appendingPathComponent("second.eml"), changed = mail(png, extraHeader: "X-Synthetic: changed\r\n")
        try changed.write(to: other); try await settle(reopened); try await finish(reopened)
        XCTAssertEqual(reopened.items.filter { $0.status == "ready" }.count, 1)
        XCTAssertEqual(reopened.items.filter { $0.status == "duplicate" }.count, 1)
        XCTAssertEqual(try Data(contentsOf: other), changed)
        await reopened.disableWatchedFolder()
    }

    func testChangingMailWaitsForStableCompleteBytes() async throws {
        let (support, watched, defaults) = try workspace(), bytes = mail(try image())
        let app = try await model(support, watched, defaults), source = watched.appendingPathComponent("copying.eml")
        let split = bytes.count / 2; try bytes.prefix(split).write(to: source)
        await app.scanWatchedFolder(); XCTAssertTrue(app.items.isEmpty)
        let writer = try FileHandle(forWritingTo: source); try writer.seekToEnd(); try writer.write(contentsOf: bytes.suffix(from: split)); try writer.close()
        try await Task.sleep(for: .milliseconds(30)); await app.scanWatchedFolder(); XCTAssertTrue(app.items.isEmpty)
        try await Task.sleep(for: .milliseconds(30)); await app.scanWatchedFolder(); try await finish(app)
        XCTAssertEqual(app.items.count, 1); XCTAssertEqual(app.items.first?.status, "ready")
        XCTAssertEqual(try Data(contentsOf: source), bytes)
        await app.disableWatchedFolder()
    }

    func testPartialMailFailureKeepsOwnedOriginalRetryableAndDoesNotCommitMessageID() async throws {
        let (support, watched, defaults) = try workspace(), png = try image()
        let invalid = mail(png, brokenPDF: true), source = watched.appendingPathComponent("receipt.eml")
        try invalid.write(to: source)
        let app = try await model(support, watched, defaults)
        try await settle(app); try await finish(app)
        let failed = try XCTUnwrap(app.items.first)
        XCTAssertEqual(failed.status, "failed"); XCTAssertEqual(failed.source.pathExtension, "eml")
        XCTAssertNil(failed.mailDelivery); XCTAssertNotNil(failed.watchedDelivery)
        XCTAssertEqual(try Data(contentsOf: failed.source), invalid); XCTAssertEqual(try Data(contentsOf: source), invalid)
        let ledger = try MailDeliveryLedger(directory: support)
        XCTAssertNil(try ledger.committedDeliverySynchronously(messageID: "<watched@example.invalid>"))
        try await settle(app); XCTAssertEqual(app.items.count, 1, "Scanner acknowledgment means owned copy, not successful extraction")
        let fixed = mail(png); try fixed.write(to: source)
        try await settle(app); try await finish(app)
        XCTAssertEqual(app.items.filter { $0.status == "ready" }.count, 1)
        XCTAssertEqual(app.items.filter { $0.status == "failed" }.count, 1)
        XCTAssertNotNil(try ledger.committedDeliverySynchronously(messageID: "<watched@example.invalid>"))
        XCTAssertEqual(try Data(contentsOf: failed.source), invalid); XCTAssertEqual(try Data(contentsOf: source), fixed)
        await app.disableWatchedFolder()
    }

    func testWatchedTIFFPreservesBytesThroughReviewAndFiling() async throws {
        let (support, watched, defaults) = try workspace(), bytes = try image(type: .tiff)
        let source = watched.appendingPathComponent("receipt.tiff"); try bytes.write(to: source)
        let app = try await model(support, watched, defaults)
        try await settle(app); try await finish(app)
        let receipt = try XCTUnwrap(app.items.first)
        XCTAssertEqual(receipt.status, "ready"); XCTAssertEqual(receipt.source.pathExtension, "tiff")
        XCTAssertEqual(try Data(contentsOf: receipt.source), bytes)
        app.selectedItemID = receipt.id; await app.fileSelected()
        let document = try XCTUnwrap(app.documents.first), library = try XCTUnwrap(app.libraryURL)
        XCTAssertTrue(document.relativePath.hasSuffix(".tiff"))
        XCTAssertEqual(try Data(contentsOf: library.appendingPathComponent(document.relativePath)), bytes)
        XCTAssertEqual(try Data(contentsOf: source), bytes)
        await app.disableWatchedFolder()
    }
}
