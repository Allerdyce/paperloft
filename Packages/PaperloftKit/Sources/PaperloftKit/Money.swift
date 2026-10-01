import Foundation
import Synchronization

/// Exact, nonnegative monetary amounts; no floating-point conversion or rounding.
public struct Money: Equatable, Sendable {
    public let minorUnits: Int64
    public let currency: String
    public let fractionDigits: Int

    public init(minorUnits: Int64, currency: String) throws {
        guard minorUnits >= 0 else { throw ReceiptError.invalidAmount }
        let digits = try Self.fractionDigits(for: currency)
        self.minorUnits = minorUnits; self.currency = currency; self.fractionDigits = digits
    }

    private static let currencyCodes = Set(Locale.commonISOCurrencyCodes)
    private static let digitsByCurrency = Mutex<[String: Int]>([:])
    /// Looked up once per currency: building a NumberFormatter is slow, and the Inbox creates
    /// amounts for every row on every refresh (AC-10 main-thread budget).
    private static func fractionDigits(for currency: String) throws -> Int {
        if let digits = digitsByCurrency.withLock({ $0[currency] }) { return digits }
        guard currencyCodes.contains(currency) else { throw ReceiptError.invalidCurrency }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        let digits = formatter.maximumFractionDigits
        guard (0...4).contains(digits) else { throw ReceiptError.invalidCurrency }
        digitsByCurrency.withLock { $0[currency] = digits }
        return digits
    }

    public init(decimal: String, currency: String) throws {
        let zero = try Money(minorUnits: 0, currency: currency)
        let value = decimal.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) || $0 == 46 }),
              (1...2).contains(parts.count), !parts[0].isEmpty,
              let whole = Int64(parts[0]) else { throw ReceiptError.invalidAmount }
        let fractional = parts.count == 2 ? String(parts[1]) : ""
        guard (parts.count == 1 || !fractional.isEmpty), fractional.count <= zero.fractionDigits else { throw ReceiptError.invalidAmount }
        let scale = (0..<zero.fractionDigits).reduce(Int64(1)) { value, _ in value * 10 }
        let multiplied = whole.multipliedReportingOverflow(by: scale)
        let padded = fractional + String(repeating: "0", count: zero.fractionDigits - fractional.count)
        let added = multiplied.partialValue.addingReportingOverflow(Int64(padded) ?? 0)
        guard !multiplied.overflow, !added.overflow else { throw ReceiptError.invalidAmount }
        try self.init(minorUnits: added.partialValue, currency: currency)
    }

    public var decimal: String {
        guard fractionDigits > 0 else { return String(minorUnits) }
        let scale = (0..<fractionDigits).reduce(Int64(1)) { value, _ in value * 10 }
        let fraction = String(minorUnits % scale)
        return "\(minorUnits / scale)." + String(repeating: "0", count: fractionDigits - fraction.count) + fraction
    }
}
