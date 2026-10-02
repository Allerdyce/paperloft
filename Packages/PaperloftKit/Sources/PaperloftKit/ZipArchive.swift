import Compression
import Foundation

/// A small ZIP writer for the accountant pack. Names are precomposed (NFC) UTF-8 with the ZIP
/// "language encoding" flag set, so Windows and other unzip tools show folders such as 交通費 or
/// files such as Zürich-Bahn correctly. (The system's folder zipping stores decomposed names
/// without the flag.) Files are DEFLATE-compressed with the Compression framework, or stored when
/// that doesn't help. Archives over 4 GB or 65,535 entries are refused rather than written as ZIP64.
enum ZipArchive {
    private static let utf8Flag: UInt16 = 0x0800

    /// Writes `folder` and everything inside it, under `rootName/`, to `handle`.
    static func write(folder: URL, rootName: String, to handle: FileHandle) throws {
        var central = Data()
        var offset: UInt64 = 0
        var count = 0
        func append(_ data: Data) throws {
            try handle.write(contentsOf: data)
            offset += UInt64(data.count)
        }
        for (relative, url, isDirectory) in try entries(folder: folder, rootName: rootName) {
            let name = Data(relative.precomposedStringWithCanonicalMapping.utf8)
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            let (time, date) = dosTimeAndDate(modified)
            let original = isDirectory ? Data() : try Data(contentsOf: url)
            let crc = crc32(original)
            let deflated = isDirectory ? nil : deflate(original)
            let method: UInt16 = deflated == nil ? 0 : 8
            let stored = deflated ?? original
            guard offset < UInt64(UInt32.max), UInt64(stored.count) < UInt64(UInt32.max), UInt64(original.count) < UInt64(UInt32.max),
                  name.count <= Int(UInt16.max), count < Int(UInt16.max) else {
                throw LibraryError.conflict("The ZIP archive would be larger than 4 GB. Choose a shorter period, or use the pack folder.")
            }
            var local = Data()
            local.appendLE(UInt32(0x0403_4b50)); local.appendLE(UInt16(20)); local.appendLE(utf8Flag); local.appendLE(method)
            local.appendLE(time); local.appendLE(date); local.appendLE(crc)
            local.appendLE(UInt32(stored.count)); local.appendLE(UInt32(original.count))
            local.appendLE(UInt16(name.count)); local.appendLE(UInt16(0)); local.append(name)
            let localOffset = offset
            try append(local)
            try append(stored)
            let unixMode: UInt32 = isDirectory ? 0o040755 : 0o100644
            central.appendLE(UInt32(0x0201_4b50)); central.appendLE(UInt16(0x0314)); central.appendLE(UInt16(20))
            central.appendLE(utf8Flag); central.appendLE(method); central.appendLE(time); central.appendLE(date); central.appendLE(crc)
            central.appendLE(UInt32(stored.count)); central.appendLE(UInt32(original.count))
            central.appendLE(UInt16(name.count)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0))
            central.appendLE(UInt16(0)); central.appendLE(UInt16(0))
            central.appendLE(unixMode << 16 | (isDirectory ? 0x10 : 0)); central.appendLE(UInt32(localOffset))
            central.append(name)
            count += 1
        }
        guard offset + UInt64(central.count) < UInt64(UInt32.max) else {
            throw LibraryError.conflict("The ZIP archive would be larger than 4 GB. Choose a shorter period, or use the pack folder.")
        }
        let centralOffset = offset
        try append(central)
        var end = Data()
        end.appendLE(UInt32(0x0605_4b50)); end.appendLE(UInt16(0)); end.appendLE(UInt16(0))
        end.appendLE(UInt16(count)); end.appendLE(UInt16(count))
        end.appendLE(UInt32(central.count)); end.appendLE(UInt32(centralOffset)); end.appendLE(UInt16(0))
        try append(end)
    }

    /// The folder itself, then everything inside it, in a stable order, directories before their contents.
    private static func entries(folder: URL, rootName: String) throws -> [(String, URL, Bool)] {
        var result: [(String, URL, Bool)] = [(rootName + "/", folder, true)]
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
            throw LibraryError.unsafePath
        }
        var items: [(String, URL, Bool)] = []
        let base = folder.standardizedFileURL.path
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw LibraryError.unsafePath }
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(base + "/") else { throw LibraryError.unsafePath }
            let relative = rootName + "/" + path.dropFirst(base.count + 1)
            let isDirectory = values.isDirectory == true
            items.append((isDirectory ? relative + "/" : relative, url, isDirectory))
        }
        result += items.sorted { $0.0.precomposedStringWithCanonicalMapping < $1.0.precomposedStringWithCanonicalMapping }
        return result
    }

    /// Raw DEFLATE, or nil when it wouldn't make the file smaller.
    private static func deflate(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        let capacity = data.count + data.count / 16 + 1024
        var output = Data(count: capacity)
        let written = output.withUnsafeMutableBytes { destination in
            data.withUnsafeBytes { source in
                compression_encode_buffer(destination.bindMemory(to: UInt8.self).baseAddress!, capacity,
                                          source.bindMemory(to: UInt8.self).baseAddress!, data.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0, written < data.count else { return nil }
        return output.prefix(written)
    }

    private static let crcTable: [UInt32] = (0..<256).map { index in
        (0..<8).reduce(UInt32(index)) { value, _ in value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1 }
    }
    static func crc32(_ data: Data) -> UInt32 {
        ~data.reduce(UInt32.max) { crcTable[Int(($0 ^ UInt32($1)) & 0xFF)] ^ ($0 >> 8) }
    }

    private static func dosTimeAndDate(_ date: Date) -> (UInt16, UInt16) {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = max(1980, min(2107, parts.year ?? 1980))
        let time = UInt16((parts.hour ?? 0) << 11 | (parts.minute ?? 0) << 5 | (parts.second ?? 0) / 2)
        let day = UInt16((year - 1980) << 9 | (parts.month ?? 1) << 5 | (parts.day ?? 1))
        return (time, day)
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
