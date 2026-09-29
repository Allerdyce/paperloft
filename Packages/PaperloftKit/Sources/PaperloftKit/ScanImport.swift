import Foundation
import Darwin
import PDFKit
import ImageIO
import UniformTypeIdentifiers

public enum ScannedPages: String, Codable, Sendable, CaseIterable {
    case separate, combined
}

/// Copies device-delivered bytes into owned files before intake. No device or account required.
public enum ScanImport {
    public static let supportedTypes = [UTType.pdf, .jpeg, .png, .heic, .tiff]
    public static let maximumBytes = 200 * 1024 * 1024
    public enum Failure: Error, LocalizedError {
        case invalid, tooLarge, unsupported
        public var errorDescription: String? {
            switch self {
            case .invalid: "The scan could not be read. Try scanning again."
            case .tooLarge: "Scan fewer pages at a time. The limit is 200 MB and 200 pages."
            case .unsupported: "Scan a PDF, JPEG, PNG, HEIC or TIFF image."
            }
        }
    }
    /// Copy a provider's temporary file synchronously inside its callback. Bounded
    /// streaming keeps provider lifetime and memory independent of later OCR work.
    public static func capture(_ source: URL, destination: URL, budget: Int = maximumBytes) throws -> Int {
        guard source.isFileURL, budget >= 0 else { throw Failure.invalid }
        let descriptor = open(source.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw Failure.invalid }
        let input = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? input.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { throw Failure.invalid }
        guard info.st_size <= budget else { throw Failure.tooLarge }
        let outputDescriptor = open(destination.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard outputDescriptor >= 0 else { throw Failure.invalid }
        do {
            let output = FileHandle(fileDescriptor: outputDescriptor, closeOnDealloc: true); defer { try? output.close() }
            var copied = 0
            while let chunk = try input.read(upToCount: min(262_144, budget - copied + 1)), !chunk.isEmpty {
                guard chunk.count <= budget - copied else { throw Failure.tooLarge }
                try output.write(contentsOf: chunk); copied += chunk.count
            }
            guard copied > 0 else { throw Failure.invalid }
            try output.synchronize()
            return copied
        } catch { try? FileManager.default.removeItem(at: destination); throw error }
    }
    public static func materialize(data: Data, typeIdentifier: String, pages: ScannedPages, destination: URL, outputBudget: Int = maximumBytes) throws -> [URL] {
        guard !data.isEmpty else { throw Failure.invalid }
        guard data.count <= maximumBytes else { throw Failure.tooLarge }
        guard let type = UTType(typeIdentifier), supportedTypes.contains(type) else { throw Failure.unsupported }
        let folder = destination.appendingPathComponent("Scan-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            if type == .pdf {
                guard let document = PDFDocument(data: data), !document.isLocked, document.pageCount > 0 else { throw Failure.invalid }
                guard document.pageCount <= 200 else { throw Failure.tooLarge }
                if pages == .combined {
                    let url = folder.appendingPathComponent("Scanned document.pdf")
                    try data.write(to: url, options: .withoutOverwriting)
                    return [url]
                }
                var written = 0
                return try (0..<document.pageCount).map { index in
                    guard let page = document.page(at: index) else { throw Failure.invalid }
                    let output = PDFDocument(); output.insert(page, at: 0)
                    guard let bytes = output.dataRepresentation() else { throw Failure.invalid }
                    guard bytes.count <= outputBudget - written else { throw Failure.tooLarge }
                    written += bytes.count
                    let url = folder.appendingPathComponent("Scanned page \(index + 1).pdf")
                    try bytes.write(to: url, options: .withoutOverwriting)
                    return url
                }
            }
            guard let image = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(image) > 0,
                  let actual = CGImageSourceGetType(image) as String?, let actualType = UTType(actual), actualType == type else { throw Failure.invalid }
            // TIFF is normalized to a pipeline-supported PNG; preserve other image formats verbatim.
            if type == .tiff {
                guard CGImageSourceGetCount(image) == 1,
                      let properties = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any],
                      let width = properties[kCGImagePropertyPixelWidth] as? Int,
                      let height = properties[kCGImagePropertyPixelHeight] as? Int,
                      width > 0, height > 0, width <= 40_000, height <= 40_000,
                      width <= 100_000_000 / height,
                      let frame = CGImageSourceCreateImageAtIndex(image, 0, nil) else { throw Failure.invalid }
                let url = folder.appendingPathComponent("Scanned image.png")
                guard let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw Failure.invalid }
                CGImageDestinationAddImage(output, frame, nil)
                guard CGImageDestinationFinalize(output) else { throw Failure.invalid }
                return [url]
            }
            let url = folder.appendingPathComponent("Scanned image." + (type.preferredFilenameExtension ?? "png"))
            try data.write(to: url, options: .withoutOverwriting)
            return [url]
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }
}
