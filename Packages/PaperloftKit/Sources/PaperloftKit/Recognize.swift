import Foundation
import CoreGraphics
import ImageIO
import Vision

public enum RecognitionError: Error { case unreadableDocument, tooManyPages, oversizedImage }

public struct DocumentRecognizer: Sendable {
    public init() {}
    public func text(at url: URL) throws -> String {
        try autoreleasepool { try readText(at: url) }
    }
    private func readText(at url: URL) throws -> String {
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = CGPDFDocument(url as CFURL) else { throw RecognitionError.unreadableDocument }
            guard document.numberOfPages <= 200 else { throw RecognitionError.tooManyPages }
            return try (1...max(1, document.numberOfPages)).map { index in
                guard let page = document.page(at: index) else { throw RecognitionError.unreadableDocument }
                let rect = page.getBoxRect(.mediaBox)
                let scale = min(2, 2400 / max(rect.width, rect.height))
                guard let context = CGContext(data: nil, width: max(1, Int(rect.width * scale)), height: max(1, Int(rect.height * scale)), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw RecognitionError.unreadableDocument }
                context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
                context.scaleBy(x: scale, y: scale); context.drawPDFPage(page)
                guard let image = context.makeImage() else { throw RecognitionError.unreadableDocument }
                return try recognize(image)
            }.joined(separator: "\n\n")
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { throw RecognitionError.unreadableDocument }
        guard width > 0, height > 0, width <= 50_000_000 / height else { throw RecognitionError.oversizedImage }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 3000]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw RecognitionError.unreadableDocument }
        return try recognize(image)
    }
    private func recognize(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
