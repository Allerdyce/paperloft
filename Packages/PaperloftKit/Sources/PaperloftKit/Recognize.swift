import Foundation
import CoreGraphics
import ImageIO
import Vision
import CoreImage

public enum RecognitionError: Error, LocalizedError, Sendable {
    case unreadableDocument, tooManyPages, oversizedImage, lockedDocument, emptyDocument
    public var errorDescription: String? {
        switch self {
        case .unreadableDocument: "This document could not be read. Try a new PDF or image copy."
        case .tooManyPages: "This PDF has 200 or more pages. Split it into smaller documents before importing."
        case .oversizedImage: "This image is 50 megapixels or larger. Export a smaller copy before importing."
        case .lockedDocument: "This PDF is password protected. Unlock a copy before importing it."
        case .emptyDocument: "This file is empty. Choose a document with content."
        }
    }
}

public protocol DocumentTextRecognizing: Sendable {
    func text(at url: URL) throws -> String
}

public struct DocumentRecognizer: DocumentTextRecognizing {
    public init() {}
    public func text(at url: URL) throws -> String {
        try autoreleasepool { try readText(at: url) }
    }
    private func readText(at url: URL) throws -> String {
        if try url.resourceValues(forKeys: [.fileSizeKey]).fileSize == 0 { throw RecognitionError.emptyDocument }
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = CGPDFDocument(url as CFURL) else { throw RecognitionError.unreadableDocument }
            guard !document.isEncrypted || document.isUnlocked else { throw RecognitionError.lockedDocument }
            guard document.numberOfPages < 200 else { throw RecognitionError.tooManyPages }
            return try (1...max(1, document.numberOfPages)).map { index in
                guard let page = document.page(at: index) else { throw RecognitionError.unreadableDocument }
                let rect = page.getBoxRect(.mediaBox)
                guard rect.width.isFinite, rect.height.isFinite, rect.width > 0, rect.height > 0 else { throw RecognitionError.unreadableDocument }
                let scale = min(2, 2400 / max(rect.width, rect.height))
                guard let context = CGContext(data: nil, width: max(1, Int(rect.width * scale)), height: max(1, Int(rect.height * scale)), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw RecognitionError.unreadableDocument }
                context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
                context.concatenate(page.getDrawingTransform(.mediaBox, rect: CGRect(x: 0, y: 0, width: context.width, height: context.height), rotate: 0, preserveAspectRatio: true))
                context.drawPDFPage(page)
                guard let image = context.makeImage() else { throw RecognitionError.unreadableDocument }
                return try recognize(image)
            }.joined(separator: "\n\n")
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { throw RecognitionError.unreadableDocument }
        guard width > 0, height > 0, width <= 49_999_999 / height else { throw RecognitionError.oversizedImage }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 3000]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw RecognitionError.unreadableDocument }
        return try recognize(image)
    }
    private func recognize(_ image: CGImage) throws -> String {
        let image = flattenDocument(image)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        let fragments = (request.results ?? []).compactMap { observation -> TextFragment? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string
            // The observation's rectangle may be axis aligned. The recognized range
            // retains the oriented text quadrilateral needed to deskew its baseline.
            let rectangle = (try? candidate.boundingBox(for: text.startIndex..<text.endIndex)) ?? observation
            let width = rectangle.bottomRight.x - rectangle.bottomLeft.x
            let slope = width > 0 ? (rectangle.bottomRight.y - rectangle.bottomLeft.y) / width : 0
            return TextFragment(text: text, bounds: rectangle.boundingBox, baselineSlope: slope)
        }
        return TextLayout.readingOrder(fragments)
    }

    /// Straighten a confidently detected photographed sheet before joining text rows.
    /// Otherwise a tilted amount column can line up with the next printed label.
    private func flattenDocument(_ image: CGImage) -> CGImage {
        let request = VNDetectDocumentSegmentationRequest()
        guard (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil,
              let page = request.results?.first, page.confidence >= 0.8,
              page.boundingBox.width * page.boundingBox.height >= 0.5 else { return image }
        let horizontalTilt = abs(page.topRight.y - page.topLeft.y) + abs(page.bottomRight.y - page.bottomLeft.y)
        let verticalTilt = abs(page.topLeft.x - page.bottomLeft.x) + abs(page.topRight.x - page.bottomRight.x)
        guard horizontalTilt + verticalTilt > 0.01 else { return image }
        func point(_ p: CGPoint) -> CIVector { CIVector(x: p.x * Double(image.width), y: p.y * Double(image.height)) }
        let flattened = CIImage(cgImage: image).applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": point(page.topLeft), "inputTopRight": point(page.topRight),
            "inputBottomLeft": point(page.bottomLeft), "inputBottomRight": point(page.bottomRight)
        ])
        guard flattened.extent.width > 0, flattened.extent.height > 0,
              flattened.extent.width * flattened.extent.height <= 50_000_000 else { return image }
        return CIContext().createCGImage(flattened, from: flattened.extent) ?? image
    }
}
