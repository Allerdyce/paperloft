import Testing
@testable import PaperloftKit

@Test func adjacentHeaderDoesNotBecomePartOfVendor() {
    let fields = ParserBackend.parse("Example Merchant  INVOICE\nIssued: Jun 11,2026\nBalance due  $31.75")
    #expect(fields.vendor == "Example Merchant")
    #expect(fields.date == "2026-06-11")
    #expect(fields.kind == "invoice")
    #expect(fields.total == "31.75")
}

@Test func cardPaymentAndAmountDueAreRecognized() {
    #expect(ParserBackend.parse("Neighborhood Shop\nRECEIPT\nCARD PAYMENT  $19.80\nSubtotal $18.00\nTax $1.80").total == "19.8")
    #expect(ParserBackend.parse("Example Supplier\nINVOICE\nAmount due $210.00").total == "210")
}

@Test func invoiceOpticalCharacterConfusionIsRecognized() {
    #expect(ParserBackend.parse("Example Supplier\nINV0ICE\nTotal $1.00").kind == "invoice")
}

@Test func savingsRefundsAndDecimalSeparatorsDoNotBecomeWrongTotals() {
    #expect(ParserBackend.parse("Shop\nRECEIPT\nTotal $15.00\nTotal savings $5.00").total == "15")
    #expect(ParserBackend.parse("Shop\nRECEIPT\nTotal $-15.00").total == nil)
    #expect(ParserBackend.parse("Shop\nRECEIPT\nTotal USD 1,234.56").total == "1234.56")
    #expect(ParserBackend.parse("Shop\nRECEIPT\nTotal 12,50").total == "12.5")
    #expect(ParserBackend.parse("Shop\nRECEIPT\nTotal USD 12,34.56").total == nil)
}
