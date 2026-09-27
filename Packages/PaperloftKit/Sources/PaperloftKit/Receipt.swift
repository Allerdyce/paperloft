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

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(year: c.decode(Int.self, forKey: .year),
                      month: c.decode(Int.self, forKey: .month),
                      day: c.decode(Int.self, forKey: .day))
    }
}

public enum ReceiptError: Error { case invalidDate, invalidAmount, invalidCurrency }

/// Integer minor units avoid floating-point rounding in receipt totals.
public struct Receipt: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var vendor: String
    public var date: ReceiptDate
    public var totalMinorUnits: Int64
    public var currency: String
    public var category: String

    public init(id: UUID = UUID(), vendor: String, date: ReceiptDate,
                totalMinorUnits: Int64, currency: String, category: String) throws {
        guard totalMinorUnits >= 0 else { throw ReceiptError.invalidAmount }
        guard currency.utf8.count == 3,
              currency.utf8.allSatisfy({ (65...90).contains($0) }) else {
            throw ReceiptError.invalidCurrency
        }
        self.id = id; self.vendor = vendor; self.date = date
        self.totalMinorUnits = totalMinorUnits; self.currency = currency
        self.category = category
    }
}

public enum ReceiptFilename {
    /// A single filename component; never accepts separators or traversal syntax.
    public static func safeComponent(_ value: String) -> String {
        let permitted = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let result = value.unicodeScalars.map { permitted.contains($0) ? String($0) : "-" }.joined()
        let collapsed = result.split(separator: "-").joined(separator: "-")
        return collapsed.isEmpty ? "Untitled" : String(collapsed.prefix(80))
    }

    /// Initial two-decimal filename convention; currency-specific display is UI work.
    public static func pdfName(for receipt: Receipt) -> String {
        let amount = "\(receipt.totalMinorUnits / 100)." + String(format: "%02lld", receipt.totalMinorUnits % 100)
        return "\(receipt.date.formatted)_\(safeComponent(receipt.vendor))_\(amount).pdf"
    }
}
