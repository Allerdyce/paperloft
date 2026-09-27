import XCTest
import PDFKit
import CryptoKit
@testable import PaperloftKit

final class TaxExportTests: XCTestCase {
    private func document(tax: Int64?, currency: String = "USD", date: String = "2026-01-01",
                          total: Int64 = 10000) throws -> FiledDocument {
        let receipt = try Receipt(vendor: "Merchant", date: ReceiptDate(iso8601: date),
                                  totalMinorUnits: total, currency: currency, category: "Office", taxMinorUnits: tax)
        return FiledDocument(receipt: receipt, contentHash: "", relativePath: receipt.id.uuidString + ".pdf", filedAt: Date())
    }

    func testRecordedZeroMissingCurrencyAndDateBoundariesStayDistinct() throws {
        let docs = try [document(tax: 125), document(tax: 0), document(tax: nil),
                        document(tax: 42, currency: "EUR"), document(tax: nil, currency: "JPY"),
                        document(tax: 500, date: "2025-12-31"), document(tax: 75, date: "2026-12-31"),
                        document(tax: 500, date: "2027-01-01")]
        let totals = try AccountantPackExporter.taxTotals(documents: docs, range: .year(2026))
        XCTAssertEqual(totals.map(\.currency), ["EUR", "JPY", "USD"])
        XCTAssertEqual(totals.map(\.recordedMinorUnits), [42, 0, 200])
        XCTAssertEqual(totals.map(\.recordedCount), [1, 0, 3])
        XCTAssertEqual(totals.map(\.unknownCount), [0, 1, 1])
        XCTAssertEqual(try AccountantPackExporter.taxTotals(documents: [], range: .year(2026)), [])
    }

    func testTaxOverflowIsRejected() throws {
        let docs = try [document(tax: Int64.max, total: Int64.max), document(tax: 1)]
        XCTAssertThrowsError(try AccountantPackExporter.taxTotals(documents: docs, range: .year(2026)))
    }

    func testPackPDFAndCSVPreserveMissingVersusZeroAndCurrencyPrecision() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/TaxExportTests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = Data("source receipt".utf8)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let docs = try [document(tax: nil), document(tax: 0), document(tax: 1234, currency: "KWD"), document(tax: nil, currency: "JPY")].map { original in
            try data.write(to: root.appendingPathComponent(original.relativePath))
            return FiledDocument(receipt: original.receipt, contentHash: hash, relativePath: original.relativePath, filedAt: original.filedAt)
        }
        let result = try AccountantPackExporter.export(documents: docs, libraryRoot: root, destination: root, range: .year(2026))
        let text = try XCTUnwrap(PDFDocument(url: result.folderURL.appendingPathComponent("summary.pdf"))?.string)
        XCTAssertTrue(text.contains("JPY | Unknown | 0 recorded | 1 unknown"), text)
        XCTAssertTrue(text.contains("KWD | 1.234 | 1 recorded | 0 unknown"), text)
        XCTAssertTrue(text.contains("USD | 0.00 | 1 recorded | 1 unknown"), text)
        let csv = try String(contentsOf: result.folderURL.appendingPathComponent("transactions.csv"), encoding: .utf8)
        XCTAssertTrue(csv.contains("\"USD\",\"100.00\",\"10000\",\"\","))
        XCTAssertTrue(csv.contains("\"USD\",\"100.00\",\"10000\",\"0.00\","))
        XCTAssertTrue(csv.contains("\"KWD\",\"10.000\",\"10000\",\"1.234\","))
        for doc in docs { XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(doc.relativePath)), data) }
    }
}
