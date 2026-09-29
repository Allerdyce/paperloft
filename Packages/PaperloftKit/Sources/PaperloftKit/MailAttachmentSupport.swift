import Foundation
import ImageIO
import UniformTypeIdentifiers

/// MIME display metadata and bounded local image inspection. Never opens URLs.
enum MailAttachmentSupport {
    static func filename(_ parameters: [String: String], key: String) throws -> String? {
        let prefix = key + "*"
        let segments = parameters.keys.filter { $0.hasPrefix(prefix) && $0 != prefix }
        if let extended = parameters[prefix] {
            guard segments.isEmpty else { throw MailDocument.Failure.malformed("ambiguous encoded filename") }
            let (charset, body) = try extendedStart(extended)
            return try decode(percentBytes(body), charset: charset)
        }
        if !segments.isEmpty {
            var chunks: [Int: (String, Bool)] = [:]
            for segment in segments {
                let suffix = String(segment.dropFirst(prefix.count))
                let encoded = suffix.hasSuffix("*")
                let number = encoded ? String(suffix.dropLast()) : suffix
                guard let index = Int(number), index >= 0, index < 100, String(index) == number,
                      chunks[index] == nil, let value = parameters[segment] else { throw MailDocument.Failure.malformed("invalid filename continuation") }
                chunks[index] = (value, encoded)
            }
            guard let first = chunks[0], chunks.keys.sorted() == Array(0..<chunks.count) else { throw MailDocument.Failure.malformed("incomplete filename continuation") }
            if first.1 {
                let (charset, initial) = try extendedStart(first.0)
                var bytes = try percentBytes(initial)
                for index in 1..<chunks.count {
                    let chunk = chunks[index]!
                    bytes += chunk.1 ? try percentBytes(chunk.0) : Array(chunk.0.utf8)
                }
                return try decode(bytes, charset: charset)
            }
            guard chunks.values.allSatisfy({ !$0.1 }) else { throw MailDocument.Failure.malformed("encoded filename has no character set") }
            return MailEnvelope.decodedWords((0..<chunks.count).map { chunks[$0]!.0 }.joined())
        }
        return parameters[key].map(MailEnvelope.decodedWords)
    }

    private static func extendedStart(_ value: String) throws -> (String, String) {
        let parts = value.split(separator: "'", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, !parts[0].isEmpty else { throw MailDocument.Failure.malformed("encoded filename has no character set") }
        return (String(parts[0]).lowercased(), String(parts[2]))
    }
    private static func percentBytes(_ value: String) throws -> [UInt8] {
        let source = Array(value.utf8)
        var result: [UInt8] = [], index = 0
        while index < source.count {
            if source[index] == 37 {
                guard index + 2 < source.count,
                      let byte = UInt8(String(bytes: source[(index + 1)...(index + 2)], encoding: .ascii) ?? "", radix: 16) else { throw MailDocument.Failure.malformed("invalid encoded filename escape") }
                result.append(byte); index += 3
            } else { result.append(source[index]); index += 1 }
        }
        return result
    }
    private static func decode(_ bytes: [UInt8], charset: String) throws -> String {
        let encoding: String.Encoding
        switch charset {
        case "utf-8", "utf8": encoding = .utf8
        case "us-ascii", "ascii": encoding = .ascii
        case "iso-8859-1", "latin1": encoding = .isoLatin1
        case "windows-1252": encoding = .windowsCP1252
        default: throw MailDocument.Failure.unsupported("filename character set")
        }
        guard let text = String(data: Data(bytes), encoding: encoding), !text.contains("\0") else { throw MailDocument.Failure.malformed("invalid filename encoding") }
        return text
    }

    static func safeName(_ name: String, extension ext: String) -> String {
        let decoded = MailEnvelope.decodedWords(name)
        let base = (decoded as NSString).deletingPathExtension
        var result = ""
        for scalar in base.unicodeScalars {
            let piece = CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" || scalar == " " ? String(scalar) : "_"
            if result.utf8.count + piece.utf8.count > 100 { break }
            result += piece
        }
        result = result.trimmingCharacters(in: .whitespaces)
        return (result.isEmpty ? "Attachment" : result) + "." + ext
    }

    static func image(data: Data, name: String, contentID: String?, inline: Bool) -> MailDocument.ImageAttachment? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0,
              let identifier = CGImageSourceGetType(source) as String?,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width >= 200, height >= 200, width <= 49_999_999 / height else { return nil }
        let ext: String
        switch identifier {
        case UTType.jpeg.identifier: ext = "jpg"
        case UTType.png.identifier: ext = "png"
        case UTType.heic.identifier, "public.heif": ext = "heic"
        case UTType.tiff.identifier:
            guard CGImageSourceGetCount(source) == 1 else { return nil }
            ext = "tiff"
        default: return nil
        }
        return MailDocument.ImageAttachment(name: safeName(name, extension: ext), data: data, fileExtension: ext,
                                            width: width, height: height, contentID: contentID.map(normalizeContentID), inline: inline)
    }
    private static func normalizeContentID(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "<>")))
    }
    static func referencedContentIDs(in html: String) -> Set<String> {
        guard let pattern = try? NSRegularExpression(pattern: #"(?i)cid:([^\s"'<>\)]+)"#) else { return [] }
        return Set(pattern.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match in
            guard let range = Range(match.range(at: 1), in: html) else { return nil }
            let raw = String(html[range]).replacingOccurrences(of: "&amp;", with: "&")
            return normalizeContentID(raw.removingPercentEncoding ?? raw)
        })
    }
}
