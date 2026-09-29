import Foundation

/// Display-only source context, never instructions or authoritative receipt fields.
public struct MailEnvelope: Sendable, Equatable {
    public let from: String?
    public let to: String?
    public let date: String?
    public let subject: String?
    public let messageID: String?

    init(headers: [String: String]) {
        from = headers["from"].map(Self.decodedWords)
        to = headers["to"].map(Self.decodedWords)
        date = headers["date"]
        subject = headers["subject"].map(Self.decodedWords)
        messageID = headers["message-id"]
    }

    static func decodedWords(_ value: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"=\?([^?\s]+)\?([bBqQ])\?([^?]*)\?="#) else { return value }
        let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))
        var result = "", cursor = value.startIndex, priorWasEncoded = false
        for match in matches {
            guard let range = Range(match.range, in: value),
                  let charsetRange = Range(match.range(at: 1), in: value),
                  let encodingRange = Range(match.range(at: 2), in: value),
                  let bodyRange = Range(match.range(at: 3), in: value) else { continue }
            let gap = String(value[cursor..<range.lowerBound])
            let body = String(value[bodyRange])
            let data: Data?
            if value[encodingRange].lowercased() == "b" { data = Data(base64Encoded: body) }
            else {
                var bytes: [UInt8] = [], source = Array(body.utf8), index = 0, valid = true
                while index < source.count {
                    if source[index] == 61 {
                        guard index + 2 < source.count,
                              let byte = UInt8(String(bytes: source[(index + 1)...(index + 2)], encoding: .utf8) ?? "", radix: 16) else { valid = false; break }
                        bytes.append(byte); index += 3
                    } else { bytes.append(source[index] == 95 ? 32 : source[index]); index += 1 }
                }
                data = valid ? Data(bytes) : nil
            }
            let encoding: String.Encoding?
            switch value[charsetRange].lowercased() {
            case "utf-8", "utf8": encoding = .utf8
            case "iso-8859-1", "latin1": encoding = .isoLatin1
            case "windows-1252": encoding = .windowsCP1252
            case "us-ascii", "ascii": encoding = .ascii
            default: encoding = nil
            }
            if let data, let encoding, let decoded = String(data: data, encoding: encoding),
               !decoded.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) {
                if !(priorWasEncoded && gap.allSatisfy(\.isWhitespace)) { result += gap }
                result += decoded; priorWasEncoded = true
            } else { result += gap + value[range]; priorWasEncoded = false }
            cursor = range.upperBound
        }
        return result + value[cursor...]
    }
}
