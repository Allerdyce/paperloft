import Foundation

/// Header hints fill absent fields only. Their provenance survives persistence and
/// keeps the result in review even when all required fields are now syntactically valid.
public enum MailFieldHints {
    public static func apply(to fields: ExtractedFields, envelope: MailEnvelope?) -> ExtractedFields {
        guard let envelope, fields.kind != "not_receipt" else { return fields }
        var result = fields
        if (fields.date ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let date = envelope.date.flatMap(receiptDate) {
            result.date = date
            result.emailDateHint = true
        }
        if (fields.vendor ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let vendor = envelope.from.flatMap(senderName) {
            result.vendor = vendor
            result.emailVendorHint = true
        }
        return result
    }

    private static func receiptDate(_ header: String) -> String? {
        // Keep the sender's calendar day, rather than shifting midnight across time zones.
        guard header.utf8.count <= 4096,
              let range = header.range(of: #"^(?:[A-Za-z]{3},\s*)?\d{1,2}\s+[A-Za-z]{3}\s+\d{4}(?=\s|$)"#, options: .regularExpression) else { return nil }
        let value = String(header[range]).replacingOccurrences(of: #"^[A-Za-z]{3},\s*"#, with: "", options: .regularExpression)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.isLenient = false
        formatter.dateFormat = "d MMM yyyy"
        guard let date = formatter.date(from: value) else { return nil }
        formatter.dateFormat = "yyyy-MM-dd"
        let iso = formatter.string(from: date)
        return (try? ReceiptDate(iso8601: iso)) == nil ? nil : iso
    }

    private static func senderName(_ header: String) -> String? {
        guard header.utf8.count <= 4096,
              !header.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)
        if let bracket = trimmed.firstIndex(of: "<") {
            let display = trimmed[..<bracket].trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\"")))
            if !display.isEmpty, display.count <= 120, !display.contains("@") { return display }
        }
        guard let at = trimmed.lastIndex(of: "@") else { return nil }
        let domain = trimmed[trimmed.index(after: at)...].trimmingCharacters(in: CharacterSet(charactersIn: "> "))
        let parts = domain.split(separator: ".")
        guard parts.count >= 2, let first = parts.first, first.count <= 63,
              domain.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == "." || $0 == "-" }) else { return nil }
        return first.replacingOccurrences(of: "-", with: " ").capitalized
    }
}
