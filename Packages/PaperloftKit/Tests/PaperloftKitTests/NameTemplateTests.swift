import Foundation
import Testing
@testable import PaperloftKit

@Suite struct NameTemplateTests {
    private func receipt(vendor: String = "Office Depot", currency: String = "USD") throws -> Receipt {
        try Receipt(vendor: vendor, date: ReceiptDate(year: 2026, month: 9, day: 18), totalMinorUnits: 7490, currency: currency, category: "Office supplies")
    }
    @Test func defaultAndCustomNamesPreserveMetadata() throws {
        let value = try receipt()
        #expect(try ReceiptNameTemplate().name(for: value, fileExtension: "PDF") == "2026-09-18_Office-Depot_74.90.pdf")
        #expect(try ReceiptNameTemplate("{vendor}_{date}_{total}_{currency}").name(for: value, fileExtension: "heic") == "Office-Depot_2026-09-18_74.90_USD.heic")
        #expect(try ReceiptNameTemplate().name(for: receipt(currency: "JPY"), fileExtension: "png").contains("_7490.png"))
    }
    @Test func rejectsTraversalUnknownTokensAndMissingMetadata() throws {
        for pattern in ["../{date}_{vendor}_{total}", "{date}/{vendor}_{total}", "{date}_{vendor}_{total}.exe", "{date}_{vendor}_{unknown}", "{vendor}", "{date}_{vendor}_{total}\u{0}"] {
            #expect(throws: NameTemplateError.self) { try ReceiptNameTemplate(pattern) }
        }
        let value = try receipt(vendor: "../../Coffee/Tea")
        let name = try ReceiptNameTemplate().name(for: value, fileExtension: "pdf")
        #expect(!name.contains("/")); #expect(!name.contains(".."))
        #expect(throws: ReceiptError.self) { try ReceiptNameTemplate().name(for: value, fileExtension: "exe") }
    }
    @Test func boundsExpandedUTF8FilenameWithoutDroppingRequiredFields() throws {
        let value = try receipt(vendor: String(repeating: "商店", count: 100))
        #expect(try ReceiptNameTemplate().name(for: value, fileExtension: "pdf").utf8.count <= 240)
        let repeated = "{date}_{vendor}_{vendor}_{vendor}_{total}"
        #expect(throws: NameTemplateError.self) { try ReceiptNameTemplate(repeated).name(for: value, fileExtension: "pdf") }
    }
}
