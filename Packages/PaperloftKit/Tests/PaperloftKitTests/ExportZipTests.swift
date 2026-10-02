import Compression
import CryptoKit
import XCTest
@testable import PaperloftKit

/// V4-01: the accountant pack ZIP keeps non-English names readable everywhere: NFC names with the
/// ZIP UTF-8 flag, every pack file present, contents intact.
final class ExportZipTests: XCTestCase {
    private func workspace() throws -> (library: URL, packs: URL) {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/ExportZipTests/" + UUID().uuidString)
        let library = root.appendingPathComponent("library"), packs = root.appendingPathComponent("packs")
        for url in [library, packs] { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (library, packs)
    }

    private func filed(_ library: URL, _ relativePath: String, vendor: String, date: String, amount: Int64, category: String, bytes: Data) throws -> FiledDocument {
        let receipt = try Receipt(vendor: vendor, date: ReceiptDate(iso8601: date), totalMinorUnits: amount, currency: "USD", category: category)
        let url = library.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url)
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        return FiledDocument(receipt: receipt, contentHash: hash, relativePath: relativePath, filedAt: Date())
    }

    private struct Entry { let name: String; let flags: UInt16; let method: UInt16; let crc: UInt32; let compressed: Int; let size: Int; let offset: Int }

    private func centralDirectory(_ zip: Data) throws -> [Entry] {
        func u16(_ at: Int) -> UInt16 { UInt16(zip[at]) | UInt16(zip[at + 1]) << 8 }
        func u32(_ at: Int) -> UInt32 { UInt32(u16(at)) | UInt32(u16(at + 2)) << 16 }
        let end = try XCTUnwrap((0...(zip.count - 22)).reversed().first { u32($0) == 0x0605_4b50 }, "end of central directory")
        var position = Int(u32(end + 16)), entries: [Entry] = []
        for _ in 0..<Int(u16(end + 10)) {
            XCTAssertEqual(u32(position), 0x0201_4b50)
            let nameLength = Int(u16(position + 28)), extra = Int(u16(position + 30)), comment = Int(u16(position + 32))
            let name = try XCTUnwrap(String(data: zip[(position + 46)..<(position + 46 + nameLength)], encoding: .utf8))
            entries.append(Entry(name: name, flags: u16(position + 8), method: u16(position + 10), crc: u32(position + 16),
                                 compressed: Int(u32(position + 20)), size: Int(u32(position + 24)), offset: Int(u32(position + 42))))
            position += 46 + nameLength + extra + comment
        }
        return entries
    }

    private func contents(_ zip: Data, _ entry: Entry) throws -> Data {
        let nameLength = Int(UInt16(zip[entry.offset + 26]) | UInt16(zip[entry.offset + 27]) << 8)
        let extra = Int(UInt16(zip[entry.offset + 28]) | UInt16(zip[entry.offset + 29]) << 8)
        let start = entry.offset + 30 + nameLength + extra
        let stored = zip[start..<(start + entry.compressed)]
        guard entry.method == 8 else { return Data(stored) }
        var output = Data(count: entry.size)
        let written = output.withUnsafeMutableBytes { destination in
            Data(stored).withUnsafeBytes { source in
                compression_decode_buffer(destination.bindMemory(to: UInt8.self).baseAddress!, entry.size,
                                          source.bindMemory(to: UInt8.self).baseAddress!, entry.compressed, nil, COMPRESSION_ZLIB)
            }
        }
        XCTAssertEqual(written, entry.size, "\(entry.name) inflates to its size")
        return output
    }

    func testZipNamesAreNFCWithUTF8FlagAndContentsMatchThePack() throws {
        XCTAssertEqual(ZipArchive.crc32(Data("123456789".utf8)), 0xCBF4_3926, "standard CRC-32 check value")
        let (library, packs) = try workspace()
        let repetitive = Data(String(repeating: "Receipt line, total 12.50\n", count: 400).utf8)
        let documents = [
            try filed(library, "2026/交通費/2026-02-03_Zürich-Bahn_12.50.pdf", vendor: "Zürich Bahn", date: "2026-02-03", amount: 1250, category: "交通費", bytes: repetitive),
            try filed(library, "2026/Café & Meals/2026-02-10_Crème-Brûlée_8.00.pdf", vendor: "Crème Brûlée", date: "2026-02-10", amount: 800, category: "Café & Meals", bytes: Data((0..<4096).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) })),
        ]
        let pack = try AccountantPackExporter.export(documents: documents, libraryRoot: library, destination: packs,
                                                     range: try ExportDateRange.quarter(year: 2026, quarter: 1), zip: true)
        let zipURL = try XCTUnwrap(pack.zipURL)
        let zip = try Data(contentsOf: zipURL)
        let entries = try centralDirectory(zip)
        let root = pack.folderURL.lastPathComponent
        for entry in entries {
            XCTAssertEqual(entry.flags & 0x0800, 0x0800, "\(entry.name) has the UTF-8 name flag")
            XCTAssertEqual(entry.name, entry.name.precomposedStringWithCanonicalMapping, "\(entry.name) is NFC")
            XCTAssertTrue(entry.name.hasPrefix(root + "/"))
        }
        let packFiles = try FileManager.default.subpathsOfDirectory(atPath: pack.folderURL.path)
        var expected = Set([root + "/"])
        for path in packFiles {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: pack.folderURL.appendingPathComponent(path).path, isDirectory: &isDirectory)
            expected.insert((root + "/" + path + (isDirectory.boolValue ? "/" : "")).precomposedStringWithCanonicalMapping)
        }
        XCTAssertEqual(Set(entries.map(\.name)), expected, "every pack file and folder is in the ZIP")
        XCTAssertTrue(entries.contains { $0.name.contains("交通費/") }, "the non-English category folder is there")
        XCTAssertTrue(entries.contains { $0.method == 8 }, "compressible files are deflated")
        for entry in entries where !entry.name.hasSuffix("/") {
            let relative = String(entry.name.dropFirst(root.count + 1))
            let match = try XCTUnwrap(packFiles.first { $0.precomposedStringWithCanonicalMapping == relative }, relative)
            let original = try Data(contentsOf: pack.folderURL.appendingPathComponent(match))
            let unpacked = try contents(zip, entry)
            XCTAssertEqual(unpacked, original, "\(relative) is unchanged")
            XCTAssertEqual(ZipArchive.crc32(unpacked), entry.crc, "\(relative) CRC")
        }
    }
}
