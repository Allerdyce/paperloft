import XCTest
import CryptoKit
@testable import PaperloftKit

/// QA-02: accountant packs use the library's readable names, with numbered suffixes for collisions.
final class ExportNamingTests: XCTestCase {
    private func workspace() throws -> (library: URL, packs: URL) {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/ExportNamingTests/" + UUID().uuidString)
        let library = root.appendingPathComponent("library"), packs = root.appendingPathComponent("packs")
        for url in [library, packs] { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (library, packs)
    }

    private func filed(_ library: URL, _ relativePath: String, date: String, amount: Int64, category: String) throws -> FiledDocument {
        let receipt = try Receipt(vendor: "Fern Cafe", date: ReceiptDate(iso8601: date), totalMinorUnits: amount, currency: "USD", category: category)
        let url = library.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data("bytes of \(relativePath)".utf8)
        try data.write(to: url)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return FiledDocument(receipt: receipt, contentHash: hash, relativePath: relativePath, filedAt: Date())
    }

    func testPackUsesReadableLibraryNamesWithNumberedCollisions() throws {
        let (library, packs) = try workspace()
        let documents = [
            try filed(library, "2026/Office supplies/2026-02-03_Fern-Cafe_12.50.pdf", date: "2026-02-03", amount: 1250, category: "Office supplies"),
            // Same filename in another folder: must not collide in the pack.
            try filed(library, "2025/Office supplies/2026-02-03_Fern-Cafe_12.50.pdf", date: "2026-02-03", amount: 1250, category: "Office supplies"),
            // Category that differs only by case: its own folder with a numbered suffix.
            try filed(library, "2026/office supplies/2026-03-04_Fern-Cafe_8.00.pdf", date: "2026-03-04", amount: 800, category: "office supplies"),
        ]
        let range = try ExportDateRange.quarter(year: 2026, quarter: 1)
        let first = try AccountantPackExporter.export(documents: documents, libraryRoot: library, destination: packs, range: range, zip: true)
        XCTAssertEqual(first.folderURL.lastPathComponent, "Accountant Pack 2026-01-01 to 2026-03-31")
        XCTAssertEqual(first.zipURL?.lastPathComponent, "Accountant Pack 2026-01-01 to 2026-03-31.zip")
        let contents = try FileManager.default.subpathsOfDirectory(atPath: first.folderURL.path).filter { $0 != "transactions.csv" && $0 != "summary.pdf" }.sorted()
        XCTAssertEqual(contents, [
            "Office supplies", "Office supplies/2026-02-03_Fern-Cafe_12.50 (2).pdf", "Office supplies/2026-02-03_Fern-Cafe_12.50.pdf",
            "office supplies (2)", "office supplies (2)/2026-03-04_Fern-Cafe_8.00.pdf",
        ])
        XCTAssertFalse(try FileManager.default.subpathsOfDirectory(atPath: first.folderURL.path).contains { $0.range(of: "[0-9A-F]{8}-[0-9A-F]{4}", options: .regularExpression) != nil },
                       "no UUIDs in pack paths")
        // A second export of the same period gets a numbered name and never touches the first.
        let second = try AccountantPackExporter.export(documents: documents, libraryRoot: library, destination: packs, range: range, zip: true)
        XCTAssertEqual(second.folderURL.lastPathComponent, "Accountant Pack 2026-01-01 to 2026-03-31 (2)")
        XCTAssertEqual(second.zipURL?.lastPathComponent, "Accountant Pack 2026-01-01 to 2026-03-31 (2).zip")
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.folderURL.appendingPathComponent("Office supplies/2026-02-03_Fern-Cafe_12.50.pdf").path))
    }
}
