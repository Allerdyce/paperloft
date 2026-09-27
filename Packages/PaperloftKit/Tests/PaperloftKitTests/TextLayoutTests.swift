import Foundation
import Testing
@testable import PaperloftKit

@Test func separateColumnsPreserveAmountsOnTheirRows() {
    let fragments = [
        TextFragment(text: "$24.00", bounds: CGRect(x: 0.8, y: 0.40, width: 0.15, height: 0.03)),
        TextFragment(text: "Subtotal", bounds: CGRect(x: 0.1, y: 0.46, width: 0.2, height: 0.03)),
        TextFragment(text: "$20.00", bounds: CGRect(x: 0.8, y: 0.46, width: 0.15, height: 0.03)),
        TextFragment(text: "TOTAL", bounds: CGRect(x: 0.1, y: 0.40, width: 0.2, height: 0.03))
    ]
    let text = TextLayout.readingOrder(fragments)
    #expect(text == "Subtotal  $20.00\nTOTAL  $24.00")
    #expect(ParserBackend.parse(text).total == "24")
}

@Test func rotatedRowsAreNotMistakenForAdjacentLines() {
    let slope = 0.08
    func fragment(_ text: String, x: Double, baseline: Double) -> TextFragment {
        TextFragment(text: text, bounds: CGRect(x: x, y: baseline + slope * (x + 0.075) - 0.015,
                                              width: 0.15, height: 0.03), baselineSlope: slope)
    }
    let fragments = [fragment("Cash", x: 0.1, baseline: 0.5), fragment("$50.00", x: 0.8, baseline: 0.5),
                     fragment("Change", x: 0.1, baseline: 0.44), fragment("$2.00", x: 0.8, baseline: 0.44)]
    #expect(TextLayout.readingOrder(fragments.reversed()) == "Cash  $50.00\nChange  $2.00")
}

@Test func emptyAndInvalidFragmentsDoNotCreateText() {
    #expect(TextLayout.readingOrder([]).isEmpty)
    #expect(TextLayout.readingOrder([TextFragment(text: "ghost", bounds: .zero)]).isEmpty)
}
