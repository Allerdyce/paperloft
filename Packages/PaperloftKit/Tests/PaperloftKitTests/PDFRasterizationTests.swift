import Foundation
import CoreGraphics
import PDFKit
import Testing
@testable import PaperloftKit

struct PDFRasterizationTests {
    private func page(box: CGRect, rotation: Int = 0) throws -> CGPDFPage {
        let data = NSMutableData()
        var media = box
        let consumer = try #require(CGDataConsumer(data: data))
        let context = try #require(CGContext(consumer: consumer, mediaBox: &media, nil))
        context.beginPDFPage(nil)
        // Asymmetric marker in the lower-left, inset from every edge.
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: box.minX + 20, y: box.minY + 30, width: 40, height: 50))
        context.endPDFPage(); context.closePDF()
        let editable = try #require(PDFDocument(data: data as Data))
        let editedPage = try #require(editable.page(at: 0))
        editedPage.rotation = rotation
        let encoded = try #require(editable.dataRepresentation())
        let provider = try #require(CGDataProvider(data: encoded as CFData))
        return try #require(CGPDFDocument(provider)?.page(at: 1))
    }

    private func inkBounds(_ image: CGImage) throws -> CGRect {
        let bytes = try #require(image.dataProvider?.data)
        let pointer = try #require(CFDataGetBytePtr(bytes))
        var minX = image.width, minY = image.height, maxX = -1, maxY = -1
        for y in 0..<image.height {
            for x in 0..<image.width {
                let offset = y * image.bytesPerRow + x * 4
                if pointer[offset] < 100 && pointer[offset + 1] < 100 && pointer[offset + 2] < 100 {
                    minX = min(minX, x); minY = min(minY, y)
                    maxX = max(maxX, x); maxY = max(maxY, y)
                }
            }
        }
        #expect(maxX >= minX && maxY >= minY)
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    @Test func enlargesContentAndHandlesNonzeroMediaOrigin() throws {
        for origin in [CGPoint.zero, CGPoint(x: 70, y: -40)] {
            let image = try DocumentRecognizer.rasterizePDFPage(page(box: CGRect(origin: origin, size: CGSize(width: 200, height: 300))))
            #expect(image.width == 400 && image.height == 600)
            // Bitmap row coordinates begin at the top. 2x physical content,
            // not a 1x page centered in an otherwise enlarged white bitmap.
            #expect(try inkBounds(image) == CGRect(x: 40, y: 440, width: 80, height: 100))
        }
    }

    @Test func rotatesWholePageWithoutClippingOrMirroring() throws {
        let expected: [(Int, Int, Int, CGRect)] = [
            (90, 600, 400, CGRect(x: 60, y: 40, width: 100, height: 80)),
            (180, 400, 600, CGRect(x: 280, y: 60, width: 80, height: 100)),
            (270, 600, 400, CGRect(x: 440, y: 280, width: 100, height: 80))
        ]
        for (rotation, width, height, bounds) in expected {
            let image = try DocumentRecognizer.rasterizePDFPage(page(box: CGRect(x: 70, y: -40, width: 200, height: 300), rotation: rotation))
            #expect(image.width == width && image.height == height)
            #expect(try inkBounds(image) == bounds)
        }
    }

    @Test func veryLargePagesStayWithinExistingPixelBudget() throws {
        let image = try DocumentRecognizer.rasterizePDFPage(page(box: CGRect(x: 0, y: 0, width: 10_000, height: 20_000)))
        #expect(image.width == 1200 && image.height == 2400)
        let bounds = try inkBounds(image)
        #expect(bounds.minX >= 0 && bounds.maxX <= CGFloat(image.width))
        #expect(bounds.minY >= 0 && bounds.maxY <= CGFloat(image.height))
    }
}
