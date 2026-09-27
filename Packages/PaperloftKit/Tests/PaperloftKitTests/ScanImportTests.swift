import Foundation
import PDFKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Testing
@testable import PaperloftKit

struct ScanImportTests {
    private func workspace() throws -> URL {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/ScanTests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    @Test func pdfPagesSeparateByDefaultOrPreserveCombinedBytes() throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        for count in [1, 5] {
            let source = PDFDocument()
            for page in 1...count {
                let one = try #require(PDFDocument(data: MailImport.bodyPDF("Receipt page \(page)\nTotal \(page).00")))
                source.insert(try #require(one.page(at: 0)), at: source.pageCount)
            }
            let bytes = try #require(source.dataRepresentation())
            let split = try ScanImport.materialize(data: bytes, typeIdentifier: UTType.pdf.identifier, pages: .separate, destination: root)
            #expect(split.count == count)
            for (index, url) in split.enumerated() {
                let document = try #require(PDFDocument(url: url))
                #expect(document.pageCount == 1)
                #expect(document.string?.contains("Receipt page \(index + 1)") == true)
            }
            let combined = try ScanImport.materialize(data: bytes, typeIdentifier: UTType.pdf.identifier, pages: .combined, destination: root)
            #expect(combined.count == 1)
            #expect(try Data(contentsOf: combined[0]) == bytes)
            #expect(PDFDocument(url: combined[0])?.pageCount == count)
        }
    }
    @Test func everyImageFormatCanBeStagedUnderBothPageModes() throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        let context = try #require(CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        let image = try #require(context.makeImage())
        for type in [UTType.png, .jpeg, .heic, .tiff] {
            let data = NSMutableData()
            let encoder = try #require(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(encoder, image, nil)
            #expect(CGImageDestinationFinalize(encoder))
            for mode in ScannedPages.allCases {
                let files = try ScanImport.materialize(data: data as Data, typeIdentifier: type.identifier, pages: mode, destination: root)
                #expect(files.count == 1)
                #expect(CGImageSourceCreateWithURL(files[0] as CFURL, nil) != nil)
                if type != .tiff { #expect(try Data(contentsOf: files[0]) == data as Data) }
                else { #expect(files[0].pathExtension == "png") }
            }
        }
    }
    @Test func invalidScansLeaveNoHalfWrittenOutputs() throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        for type in ScanImport.supportedTypes {
            #expect(throws: (any Error).self) { try ScanImport.materialize(data: Data("not a scan".utf8), typeIdentifier: type.identifier, pages: .separate, destination: root) }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        #expect(throws: (any Error).self) { try ScanImport.materialize(data: Data("text".utf8), typeIdentifier: UTType.plainText.identifier, pages: .combined, destination: root) }
    }
    @Test func outputBudgetAndProviderCaptureAreBoundedAndCleanUp() throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        let bytes = try MailImport.bodyPDF("Synthetic scan")
        #expect(throws: (any Error).self) {
            try ScanImport.materialize(data: bytes, typeIdentifier: UTType.pdf.identifier, pages: .separate, destination: root, outputBudget: 1)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        let original = root.appendingPathComponent("provider.pdf")
        try bytes.write(to: original)
        let owned = root.appendingPathComponent("owned.pdf")
        #expect(throws: (any Error).self) { try ScanImport.capture(original, destination: owned, budget: 1) }
        #expect(!FileManager.default.fileExists(atPath: owned.path))
        #expect(try ScanImport.capture(original, destination: owned) == bytes.count)
        try FileManager.default.removeItem(at: original)
        #expect(try Data(contentsOf: owned) == bytes)
    }

}
