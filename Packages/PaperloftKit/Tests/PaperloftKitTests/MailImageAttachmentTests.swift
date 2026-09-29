import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Testing
@testable import PaperloftKit

struct MailImageAttachmentTests {
    private func image(_ type: UTType = .png, width: Int = 256, height: Int = 256, pages: Int = 1) throws -> Data {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let bitmap = try #require(context.makeImage()), data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, type.identifier as CFString, pages, nil))
        for _ in 0..<pages { CGImageDestinationAddImage(destination, bitmap, nil) }
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
    private func part(_ data: Data, mime: String = "image/png", disposition: String = "attachment; filename=receipt.png", contentID: String? = nil) -> String {
        "Content-Type: \(mime)\r\nContent-Disposition: \(disposition)\r\n" + (contentID.map { "Content-ID: <\($0)>\r\n" } ?? "")
            + "Content-Transfer-Encoding: base64\r\n\r\n" + data.base64EncodedString()
    }
    private func mixed(_ parts: [String], subtype: String = "mixed") -> Data {
        Data(("Content-Type: multipart/\(subtype); boundary=parts\r\n\r\n" + parts.map { "--parts\r\n\($0)\r\n" }.joined() + "--parts--\r\n").utf8)
    }

    @Test func allFourImageFormatsSurviveMaterializationExactly() throws {
        let formats: [(UTType, String, String)] = [(.jpeg, "image/jpeg", "jpg"), (.png, "image/png", "png"), (.heic, "image/heic", "heic"), (.tiff, "image/tiff", "tiff")]
        let bytes = try formats.map { try image($0.0) }
        let email = mixed(["Content-Type: text/plain\r\n\r\nReceipt attached"] + formats.enumerated().map { part(bytes[$0.offset], mime: $0.element.1) })
        let parsed = try MailDocument.parse(email)
        #expect(parsed.images.map(\.data) == bytes)
        #expect(parsed.images.map(\.fileExtension) == formats.map(\.2))
        #expect(parsed.images.allSatisfy { $0.width == 256 && $0.height == 256 })
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/MailImageTests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("receipt.eml"); try email.write(to: source)
        let result = try MailImport.materialize(source: source, destination: root)
        #expect(result.documents.count == 5)
        #expect(result.bodyDocument == result.documents.first)
        #expect(result.bodyText == "Receipt attached")
        #expect(try result.attachments.map { try Data(contentsOf: $0) } == bytes)
        #expect(result.attachments.map(\.pathExtension) == formats.map(\.2))
        #expect(try Data(contentsOf: source) == email)
    }

    @Test func TIFFCandidateUsesNormalRecognitionAndFilingValidation() async throws {
        let bytes = try image(.tiff)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/MailImageTests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("receipt.tiff"); try bytes.write(to: source)
        let libraryURL = root.appendingPathComponent("library")
        try FileManager.default.createDirectory(at: libraryURL, withIntermediateDirectories: true)
        let library = try LibraryStore(root: libraryURL)
        let index = try ReceiptIndex.open(at: root.appendingPathComponent("index.sqlite"))
        let fields = ExtractedFields(vendor: "Synthetic shop", date: "2026-09-29", total: "10.00", currency: "USD", category: "Office supplies", confidence: 1, backend: "stub")
        let engine = ReceiptEngine(library: library, index: index, backend: StubBackend(response: fields))
        let reviewed = try await engine.understand(source)
        let receipt = try Receipt(vendor: "Synthetic shop", date: ReceiptDate(iso8601: "2026-09-29"), totalMinorUnits: 1000, currency: "USD", category: "Office supplies")
        let result = try await engine.file(reviewed, confirmed: receipt)
        let document = try #require(result.batch.documents.first)
        #expect(document.relativePath.hasSuffix(".tiff"))
        #expect(try Data(contentsOf: library.root.appendingPathComponent(document.relativePath)) == bytes)
        #expect(try Data(contentsOf: source) == bytes)
    }

    @Test func multiPageTIFFDoesNotSilentlyDiscardLaterPages() throws {
        let bytes = try image(.tiff, pages: 2)
        let mail = try MailDocument.parse(mixed(["Content-Type: text/plain\r\n\r\nReceipt attached", part(bytes, mime: "image/tiff")]))
        #expect(mail.images.isEmpty)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/MailImageTests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("multipage.tiff"); try bytes.write(to: source)
        #expect(throws: RecognitionError.self) { try DocumentRecognizer().text(at: source) }
    }

    @Test func tinyAndHTMLReferencedInlineImagesAreExcluded() throws {
        let valid = try image(), narrow = try image(width: 199, height: 200), short = try image(width: 200, height: 199), edge = try image(width: 200, height: 200)
        let html = "Content-Type: text/html\r\n\r\n<p>Total 10.00</p><img src='CID:logo%40example.invalid'>"
        let mail = try MailDocument.parse(mixed([html, part(narrow), part(short), part(valid, disposition: "inline; filename=logo.png", contentID: "logo@example.invalid"), part(edge), part(valid, disposition: "attachment; filename=explicit.png", contentID: "logo@example.invalid")]))
        #expect(mail.images.count == 2)
        #expect(mail.images[0].width == 200)
        #expect(mail.images[1].name == "explicit.png")
        #expect(mail.htmlBody?.contains("CID:logo%40example.invalid") == true)
    }

    @Test func rawHTMLIsRetainedWhilePlaintextAlternativeStaysCompatible() throws {
        let html = "<html><body><p>Receipt &amp; total 10.00</p><img src='https://example.invalid/pixel'></body></html>"
        let mail = try MailDocument.parse(mixed(["Content-Type: text/plain\r\n\r\nPlain receipt total 10.00", "Content-Type: text/html\r\n\r\n" + html], subtype: "alternative"))
        #expect(mail.body == "Plain receipt total 10.00")
        #expect(mail.htmlBody == html)
        #expect(mail.images.isEmpty)
    }

    @Test func encodedFilenamesAreDecodedBeforeTypeSelectionAndSanitized() throws {
        let bytes = try image()
        for name in ["filename=\"=?UTF-8?Q?Caf=C3=A9.png?=\"", "filename*=UTF-8''Caf%C3%A9.png", "filename*0*=UTF-8''Caf%C3; filename*1*=%A9.png"] {
            let mail = try MailDocument.parse(mixed([part(bytes, mime: "application/octet-stream", disposition: "attachment; " + name)]))
            #expect(mail.images.count == 1)
            #expect(mail.images.first?.name == "Café.png")
        }
        let hostile = try MailDocument.parse(mixed([part(bytes, disposition: "attachment; filename*=UTF-8''..%2F..%2Fsecret.png")]))
        let name = try #require(hostile.images.first?.name)
        #expect(!name.contains("/")); #expect(!name.contains(".."))
        let misleading = try MailDocument.parse(mixed([part(bytes, mime: "image/jpeg", disposition: "attachment; filename=receipt.jpg")]))
        #expect(misleading.images.first?.fileExtension == "png")
    }

    @Test func malformedFilenameContinuationsAndExcessiveImagesFailBoundedly() throws {
        let bytes = try image()
        for name in ["filename*=UTF-8''bad%ZZ.png", "filename*1*=UTF-8''receipt.png", "filename*0*=UTF-8''receipt; filename*2*=.png", "filename*0=receipt; filename*0*=UTF-8''receipt.png"] {
            #expect(throws: MailDocument.Failure.self) { try MailDocument.parse(mixed([part(bytes, disposition: "attachment; " + name)])) }
        }
        #expect(throws: MailDocument.Failure.self) { try MailDocument.parse(mixed(Array(repeating: part(bytes), count: 21))) }
        let mail = try MailDocument.parse(mixed(["Content-Type: text/plain\r\n\r\nReceipt total 10.00", part(Data("corrupt".utf8))]))
        #expect(mail.images.isEmpty)
        #expect(mail.notices.contains { $0.contains("invalid") })
    }
}
