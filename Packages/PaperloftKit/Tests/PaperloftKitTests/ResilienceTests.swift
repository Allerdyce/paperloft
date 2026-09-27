import Foundation
import Testing
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import AppIntents
@testable import PaperloftKit

@Suite(.serialized) struct ResilienceTests {
    private func pdf(_ url: URL, pages: Int, locked: Bool = false) throws {
        var rectangle = CGRect(x: 0, y: 0, width: 612, height: 792)
        let info: [CFString: Any] = locked ? [kCGPDFContextUserPassword: "synthetic-read-password", kCGPDFContextOwnerPassword: "synthetic-owner-password"] : [:]
        guard let consumer = CGDataConsumer(url: url as CFURL), let context = CGContext(consumer: consumer, mediaBox: &rectangle, info as CFDictionary) else { throw RecognitionError.unreadableDocument }
        for _ in 0..<pages { context.beginPDFPage(nil); context.endPDFPage() }
        context.closePDF()
    }
    private func png(_ url: URL, width: Int, height: Int, text: String? = nil) throws {
        try autoreleasepool {
            guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw RecognitionError.unreadableDocument }
            context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            if let text {
                let attributes = [kCTFontAttributeName: CTFontCreateWithName("Helvetica" as CFString, 32, nil), kCTForegroundColorAttributeName: CGColor(gray: 0, alpha: 1)] as CFDictionary
                let string = CFAttributedStringCreate(nil, text as CFString, attributes)!
                context.textPosition = CGPoint(x: 30, y: height / 2)
                CTLineDraw(CTLineCreateWithAttributedString(string), context)
            }
            guard let image = context.makeImage(), let writer = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw RecognitionError.unreadableDocument }
            CGImageDestinationAddImage(writer, image, nil)
            guard CGImageDestinationFinalize(writer) else { throw RecognitionError.unreadableDocument }
        }
    }

    @Test func emptyCorruptLockedAndLongPDFsFailClearly() throws {
        let folder = try EngineTestFolder(); defer { folder.clean() }
        let recognizer = DocumentRecognizer()
        let empty = try folder.source("empty.pdf", bytes: Data())
        #expect(throws: RecognitionError.emptyDocument) { try recognizer.text(at: empty) }
        let corrupt = try folder.source("corrupt.pdf", bytes: Data("not a pdf".utf8))
        #expect(throws: RecognitionError.unreadableDocument) { try recognizer.text(at: corrupt) }
        let locked = folder.inbox.appendingPathComponent("locked.pdf"); try pdf(locked, pages: 1, locked: true)
        #expect(throws: RecognitionError.lockedDocument) { try recognizer.text(at: locked) }
        let long = folder.inbox.appendingPathComponent("long.pdf"); try pdf(long, pages: 200)
        #expect(throws: RecognitionError.tooManyPages) { try recognizer.text(at: long) }
        #expect(RecognitionError.lockedDocument.localizedDescription.contains("Unlock"))
    }

    @Test func fiftyMegapixelImageIsRejectedBeforeOCR() throws {
        let folder = try EngineTestFolder(); defer { folder.clean() }
        let image = folder.inbox.appendingPathComponent("large.png")
        try png(image, width: 10000, height: 5000)
        #expect(throws: RecognitionError.oversizedImage) { try DocumentRecognizer().text(at: image) }
    }

    @Test func ordinaryImageAndPDFCompleteWithoutCrashing() throws {
        let folder = try EngineTestFolder(); defer { folder.clean() }
        let image = folder.inbox.appendingPathComponent("notice.png")
        try png(image, width: 1200, height: 300, text: "Community picnic schedule")
        let text = try DocumentRecognizer().text(at: image)
        #expect(!text.isEmpty)
        #expect(ParserBackend.parse(text).kind == "not_receipt")
        let document = folder.inbox.appendingPathComponent("blank.pdf"); try pdf(document, pages: 2)
        #expect(try DocumentRecognizer().text(at: document).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test func missingLibraryAndInvalidPermissionHaveActionableErrors() throws {
        let folder = try EngineTestFolder(); defer { folder.clean() }
        #expect(throws: LibraryError.self) { try LibraryStore(root: folder.base.appendingPathComponent("Missing")) }
        #expect(throws: LibraryAccessError.unavailable) { try LibraryAccess(bookmark: Data("invalid bookmark".utf8)) }
        #expect(LibraryAccessError.staleBookmark.localizedDescription.contains("Choose"))
    }
}
