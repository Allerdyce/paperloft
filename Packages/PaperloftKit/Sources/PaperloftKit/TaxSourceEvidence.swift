import Foundation

/// A conservative review signal, not a tax calculator. Multiple taxes may be valid,
/// but choosing components across several purchases requires the person's review.
enum TaxSourceEvidence {
    static func requireReviewIfNeeded(fields: inout ExtractedFields, text: String) {
        guard let tax = fields.tax else { return }
        let expected = Decimal(string: tax, locale: Locale(identifier: "en_US_POSIX"))
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        var amounts: [Decimal] = []
        var currencyConflict = false
        for (index, line) in lines.enumerated() {
            guard line.range(of: #"(?i)\b(?:tax(?:es)?|VAT|GST|HST|PST)\b"#, options: .regularExpression) != nil,
                  line.range(of: #"(?i)\b(?:invoice|refund|ID|number|subtotal|before|including|includes|included|inclusive|excluding|excludes|excluded|exclusive|net|gross|rate)\b"#, options: .regularExpression) == nil else { continue }
            if line.range(of: #"(?i)\btotal\b"#, options: .regularExpression) != nil,
               line.range(of: #"(?i)\b(?:total\s+(?:sales\s+)?tax(?:es)?|tax(?:es)?\s+total)\b"#, options: .regularExpression) == nil { continue }
            if let amount = trailingAmount(line) {
                amounts.append(amount)
                currencyConflict = currencyConflict || conflictsWithCurrency(line, currency: fields.currency)
            }
            else if index + 1 < lines.count,
                    lines[index + 1].range(of: #"^(?:[A-Z]{3}\s*)?[$£€]?\s*[0-9.,]+(?:\s*[A-Z]{3})?$"#, options: .regularExpression) != nil,
                    let amount = trailingAmount(lines[index + 1]) {
                amounts.append(amount)
                currencyConflict = currencyConflict || conflictsWithCurrency(line + " " + lines[index + 1], currency: fields.currency)
            }
        }
        // Even equal component amounts can belong to separate transactions. Do not
        // collapse or sum them without a person identifying the intended purchase.
        let unambiguous = !currencyConflict && expected != nil && amounts.count == 1 && amounts.first == expected
        fields.taxNeedsReview = !unambiguous
        if !unambiguous { fields.confidence = min(fields.confidence, 0.5) }
    }

    private static func conflictsWithCurrency(_ line: String, currency: String?) -> Bool {
        let codes = line.uppercased().components(separatedBy: CharacterSet.letters.inverted)
            .filter { Locale.commonISOCurrencyCodes.contains($0) }
        if codes.contains(where: { $0 != currency }) { return true }
        if line.contains("£") && currency != "GBP" { return true }
        if line.contains("€") && currency != "EUR" { return true }
        // A bare dollar sign is shared by several currencies, so does not identify USD.
        return false
    }

    private static func trailingAmount(_ line: String) -> Decimal? {
        guard let range = line.range(of: #"(?<![0-9.,%\-])(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)\.[0-9]{2}(?:\s*[A-Z]{3})?\s*$"#, options: .regularExpression) else { return nil }
        let value = line[range].replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces).first ?? ""
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }
}
