import Foundation
import CryptoKit
import Darwin

public enum LibraryError: Error, LocalizedError, Sendable {
    case missingLibrary, busy, unsafePath, unsupportedFile, corruptJournal
    case duplicate(String), sourceChanged(String), conflict(String), invalidMetadata(String)

    public var errorDescription: String? {
        switch self {
        case .missingLibrary: "The library folder is unavailable. Choose it again to continue."
        case .busy: "Another filing operation is using this library. Try again when it finishes."
        case .unsafePath: "A library path points outside the selected folder or uses a symbolic link."
        case .unsupportedFile: "Choose a PDF, PNG, JPEG, or HEIC document."
        case .corruptJournal: "The filing history could not be read. Documents have been preserved."
        case .duplicate(let path): "This document is already filed at \(path). Review the duplicate before continuing."
        case .sourceChanged(let path): "The source changed during filing: \(path). Both versions have been preserved."
        case .conflict(let path): "A file changed or already exists at \(path). Nothing was overwritten."
        case .invalidMetadata(let path): "Receipt details could not be read for \(path). Review this document."
        }
    }
}

public struct FiledDocument: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { receipt.id }
    public let receipt: Receipt
    public let contentHash: String
    public var relativePath: String
    public let filedAt: Date
}

struct FileIdentity: Codable, Equatable, Sendable {
    let device: Int32
    let inode: UInt64
}

enum LibraryFiles {
    static let metadataName = "app.paperloft.receipt"
    static let extensions: Set<String> = ["pdf", "png", "jpg", "jpeg", "heic", "tif", "tiff"]

    static func identity(_ url: URL) throws -> FileIdentity {
        var information = stat()
        guard lstat(url.path, &information) == 0,
              information.st_mode & S_IFMT == S_IFREG else { throw LibraryError.unsafePath }
        return FileIdentity(device: information.st_dev, inode: information.st_ino)
    }

    static func hash(_ url: URL) throws -> String {
        _ = try identity(url)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty { hash.update(data: data) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func exists(_ url: URL) -> Bool {
        var information = stat()
        return lstat(url.path, &information) == 0
    }

    static func directory(_ url: URL) throws {
        var information = stat()
        guard lstat(url.path, &information) == 0, information.st_mode & S_IFMT == S_IFDIR else { throw LibraryError.unsafePath }
    }

    static func createDirectory(_ url: URL) throws {
        if mkdir(url.path, 0o700) != 0 && errno != EEXIST { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        try directory(url)
    }

    static func renameExclusive(_ source: URL, _ destination: URL) throws {
        guard renamex_np(source.path, destination.path, UInt32(RENAME_EXCL)) == 0 else {
            if errno == EEXIST { throw LibraryError.conflict(destination.path) }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    static func metadata(_ url: URL) throws -> FiledDocument? {
        _ = try identity(url)
        let size = getxattr(url.path, metadataName, nil, 0, 0, XATTR_NOFOLLOW)
        if size < 0 && errno == ENOATTR { return nil }
        guard size > 0, size <= 131_072 else { throw LibraryError.invalidMetadata(url.lastPathComponent) }
        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { bytes in
            getxattr(url.path, metadataName, bytes.baseAddress, size, 0, XATTR_NOFOLLOW)
        }
        guard read == size, let result = try? JSONDecoder().decode(FiledDocument.self, from: data) else {
            throw LibraryError.invalidMetadata(url.lastPathComponent)
        }
        return result
    }

    static func setMetadata(_ metadata: FiledDocument, at url: URL) throws {
        let data = try JSONEncoder().encode(metadata)
        guard data.count <= 131_072 else { throw LibraryError.invalidMetadata(url.lastPathComponent) }
        let result = data.withUnsafeBytes { bytes in
            setxattr(url.path, metadataName, bytes.baseAddress, bytes.count, 0, XATTR_NOFOLLOW)
        }
        guard result == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }

    static func persist<T: Encodable>(_ value: T, at url: URL) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
        try synchronize(url)
    }

    static func synchronize(_ url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }

    static func safeFolder(_ value: String) -> String {
        let words = value.split(whereSeparator: \.isWhitespace).map { ReceiptFilename.safeComponent(String($0)) }
        var result = ""
        for character in words.joined(separator: " ") {
            guard result.utf8.count + String(character).utf8.count <= 100 else { break }
            result.append(character)
        }
        return result.isEmpty ? "Uncategorized" : result
    }
}
