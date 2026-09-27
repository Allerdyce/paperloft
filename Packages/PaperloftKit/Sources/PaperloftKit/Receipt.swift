import Foundation

/// Calendar date without timezone conversion, as printed on a receipt.
public struct ReceiptDate: Codable, Equatable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: day)
        guard (1...9999).contains(year), let date = calendar.date(from: components),
              calendar.component(.year, from: date) == year,
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day else {
            throw ReceiptError.invalidDate
        }
        self.year = year; self.month = month; self.day = day
    }

    public var formatted: String { String(format: "%04d-%02d-%02d", year, month, day) }

    public init(iso8601: String) throws {
        let parts = iso8601.split(separator: "-", omittingEmptySubsequences: false)
        guard iso8601.utf8.count == 10, parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { throw ReceiptError.invalidDate }
        try self.init(year: year, month: month, day: day)
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(year: c.decode(Int.self, forKey: .year),
                      month: c.decode(Int.self, forKey: .month),
                      day: c.decode(Int.self, forKey: .day))
    }
}

public enum ReceiptError: Error { case invalidDate, invalidAmount, invalidCurrency, invalidVendor, invalidCategory, unsupportedFileType }

public enum DocumentKind: String, Codable, Sendable { case receipt, invoice, bill }

/// Integer minor units avoid floating-point rounding in receipt totals.
public struct Receipt: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let vendor: String
    public let date: ReceiptDate
    public let totalMinorUnits: Int64
    public let currency: String
    public let category: String
    public let kind: DocumentKind
    public let taxMinorUnits: Int64?

    public init(id: UUID = UUID(), vendor: String, date: ReceiptDate,
                totalMinorUnits: Int64, currency: String, category: String,
                kind: DocumentKind = .receipt, taxMinorUnits: Int64? = nil) throws {
        _ = try Money(minorUnits: totalMinorUnits, currency: currency)
        if let taxMinorUnits, !(0...totalMinorUnits).contains(taxMinorUnits) { throw ReceiptError.invalidAmount }
        let vendor = vendor.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !vendor.isEmpty else { throw ReceiptError.invalidVendor }
        guard !category.isEmpty else { throw ReceiptError.invalidCategory }
        self.id = id; self.vendor = vendor; self.date = date
        self.totalMinorUnits = totalMinorUnits; self.currency = currency
        self.category = category
        self.kind = kind; self.taxMinorUnits = taxMinorUnits
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: c.decode(UUID.self, forKey: .id), vendor: c.decode(String.self, forKey: .vendor),
                      date: c.decode(ReceiptDate.self, forKey: .date), totalMinorUnits: c.decode(Int64.self, forKey: .totalMinorUnits),
                      currency: c.decode(String.self, forKey: .currency), category: c.decode(String.self, forKey: .category),
                      kind: c.decodeIfPresent(DocumentKind.self, forKey: .kind) ?? .receipt,
                      taxMinorUnits: c.decodeIfPresent(Int64.self, forKey: .taxMinorUnits))
    }
}

public enum ReceiptFilename {
    /// A single filename component; never accepts separators or traversal syntax.
    public static func safeComponent(_ value: String) -> String {
        let permitted = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let result = value.precomposedStringWithCanonicalMapping.unicodeScalars.map { permitted.contains($0) ? String($0) : "-" }.joined()
        let collapsed = result.split(separator: "-").joined(separator: "-")
        var bounded = ""
        for character in collapsed {
            guard bounded.utf8.count + String(character).utf8.count <= 80 else { break }
            bounded.append(character)
        }
        return bounded.isEmpty ? "Untitled" : bounded
    }

    public static func pdfName(for receipt: Receipt) -> String {
        // Receipt construction and decoding validate these invariants.
        let amount = (try? Money(minorUnits: receipt.totalMinorUnits, currency: receipt.currency).decimal) ?? "unknown"
        return "\(receipt.date.formatted)_\(safeComponent(receipt.vendor))_\(amount).pdf"
    }

    public static func name(for receipt: Receipt, fileExtension: String) throws -> String {
        let ext = fileExtension.lowercased()
        guard ["pdf", "png", "jpg", "jpeg", "heic"].contains(ext) else { throw ReceiptError.unsupportedFileType }
        return String(pdfName(for: receipt).dropLast(3)) + ext
    }
}
