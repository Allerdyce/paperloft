import XCTest
import PDFKit
import CryptoKit
import Darwin
@testable import PaperloftKit

final class ExportTests: XCTestCase {
    private func workspace() throws -> URL {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/ExportTests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root
    }
    private func document(_ root: URL, date: String, amount: Int64 = 1234, currency: String = "USD",
                          category: String = "Office", vendor: String = "Café, \"North\"\n東京") throws -> FiledDocument {
        let receipt = try Receipt(vendor: vendor, date: ReceiptDate(iso8601: date), totalMinorUnits: amount,
                                  currency: currency, category: category)
        let path = receipt.id.uuidString + ".pdf"
        let data = Data(("Original bytes " + path).utf8)
        try data.write(to: root.appendingPathComponent(path))
        return FiledDocument(receipt: receipt, contentHash: digest(data), relativePath: path, filedAt: Date())
    }
    private func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    func testTraverseOnlyAncestorsAndSymlinkRejection() throws {
        let root = try workspace()
        let sourceParent = root.appendingPathComponent("source-parent")
        let targetParent = root.appendingPathComponent("target-parent")
        let source = sourceParent.appendingPathComponent("library")
        let target = targetParent.appendingPathComponent("packs")
        for url in [source, target] { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
        let doc = try document(source, date: "2026-01-01", amount: 2592)
        defer { chmod(sourceParent.path, 0o700); chmod(targetParent.path, 0o700) }
        XCTAssertEqual(chmod(sourceParent.path, 0o100), 0)
        XCTAssertEqual(chmod(targetParent.path, 0o100), 0)
        for url in [sourceParent, targetParent] {
            let descriptor = open(url.path, O_RDONLY | O_DIRECTORY)
            XCTAssertEqual(descriptor, -1, "Regression requires traversal without directory-read permission")
            if descriptor >= 0 { close(descriptor) }
        }
        let result = try AccountantPackExporter.export(documents: [doc], libraryRoot: source, destination: target, range: .year(2026))
        let rows = try parseCSV(Data(contentsOf: result.folderURL.appendingPathComponent("transactions.csv")))
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1][6], "2592")
        XCTAssertEqual(digest(try Data(contentsOf: result.folderURL.appendingPathComponent(rows[1][8]))), doc.contentHash)
        XCTAssertTrue(try XCTUnwrap(PDFDocument(url: result.folderURL.appendingPathComponent("summary.pdf"))?.string).contains("USD | 25.92"))
        let link = root.appendingPathComponent("linked-ancestor")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: sourceParent)
        XCTAssertThrowsError(try AccountantPackExporter.export(documents: [doc], libraryRoot: link.appendingPathComponent("library"), destination: target, range: .year(2026)))
    }

    /// Independent RFC 4180 state machine; rejects malformed quote/record delimiters.
    private func parseCSV(_ data: Data) throws -> [[String]] {
        let source = Array(try XCTUnwrap(String(data: data, encoding: .utf8)))
        var rows: [[String]] = [], row: [String] = [], field = "", quoted = false, closed = false, i = 0
        while i < source.count {
            let c = source[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < source.count && source[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { quoted = false; closed = true }
                } else { field.append(c) }
            } else if c == "\"" { XCTAssertTrue(field.isEmpty && !closed); quoted = true }
            else if c == "," { row.append(field); field = ""; closed = false }
            else if c == "\r\n" || c == "\n" {
                row.append(field); rows.append(row); row = []; field = ""; closed = false
            } else { XCTAssertFalse(closed); field.append(c) }
            i += 1
        }
        XCTAssertFalse(quoted); XCTAssertTrue(row.isEmpty && field.isEmpty)
        return rows
    }

    func testInclusiveRangeCSVExactCurrencyTotalsPDFAndOriginalHashes() throws {
        let root = try workspace()
        let documents = try [document(root, date: "2025-12-31"),
                             document(root, date: "2026-01-01", amount: 101),
                             document(root, date: "2026-02-28", amount: 209),
                             document(root, date: "2026-03-31", amount: 333, category: "Travel"),
                             document(root, date: "2026-03-31", amount: 444, currency: "EUR"),
                             document(root, date: "2026-04-01")]
        let range = try ExportDateRange.quarter(year: 2026, quarter: 1)
        let result = try AccountantPackExporter.export(documents: documents, libraryRoot: root, destination: root, range: range)
        let rows = try parseCSV(Data(contentsOf: result.folderURL.appendingPathComponent("transactions.csv")))
        XCTAssertEqual(rows.count, 5); XCTAssertEqual(result.documentCount, 4)
        XCTAssertEqual(rows[0], ["date", "vendor", "category", "kind", "currency", "total", "total_minor_units", "tax", "file", "sha256"])
        var totals: [String: Int64] = [:], monthly: [String: Int64] = [:]
        for row in rows.dropFirst() {
            XCTAssertEqual(row.count, 10); XCTAssertEqual(row[1], "Café, \"North\"\n東京")
            XCTAssertTrue(("2026-01-01"..."2026-03-31").contains(row[0]))
            let amount = try XCTUnwrap(Int64(row[6]))
            totals[row[2] + " | " + row[4], default: 0] += amount
            monthly[String(row[0].prefix(7)) + " | " + row[4], default: 0] += amount
            XCTAssertEqual(row[5], String(format: "%lld.%02lld", amount / 100, amount % 100))
            let exported = try Data(contentsOf: result.folderURL.appendingPathComponent(row[8]))
            XCTAssertEqual(digest(exported), row[9])
            let original = try XCTUnwrap(documents.first { $0.contentHash == row[9] })
            XCTAssertEqual(exported, try Data(contentsOf: root.appendingPathComponent(original.relativePath)))
        }
        XCTAssertEqual(totals, ["Office | USD": 310, "Travel | USD": 333, "Office | EUR": 444])
        let pdf = try XCTUnwrap(PDFDocument(url: result.folderURL.appendingPathComponent("summary.pdf")))
        XCTAssertGreaterThan(pdf.pageCount, 0)
        let text = try XCTUnwrap(pdf.string)
        XCTAssertTrue(text.contains("Not tax advice"))
        for (key, value) in totals.merging(monthly, uniquingKeysWith: +) {
            XCTAssertTrue(text.contains(key + " | " + String(format: "%lld.%02lld", value / 100, value % 100)), text)
        }
        for document in documents { XCTAssertEqual(digest(try Data(contentsOf: root.appendingPathComponent(document.relativePath))), document.contentHash) }
    }

    func testYearQuarterLeapCustomAndInvalidRanges() throws {
        XCTAssertTrue(try ExportDateRange.year(2024).contains(ReceiptDate(iso8601: "2024-02-29")))
        for quarter in 1...4 {
            let range = try ExportDateRange.quarter(year: 2026, quarter: quarter)
            XCTAssertEqual(range.start.month, quarter * 3 - 2); XCTAssertEqual(range.end.month, quarter * 3)
        }
        let day = try ReceiptDate(iso8601: "2026-05-17")
        let range = try ExportDateRange(start: day, end: day)
        let root = try workspace()
        let docs = try [document(root, date: "2026-05-16"), document(root, date: "2026-05-17"), document(root, date: "2026-05-18")]
        XCTAssertEqual(try AccountantPackExporter.export(documents: docs, libraryRoot: root, destination: root, range: range).documentCount, 1)
        XCTAssertThrowsError(try ExportDateRange.quarter(year: 2026, quarter: 0))
        XCTAssertThrowsError(try ExportDateRange.quarter(year: 2026, quarter: 5))
        XCTAssertThrowsError(try ExportDateRange.year(10000))
        XCTAssertThrowsError(try ExportDateRange(start: ReceiptDate(iso8601: "2026-05-18"), end: day))
    }

    func testCollisionUnicodeCategoriesAndRepeatedExportNeverOverwrite() throws {
        let root = try workspace()
        let docs = try [document(root, date: "2026-01-01", category: "A/B"), document(root, date: "2026-01-01", category: "A:B"),
                        document(root, date: "2026-01-01", category: "a-b"), document(root, date: "2026-01-01", category: "交通費")]
        let first = try AccountantPackExporter.export(documents: docs, libraryRoot: root, destination: root, range: .year(2026))
        let firstCSV = try Data(contentsOf: first.folderURL.appendingPathComponent("transactions.csv"))
        let second = try AccountantPackExporter.export(documents: docs, libraryRoot: root, destination: root, range: .year(2026))
        XCTAssertNotEqual(first.folderURL, second.folderURL)
        XCTAssertEqual(firstCSV, try Data(contentsOf: first.folderURL.appendingPathComponent("transactions.csv")))
        let rows = try parseCSV(firstCSV)
        XCTAssertEqual(Set(rows.dropFirst().map { $0[8].split(separator: "/")[0] }).count, 4)
        let pdf = try XCTUnwrap(PDFDocument(url: first.folderURL.appendingPathComponent("summary.pdf")))
        XCTAssertTrue(try XCTUnwrap(pdf.string).contains("交通費"))
    }

    func testHashChangesDuplicateIDsAndTraversalAreRejected() throws {
        let root = try workspace(), range = try ExportDateRange.year(2026)
        var doc = try document(root, date: "2026-01-01")
        XCTAssertThrowsError(try AccountantPackExporter.export(documents: [doc, doc], libraryRoot: root, destination: root, range: range))
        let originalPath = doc.relativePath
        for path in ["../" + originalPath, "/" + originalPath, "x/../" + originalPath, "x//" + originalPath, "x\0.pdf"] {
            doc.relativePath = path
            XCTAssertThrowsError(try AccountantPackExporter.export(documents: [doc], libraryRoot: root, destination: root, range: range))
        }
        doc.relativePath = originalPath
        let changed = Data("Changed source".utf8)
        try changed.write(to: root.appendingPathComponent(originalPath))
        XCTAssertThrowsError(try AccountantPackExporter.export(documents: [doc], libraryRoot: root, destination: root, range: range))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(originalPath)), changed)
    }

    func testSymlinkFilesDirectoriesAndDestinationRejected() throws {
        let root = try workspace(), range = try ExportDateRange.year(2026)
        var doc = try document(root, date: "2026-01-01")
        let alias = root.appendingPathComponent("alias.pdf")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: root.appendingPathComponent(doc.relativePath))
        doc.relativePath = "alias.pdf"
        XCTAssertThrowsError(try AccountantPackExporter.export(documents: [doc], libraryRoot: root, destination: root, range: range))
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root)
        doc.relativePath = "link/alias.pdf"
        XCTAssertThrowsError(try AccountantPackExporter.export(documents: [doc], libraryRoot: root, destination: root, range: range))
        XCTAssertThrowsError(try AccountantPackExporter.export(documents: [], libraryRoot: root, destination: link, range: range))
        let nested = root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: false)
        XCTAssertThrowsError(try AccountantPackExporter.export(documents: [], libraryRoot: root, destination: link.appendingPathComponent("nested"), range: range))
        XCTAssertThrowsError(try AccountantPackExporter.export(documents: [], libraryRoot: link, destination: root, range: range))
    }

    func testOverflowRejectedAndCurrenciesWithDifferentPrecision() throws {
        let root = try workspace(), range = try ExportDateRange.year(2026)
        let overflow = try [document(root, date: "2026-01-01", amount: Int64.max), document(root, date: "2026-01-01", amount: 1)]
        XCTAssertThrowsError(try AccountantPackExporter.export(documents: overflow, libraryRoot: root, destination: root, range: range))
        let docs = try [document(root, date: "2026-01-01", amount: 123, currency: "JPY"), document(root, date: "2026-01-01", amount: 1234, currency: "KWD")]
        let result = try AccountantPackExporter.export(documents: docs, libraryRoot: root, destination: root, range: range)
        let rows = try parseCSV(Data(contentsOf: result.folderURL.appendingPathComponent("transactions.csv")))
        let byCurrency = Dictionary(uniqueKeysWithValues: rows.dropFirst().map { ($0[4], $0[5]) })
        XCTAssertEqual(byCurrency, ["JPY": "123", "KWD": "1.234"])
        let text = try XCTUnwrap(PDFDocument(url: result.folderURL.appendingPathComponent("summary.pdf"))?.string)
        XCTAssertTrue(text.contains("JPY | 123")); XCTAssertTrue(text.contains("KWD | 1.234"))
    }

    func testEmptyAndMultipageSummary() throws {
        let root = try workspace(), range = try ExportDateRange.year(2026)
        let empty = try AccountantPackExporter.export(documents: [], libraryRoot: root, destination: root, range: range)
        XCTAssertEqual(try parseCSV(Data(contentsOf: empty.folderURL.appendingPathComponent("transactions.csv"))).count, 1)
        XCTAssertTrue(try XCTUnwrap(PDFDocument(url: empty.folderURL.appendingPathComponent("summary.pdf"))?.string).contains("0 documents"))
        let docs = try (0..<70).map { try document(root, date: "2026-01-01", category: String(format: "Category %03d", $0)) }
        let pack = try AccountantPackExporter.export(documents: docs, libraryRoot: root, destination: root, range: range)
        let pdf = try XCTUnwrap(PDFDocument(url: pack.folderURL.appendingPathComponent("summary.pdf")))
        XCTAssertGreaterThan(pdf.pageCount, 1)
        for i in 0..<70 { XCTAssertTrue(try XCTUnwrap(pdf.string).contains(String(format: "Category %03d | USD | 12.34", i))) }
    }

    func testOptionalSystemZIPContainsCSVAndOriginalBytes() throws {
        let root = try workspace()
        let doc = try document(root, date: "2026-01-01")
        let pack = try AccountantPackExporter.export(documents: [doc], libraryRoot: root, destination: root, range: .year(2026), zip: true)
        let zip = try XCTUnwrap(pack.zipURL)
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", zip.path, "*/transactions.csv"]
        process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
        try process.run()
        let csv = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit(); XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(csv, try Data(contentsOf: pack.folderURL.appendingPathComponent("transactions.csv")))
        let rows = try parseCSV(csv)
        let unzip = Process(), bytes = Pipe()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-p", zip.path, "*/" + rows[1][8]]
        unzip.standardOutput = bytes; unzip.standardError = FileHandle.nullDevice
        try unzip.run()
        let original = bytes.fileHandleForReading.readDataToEndOfFile()
        unzip.waitUntilExit(); XCTAssertEqual(unzip.terminationStatus, 0)
        XCTAssertEqual(digest(original), doc.contentHash)
    }
}
