import Testing
@testable import PaperloftKit

@Test func classifierStatementLabelMapsToBillAndOtherLabelsPassThrough() {
    #expect(SystemBackend.documentKind(fromClassifierLabel: "statement") == "bill")
    for label in ["receipt", "invoice", "not_receipt"] { #expect(SystemBackend.documentKind(fromClassifierLabel: label) == label) }
    #expect(SystemBackend.classifierInstructions.contains("A BILL or ACCOUNT STATEMENT is statement"))
}
