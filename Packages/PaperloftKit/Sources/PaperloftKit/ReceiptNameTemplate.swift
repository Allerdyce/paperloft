import Foundation

public struct ReceiptNameTemplate: Sendable {
    public static let defaultPattern = "{date}_{vendor}_{total}"
    public let pattern: String
    public init(_ pattern: String = defaultPattern) throws {
        guard !pattern.isEmpty, pattern.utf8.count <= 120 else { throw NameTemplateError.invalid }
        var remainder = pattern
        for token in ["date", "vendor", "total", "currency", "category", "kind"] {
            remainder = remainder.replacingOccurrences(of: "{" + token + "}", with: "")
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        guard remainder.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              ["date", "vendor", "total"].allSatisfy({ pattern.contains("{" + $0 + "}") }) else { throw NameTemplateError.invalid }
        self.pattern = pattern
    }
    public func name(for receipt: Receipt, fileExtension: String) throws -> String {
        let ext = fileExtension.lowercased()
        guard ["pdf", "png", "jpg", "jpeg", "heic"].contains(ext) else { throw ReceiptError.unsupportedFileType }
        let values = ["date": receipt.date.formatted, "vendor": ReceiptFilename.safeComponent(receipt.vendor),
                      "total": try Money(minorUnits: receipt.totalMinorUnits, currency: receipt.currency).decimal,
                      "currency": receipt.currency, "category": ReceiptFilename.safeComponent(receipt.category),
                      "kind": receipt.kind.rawValue]
        var result = pattern.replacingOccurrences(of: " ", with: "-")
        for (token, value) in values { result = result.replacingOccurrences(of: "{" + token + "}", with: value) }
        result += "." + ext
        guard result.utf8.count <= 240 else { throw NameTemplateError.tooLong }
        return result
    }
}

public enum NameTemplateError: LocalizedError, Sendable {
    case invalid, tooLong
    public var errorDescription: String? {
        switch self {
        case .invalid: "Include {date}, {vendor} and {total}. Optional fields are {currency}, {category} and {kind}. Use letters, numbers, spaces, hyphens or underscores between fields."
        case .tooLong: "This filename would be too long. Choose a shorter filename template."
        }
    }
}
