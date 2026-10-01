import Foundation
import CryptoKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Public accepted corpus only; never modifies its sources. Fixture conversion is
// outside the app process, so HEIC/PDF encoder setup cannot inflate app peak memory.
func required<T>(_ value: T?) throws -> T {
    guard let value else { throw NSError(domain: "PerformanceInputs", code: 1) }
    return value
}
let repo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let fixtures = repo.appendingPathComponent("Tests/Fixtures")
let destination = repo.appendingPathComponent("build/PerformanceFixtures")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
var entries: [[String: String]] = []
for index in 1...100 {
    try autoreleasepool {
        let id = String(format: "document-%03d", index)
        let originalType = index.isMultiple(of: 2) ? "png" : "jpg"
        let source = fixtures.appendingPathComponent(id + "." + originalType)
        let measuredType = index % 5 == 0 ? "pdf" : index % 5 == 1 ? "heic" : originalType
        let target = destination.appendingPathComponent(id + "." + measuredType)
        if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
        if measuredType == originalType { try FileManager.default.copyItem(at: source, to: target) }
        else {
            let sourceImage = try required(CGImageSourceCreateWithURL(source as CFURL, nil))
            let image = try required(CGImageSourceCreateImageAtIndex(sourceImage, 0, nil))
            if measuredType == "pdf" {
                var box = CGRect(x: 0, y: 0, width: image.width, height: image.height)
                let consumer = try required(CGDataConsumer(url: target as CFURL))
                let context = try required(CGContext(consumer: consumer, mediaBox: &box, nil))
                context.beginPDFPage(nil); context.draw(image, in: box); context.endPDFPage(); context.closePDF()
            } else {
                let output = try required(CGImageDestinationCreateWithURL(target as CFURL, UTType.heic.identifier as CFString, 1, nil))
                CGImageDestinationAddImage(output, image, [kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary)
                guard CGImageDestinationFinalize(output) else { throw NSError(domain: "PerformanceInputs", code: 2) }
            }
        }
        let digest = SHA256.hash(data: try Data(contentsOf: target)).map { String(format: "%02x", $0) }.joined()
        entries.append(["id": id, "sourceType": originalType, "measuredType": measuredType, "sha256": digest])
    }
}
try JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys]).write(to: destination.appendingPathComponent("manifest.json"), options: .atomic)
print("Generated \(entries.count) public derivatives: 30 JPEG, 30 PNG, 20 PDF, 20 HEIC.")
