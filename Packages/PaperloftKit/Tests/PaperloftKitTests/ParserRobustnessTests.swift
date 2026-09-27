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
