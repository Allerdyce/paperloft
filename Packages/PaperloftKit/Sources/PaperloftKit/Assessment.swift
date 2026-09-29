import Foundation

public enum ReviewReason: String, Codable, Sendable {
    case notReceipt, invalidKind, missingVendor, invalidDate, invalidTotal, invalidTax
    case taxSourceUnverified, emailDateHint, emailVendorHint
    case invalidCurrency, missingCategory, lowConfidence, parserDisagreement, parserUnavailable, classificationUnavailable
}

public struct ExtractionAssessment: Sendable {
    public let receipt: Receipt?
    public let reasons: [ReviewReason]
    public var canAutoFile: Bool { receipt != nil && reasons.isEmpty }

    public init(fields: ExtractedFields, parser: ExtractedFields) {
        var reasons: [ReviewReason] = []
        if fields.kind == "not_receipt" { self.receipt = nil; self.reasons = [.notReceipt]; return }
        let kind = DocumentKind(rawValue: fields.kind)
        if kind == nil { reasons.append(.invalidKind) }
        let vendor = fields.vendor?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if vendor.isEmpty { reasons.append(.missingVendor) }
        let date = fields.date.flatMap { try? ReceiptDate(iso8601: $0) }
        if date == nil { reasons.append(.invalidDate) }
        let currency = fields.currency ?? ""
        if (try? Money(minorUnits: 0, currency: currency)) == nil { reasons.append(.invalidCurrency) }
        let total = fields.total.flatMap { try? Money(decimal: $0, currency: currency) }
        if total == nil { reasons.append(.invalidTotal) }
        let tax = fields.tax.flatMap { try? Money(decimal: $0, currency: currency) }
        if fields.tax != nil && (tax == nil || (tax?.minorUnits ?? 0) > (total?.minorUnits ?? 0)) { reasons.append(.invalidTax) }
        let category = fields.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if category.isEmpty { reasons.append(.missingCategory) }
        if reasons.isEmpty, let date, let total, let kind {
            receipt = try? Receipt(vendor: vendor, date: date, totalMinorUnits: total.minorUnits,
                                   currency: currency, category: category, kind: kind, taxMinorUnits: tax?.minorUnits)
        } else { receipt = nil }
        if fields.emailDateHint == true { reasons.append(.emailDateHint) }
        if fields.emailVendorHint == true { reasons.append(.emailVendorHint) }
        if fields.taxNeedsReview == true { reasons.append(.taxSourceUnverified) }
        if !fields.confidence.isFinite || fields.confidence < 0.9 { reasons.append(.lowConfidence) }
        if fields.classificationError != nil { reasons.append(.classificationUnavailable) }
        if fields.backend != "system" || parser.date == nil || parser.total == nil { reasons.append(.parserUnavailable) }
        else if parser.date != fields.date || parser.total.flatMap({ try? Money(decimal: $0, currency: currency) }) != total {
            reasons.append(.parserDisagreement)
        }
        self.reasons = reasons
    }
}
