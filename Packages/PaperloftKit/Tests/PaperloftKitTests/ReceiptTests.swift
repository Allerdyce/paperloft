import Foundation
import Testing
@testable import PaperloftKit

@Test func calendarValidation() throws {
    #expect(throws: ReceiptError.self) { try ReceiptDate(year: 2025, month: 2, day: 29) }
    #expect(throws: ReceiptError.self) { try ReceiptDate(year: 2026, month: 13, day: 1) }
    #expect(try ReceiptDate(year: 2024, month: 2, day: 29).formatted == "2024-02-29")
}
@Test func decodedDatesAreValidated() {
    let data = Data(#"{"year":2026,"month":2,"day":31}"#.utf8)
    #expect(throws: (any Error).self) { try JSONDecoder().decode(ReceiptDate.self, from: data) }
}
@Test func filenameDoesNotTraversePaths() {
    for input in ["../../private", "/tmp/a", "a\\b", "\u{0}", "...", "💰", "a:b"] {
        let name = ReceiptFilename.safeComponent(input)
        #expect(!name.contains("/")); #expect(!name.contains("\\"))
        #expect(!name.contains("..")); #expect(!name.contains(":"))
        #expect(!name.isEmpty)
    }
}
@Test func amountsKeepTheirCents() throws {
    let receipt = try Receipt(vendor: "Office Depot", date: ReceiptDate(year: 2026, month: 9, day: 18),
                              totalMinorUnits: 7490, currency: "USD", category: "Office supplies")
    #expect(ReceiptFilename.pdfName(for: receipt) == "2026-09-18_Office-Depot_74.90.pdf")
}
