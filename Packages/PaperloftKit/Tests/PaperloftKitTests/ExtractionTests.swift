import Foundation
import Testing
@testable import PaperloftKit

@Test func parserUsesFinalTotalRatherThanTenderedCash() async throws {
    let fields = try await ParserBackend().extract(text: "Maple Stationery\nDate: 03/14/2026\nSubtotal $18.00\nTax $1.44\nTOTAL $19.44\nCash $20.00\nChange $0.56")
    #expect(fields.vendor == "Maple Stationery")
    #expect(fields.date == "2026-03-14")
    #expect(fields.total == "19.44")
    #expect(fields.category == "Office supplies")
}
@Test func parserRecognizesNonFinancialText() async throws {
    let fields = try await ParserBackend().extract(text: "Community Garden\nSaturday volunteering\nBring gloves and water")
    #expect(fields.kind == "not_receipt")
    #expect(fields.total == nil)
}
@Test func parserPrefersIssueDateOverDueDate() async throws {
    let fields = try await ParserBackend().extract(text: "Harbor Software\nInvoice\nDue date: 04/30/2026\nIssued: 04/01/2026\nBalance due $125.00")
    #expect(fields.kind == "invoice")
    #expect(fields.date == "2026-04-01")
    #expect(fields.total == "125")
}
@Test func stubReturnsInjectedFields() async throws {
    let expected = ExtractedFields(kind: "bill", total: "8.00", backend: "stub")
    #expect(try await StubBackend(response: expected).extract(text: "unrelated content") == expected)
}
