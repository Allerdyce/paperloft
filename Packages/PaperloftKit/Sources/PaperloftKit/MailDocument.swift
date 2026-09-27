import Foundation

/// Parses only bytes explicitly supplied by the caller. It never opens files or URLs.
public struct MailDocument: Sendable, Equatable {
    public struct PDF: Sendable, Equatable {
        /// A display hint, never an output path. Callers must create their own unique destination.
        public let name: String
        public let data: Data
    }
    public let body: String
    public let pdfs: [PDF]
    public let notices: [String]
    public private(set) var envelope: MailEnvelope? = nil
    private var containsPlainBody = false

    public enum Failure: Error, LocalizedError, Equatable {
        case malformed(String), unsupported(String), limit(String)
        public var errorDescription: String? {
            switch self {
            case .malformed(let reason): "The email is malformed: \(reason)."
            case .unsupported(let reason): "This email cannot be read: \(reason)."
            case .limit(let reason): "The email exceeds the safe import limit: \(reason)."
            }
        }
    }

    // Fixed limits keep untrusted MIME input from causing unbounded recursion/allocation.
    public static let maximumBytes = 50 * 1024 * 1024
    public static let maximumPDFBytes = 16 * 1024 * 1024
    public static let maximumBodyBytes = 1024 * 1024
    public static let maximumParts = 100
    public static let maximumDepth = 8
    public static let maximumPDFs = 20

    public static func parse(_ data: Data) throws -> MailDocument {
        guard data.count <= maximumBytes else { throw Failure.limit("50 MB message") }
        var parser = Parser()
        var result = try parser.entity(Array(data), depth: 0)
        result.envelope = parser.envelope
        guard !result.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !result.pdfs.isEmpty else {
            throw Failure.unsupported("no readable body or PDF attachment; save a PDF from Mail instead")
        }
        return result
    }

    private struct Parser {
        var parts = 0
        var pdfCount = 0
        var textBytes = 0
        var envelope: MailEnvelope?

        mutating func entity(_ bytes: [UInt8], depth: Int) throws -> MailDocument {
            guard depth <= maximumDepth else { throw Failure.limit("MIME nesting") }
            parts += 1
            guard parts <= maximumParts else { throw Failure.limit("100 MIME parts") }
            let (headers, raw) = try splitHeaders(bytes)
            if depth == 0 { envelope = MailEnvelope(headers: headers) }
            let content = try parameters(headers["content-type"] ?? "text/plain; charset=us-ascii")
            let disposition = try parameters(headers["content-disposition"] ?? "inline")
            let encoding = (headers["content-transfer-encoding"] ?? "7bit").lowercased()
            if content.0.hasPrefix("multipart/") {
                guard ["7bit", "8bit", "binary"].contains(encoding) else { throw Failure.malformed("encoded multipart") }
                guard ["multipart/mixed", "multipart/alternative", "multipart/related"].contains(content.0) else {
                    throw Failure.unsupported("\(content.0) container")
                }
                guard let boundary = content.1["boundary"], !boundary.isEmpty, boundary.utf8.count <= 70,
                      boundary.utf8.allSatisfy({ $0 >= 32 && $0 < 127 }), !boundary.hasSuffix(" ") else {
                    throw Failure.malformed("missing or invalid multipart boundary")
                }
                let children = try splitMultipart(raw, boundary: boundary)
                var bodies: [(String, Bool)] = [], pdfs: [PDF] = [], notices: [String] = []
                for child in children {
                    let result = try entity(child, depth: depth + 1)
                    if !result.body.isEmpty { bodies.append((result.body, result.containsPlainBody)) }
                    pdfs += result.pdfs; notices += result.notices
                }
                // Alternative representations describe the same message, not multiple receipts.
                let body = content.0 == "multipart/alternative" ? (bodies.first(where: { $0.1 }) ?? bodies.first)?.0 ?? "" : bodies.map(\.0).joined(separator: "\n\n")
                return MailDocument(body: body, pdfs: pdfs, notices: notices, containsPlainBody: bodies.contains { $0.1 })
            }
            if content.0 == "message/rfc822" {
                // Forwarded messages share the same global depth/part/body budgets.
                // Decode only the supplied bytes; never retrieve an external message.
                return try entity(decode(raw, encoding: encoding), depth: depth + 1)
            }
            let filename = disposition.1["filename"] ?? content.1["name"] ?? "Attachment"
            let isPDF = content.0 == "application/pdf" || (content.0 == "application/octet-stream" && filename.lowercased().hasSuffix(".pdf"))
            let isText = content.0 == "text/plain" || content.0 == "text/html"
            guard isText || isPDF else {
                return MailDocument(body: "", pdfs: [], notices: ["Ignored \(content.0) content; external resources were not loaded."])
            }
            if isText, disposition.0 == "attachment" {
                return MailDocument(body: "", pdfs: [], notices: ["Ignored non-PDF attachment."])
            }
            let decoded = try decode(raw, encoding: encoding)
            if isPDF {
                guard decoded.count <= maximumPDFBytes else { throw Failure.limit("16 MB PDF") }
                guard decoded.starts(with: Array("%PDF-".utf8)) else { throw Failure.malformed("PDF attachment has no PDF signature") }
                pdfCount += 1
                guard pdfCount <= maximumPDFs else { throw Failure.limit("20 PDF attachments") }
                let name = safeName(filename)
                return MailDocument(body: "", pdfs: [PDF(name: name, data: Data(decoded))], notices: [])
            }
            textBytes += decoded.count
            guard textBytes <= maximumBodyBytes else { throw Failure.limit("1 MB text body") }
            let charset = (content.1["charset"] ?? "us-ascii").lowercased()
            let text: String?
            switch charset {
            case "utf-8", "utf8": text = String(bytes: decoded, encoding: .utf8)
            case "us-ascii", "ascii": text = decoded.allSatisfy { $0 < 128 } ? String(bytes: decoded, encoding: .utf8) : nil
            case "iso-8859-1", "latin1": text = String(String.UnicodeScalarView(decoded.map { UnicodeScalar($0) }))
            case "windows-1252": text = String(data: Data(decoded), encoding: .windowsCP1252)
            default: throw Failure.unsupported("text character set \(charset)")
            }
            guard let text, !text.contains("\0") else { throw Failure.malformed("invalid text encoding") }
            let body = content.0 == "text/html" ? try HTMLText.extract(text) : text
            return MailDocument(body: body, pdfs: [], notices: [], containsPlainBody: content.0 == "text/plain")
        }

        func splitHeaders(_ bytes: [UInt8]) throws -> ([String: String], [UInt8]) {
            var position = 0, lines: [String] = [], found = false
            while position < bytes.count {
                let start = position
                while position < bytes.count && bytes[position] != 10 { position += 1 }
                var end = position
                if end > start && bytes[end - 1] == 13 { end -= 1 }
                if position < bytes.count { position += 1 }
                guard position <= 65_536 else { throw Failure.limit("64 KB headers") }
                if start == end { found = true; break }
                guard let line = String(bytes: bytes[start..<end], encoding: .utf8),
                      !line.unicodeScalars.contains(where: { $0.value < 32 && $0.value != 9 }) else {
                    throw Failure.malformed("invalid header")
                }
                if line.hasPrefix(" ") || line.hasPrefix("\t") {
                    guard !lines.isEmpty else { throw Failure.malformed("orphan folded header") }
                    lines[lines.count - 1] += " " + line.trimmingCharacters(in: .whitespaces)
                } else { lines.append(line) }
            }
            guard found else { throw Failure.malformed("missing header/body separator") }
            var result: [String: String] = [:]
            for line in lines {
                guard let colon = line.firstIndex(of: ":") else { throw Failure.malformed("header without colon") }
                let name = String(line[..<colon]).lowercased()
                guard !name.isEmpty, name.utf8.allSatisfy({ $0 > 32 && $0 < 127 && $0 != 58 }) else {
                    throw Failure.malformed("invalid header name")
                }
                if name.hasPrefix("content-") || ["from", "to", "date", "subject", "message-id"].contains(name) {
                    guard result[name] == nil else { throw Failure.malformed("duplicate \(name) header") }
                    result[name] = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                }
            }
            return (result, Array(bytes[position...]))
        }

        func parameters(_ value: String) throws -> (String, [String: String]) {
            var fields: [String] = [], field = "", quoted = false, escaped = false
            for c in value {
                if escaped { field.append(c); escaped = false }
                else if c == "\\" && quoted { escaped = true }
                else if c == "\"" { quoted.toggle() }
                else if c == ";" && !quoted { fields.append(field); field = "" }
                else { field.append(c) }
            }
            guard !quoted && !escaped else { throw Failure.malformed("unterminated MIME parameter") }
            fields.append(field)
            let type = fields.removeFirst().trimmingCharacters(in: .whitespaces).lowercased()
            var result: [String: String] = [:]
            for field in fields {
                guard let equal = field.firstIndex(of: "=") else { throw Failure.malformed("invalid MIME parameter") }
                let name = field[..<equal].trimmingCharacters(in: .whitespaces).lowercased()
                guard result[name] == nil else { throw Failure.malformed("duplicate MIME parameter") }
                result[name] = field[field.index(after: equal)...].trimmingCharacters(in: .whitespaces)
            }
            return (type, result)
        }

        func splitMultipart(_ bytes: [UInt8], boundary: String) throws -> [[UInt8]] {
            let marker = Array(("--" + boundary).utf8)
            var parts: [[UInt8]] = [], start: Int?, position = 0, closed = false
            while position < bytes.count {
                let lineStart = position
                while position < bytes.count && bytes[position] != 10 { position += 1 }
                var end = position
                if end > lineStart && bytes[end - 1] == 13 { end -= 1 }
                while end > lineStart && (bytes[end - 1] == 32 || bytes[end - 1] == 9) { end -= 1 }
                if position < bytes.count { position += 1 }
                let line = Array(bytes[lineStart..<end])
                if line == marker || line == marker + [45, 45] {
                    if let start {
                        var partEnd = lineStart
                        if partEnd > start && bytes[partEnd - 1] == 10 { partEnd -= 1 }
                        if partEnd > start && bytes[partEnd - 1] == 13 { partEnd -= 1 }
                        parts.append(Array(bytes[start..<partEnd]))
                        guard parts.count <= maximumParts else { throw Failure.limit("100 MIME parts") }
                    }
                    if line == marker + [45, 45] { closed = true; break }
                    start = position
                }
            }
            guard closed && !parts.isEmpty else { throw Failure.malformed("incomplete multipart message") }
            return parts
        }

        func decode(_ bytes: [UInt8], encoding: String) throws -> [UInt8] {
            switch encoding {
            case "7bit":
                guard bytes.allSatisfy({ $0 < 128 }) else { throw Failure.malformed("non-ASCII 7bit content") }
                return bytes
            case "8bit", "binary": return bytes
            case "base64":
                let compact = bytes.filter { ![9, 10, 13, 32].contains($0) }
                guard let data = Data(base64Encoded: Data(compact)) else { throw Failure.malformed("invalid base64") }
                return Array(data)
            case "quoted-printable":
                var result: [UInt8] = [], i = 0
                while i < bytes.count {
                    if bytes[i] != 61 { result.append(bytes[i]); i += 1; continue }
                    if i + 1 < bytes.count && bytes[i + 1] == 10 { i += 2; continue }
                    if i + 2 < bytes.count && bytes[i + 1] == 13 && bytes[i + 2] == 10 { i += 3; continue }
                    guard i + 2 < bytes.count, let high = hex(bytes[i + 1]), let low = hex(bytes[i + 2]) else {
                        throw Failure.malformed("invalid quoted-printable escape")
                    }
                    result.append(high * 16 + low); i += 3
                }
                return result
            default: throw Failure.unsupported("transfer encoding \(encoding)")
            }
        }
        func hex(_ byte: UInt8) -> UInt8? {
            switch byte { case 48...57: byte - 48; case 65...70: byte - 55; case 97...102: byte - 87; default: nil }
        }
        func safeName(_ name: String) -> String {
            var result = ""
            for scalar in name.unicodeScalars {
                let piece = CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" || scalar == " " ? String(scalar) : "_"
                if result.utf8.count + piece.utf8.count > 100 { break }
                result += piece
            }
            result = result.trimmingCharacters(in: .whitespaces)
            return (result.isEmpty ? "Attachment" : result) + ".pdf"
        }
    }
}

/// A deliberately non-rendering tokenizer: attributes and external resource URLs are discarded.
/// No DOM, scripts, CSS, images or document loaders are involved.
private enum HTMLText {
    static func extract(_ html: String) throws -> String {
        let chars = Array(html)
        var i = 0, output = "", hidden: [String] = []
        let blocks: Set<String> = ["p", "div", "br", "tr", "td", "th", "li", "table", "h1", "h2", "h3", "hr"]
        while i < chars.count {
            // Script/style content is raw text, including comparison operators and angle brackets.
            if let current = hidden.last, current == "script" || current == "style" {
                let marker = Array(("</" + current).utf8)
                let end = i + marker.count
                let matches = end < chars.count && String(chars[i..<end]).lowercased() == "</" + current
                    && (chars[end] == ">" || chars[end].isWhitespace)
                if !matches { i += 1; continue }
            }
            if chars[i] == "<" {
                if i + 3 < chars.count && String(chars[i...i+3]) == "<!--" {
                    i += 4
                    while i + 2 < chars.count && String(chars[i...i+2]) != "-->" { i += 1 }
                    guard i + 2 < chars.count else { throw MailDocument.Failure.malformed("unterminated HTML comment") }
                    i += 3; continue
                }
                i += 1
                var tag = "", quote: Character?
                while i < chars.count {
                    let c = chars[i]
                    if let current = quote { if c == current { quote = nil } }
                    else if c == "\"" || c == "'" { quote = c }
                    else if c == ">" { break }
                    tag.append(c); i += 1
                }
                guard i < chars.count else { throw MailDocument.Failure.malformed("unterminated HTML tag") }
                i += 1
                let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let closing = trimmed.hasPrefix("/")
                let name = trimmed.drop(while: { $0 == "/" }).prefix(while: { $0.isLetter || $0.isNumber })
                if closing, let current = hidden.last, name == current { hidden.removeLast() }
                else if ["script", "style", "head", "template"].contains(String(name)) && !closing {
                    guard hidden.count < 64 else { throw MailDocument.Failure.limit("HTML nesting") }
                    hidden.append(String(name))
                } else if hidden.isEmpty && blocks.contains(String(name)) { output += "\n" }
                continue
            }
            if hidden.isEmpty {
                if chars[i] == "&", let end = chars[(i + 1)...].prefix(12).firstIndex(of: ";") {
                    let entity = String(chars[(i + 1)..<end])
                    guard let decoded = decodeEntity(entity) else { throw MailDocument.Failure.unsupported("HTML entity &\(entity);") }
                    output += decoded; i = end + 1; continue
                }
                output.append(chars[i])
            }
            i += 1
        }
        guard hidden.isEmpty else { throw MailDocument.Failure.malformed("unterminated hidden HTML section") }
        return output.split(whereSeparator: { $0.isNewline }).map {
            $0.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        }.filter { !$0.isEmpty }.joined(separator: "\n")
    }
    private static func decodeEntity(_ entity: String) -> String? {
        let named = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ", "pound": "£", "euro": "€", "cent": "¢", "yen": "¥", "copy": "©"]
        if let value = named[entity] { return value }
        let latin = "nbsp iexcl cent pound curren yen brvbar sect uml copy ordf laquo not shy reg macr deg plusmn sup2 sup3 acute micro para middot cedil sup1 ordm raquo frac14 frac12 frac34 iquest Agrave Aacute Acirc Atilde Auml Aring AElig Ccedil Egrave Eacute Ecirc Euml Igrave Iacute Icirc Iuml ETH Ntilde Ograve Oacute Ocirc Otilde Ouml times Oslash Ugrave Uacute Ucirc Uuml Yacute THORN szlig agrave aacute acirc atilde auml aring aelig ccedil egrave eacute ecirc euml igrave iacute icirc iuml eth ntilde ograve oacute ocirc otilde ouml divide oslash ugrave uacute ucirc uuml yacute thorn yuml".split(separator: " ")
        if let index = latin.firstIndex(of: Substring(entity)), let scalar = UnicodeScalar(index + 160) { return String(scalar) }
        let punctuation = ["ndash": "–", "mdash": "—", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”", "hellip": "…", "bull": "•", "trade": "™", "OElig": "Œ", "oelig": "œ"]
        if let value = punctuation[entity] { return value }
        guard entity.hasPrefix("#") else { return nil }
        let hex = entity.lowercased().hasPrefix("#x")
        guard let value = UInt32(entity.dropFirst(hex ? 2 : 1), radix: hex ? 16 : 10),
              value >= 32, let scalar = UnicodeScalar(value) else { return nil }
        return String(scalar)
    }
}
