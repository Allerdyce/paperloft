import Foundation
import CryptoKit
import Darwin

public enum IntakeSource: String, Codable, Sendable { case fileImport, drop, paste, watchedFolder, mail, share, scan, sample }
public struct IntakeSourceMetadata: Codable, Equatable, Sendable {
    public let detail: String?
    public let mailSubject: String?
    public let mailSender: String?
    public let mailDate: Date?
    public init(detail: String? = nil, mailSubject: String? = nil, mailSender: String? = nil, mailDate: Date? = nil) {
        self.detail = detail; self.mailSubject = mailSubject; self.mailSender = mailSender; self.mailDate = mailDate
    }
    fileprivate var isValid: Bool {
        [detail, mailSubject, mailSender].allSatisfy { $0.map { $0.utf8.count <= 4096 && !$0.contains("\0") } ?? true }
            && (mailDate?.timeIntervalSince1970.isFinite ?? true)
    }
}
public struct IntakeRecord: Codable, Equatable, Sendable {
    public let id: UUID
    public let origin: IntakeSource
    public let metadata: IntakeSourceMetadata?
    public let displayName: String
    public let receivedAt: Date
    public let fileExtension: String
    public let contentHash: String
    public let byteCount: Int64
    public var relativePayloadPath: String { id.uuidString + "/payload." + fileExtension }
}

/// Owned staging only, not a second receipt/delivery ledger. The caller must commit
/// its inbox and source-specific proofs before acknowledging any upstream source.
/// Originals and their move permissions remain the caller's responsibility.
/// `directory` must be an app-private, stable container directory. The app owns
/// its lifetime, creates the parent directory beforehand, and serializes discard against consumers. Published records are
/// never automatically removed; incomplete hidden stages are not publications.
public actor IntakeQueue {
    public enum Failure: Error, LocalizedError {
        case unsafePath, unsupportedType, tooLarge, empty, changed, conflict, corrupt
        public var errorDescription: String? {
            switch self {
            case .unsafePath: "Import a regular receipt file rather than a link."
            case .unsupportedType: "Import a PDF, PNG, JPEG, HEIC, TIFF or EML file."
            case .tooLarge: "This file or its source details exceed the import size limit. Try a smaller file."
            case .empty: "This file is empty. Wait for it to finish saving, then import it again."
            case .changed: "This file changed while importing. Wait for it to finish saving, then import it again."
            case .conflict: "This import already has a different saved copy. Import the receipt again as a new item."
            case .corrupt: "The saved intake copy or its details could not be verified. Reimport the original receipt."
            }
        }
    }
    private static let maximumRecordBytes = 16_384
    public static let maximumFileBytes: Int64 = 200_000_000
    private let directory: URL
    private let rootFD: Int32
    private var beforePublicationSync: (@Sendable () throws -> Void)?
    func observePublicationSync(_ observer: (@Sendable () throws -> Void)?) { beforePublicationSync = observer }
    private var didCopyChunk: (@Sendable () throws -> Void)?
    // Internal deterministic failure seam; production leaves it unset.
    func observeCopy(_ observer: @escaping @Sendable () throws -> Void) { didCopyChunk = observer }
    public init(directory: URL) throws {
        guard directory.isFileURL else { throw Failure.unsafePath }
        guard mkdir(directory.path, 0o700) == 0 || errno == EEXIST else { throw Self.posix() }
        // Persist the new queue entry before any publication can depend on it.
        try Self.syncDirectory(directory.deletingLastPathComponent())
        rootFD = try Self.openSafe(directory, flags: O_EXEC | O_DIRECTORY)
        self.directory = directory
    }
    deinit { close(rootFD) }

    /// A stable ID represents immutable content, origin, display name and type.
    /// Retrying it returns the first publication (including its original timestamp).
    public func enqueue(source: URL, id: UUID = UUID(), origin: IntakeSource,
                        displayName: String? = nil, metadata: IntakeSourceMetadata? = nil, receivedAt: Date = Date(),
                        maximumBytes: Int64 = maximumFileBytes) throws -> IntakeRecord {
        try Task.checkCancellation()
        let ext = source.pathExtension.lowercased(), name = displayName ?? source.lastPathComponent
        guard LibraryFiles.extensions.contains(ext) || ext == "eml" else { throw Failure.unsupportedType }
        guard !name.isEmpty, name.utf8.count <= 1024, !name.contains("\0"), receivedAt.timeIntervalSince1970.isFinite else { throw Failure.corrupt }
        guard metadata?.isValid ?? true else { throw Failure.corrupt }
        guard maximumBytes > 0, maximumBytes <= Self.maximumFileBytes else { throw Failure.tooLarge }
        let stageName = ".incoming-" + UUID().uuidString
        guard mkdirat(rootFD, stageName, 0o700) == 0 else { throw Self.posix() }
        let stage = directory.appendingPathComponent(stageName, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: stage) }
        let payload = stage.appendingPathComponent("payload." + ext)
        let copied = try Self.copyAndHash(source, to: payload, limit: maximumBytes, didCopyChunk: didCopyChunk)
        let record = IntakeRecord(id: id, origin: origin, metadata: metadata, displayName: name, receivedAt: receivedAt,
                                  fileExtension: ext, contentHash: copied.0, byteCount: copied.1)
        let encoded = try JSONEncoder().encode(record)
        guard encoded.count <= Self.maximumRecordBytes else { throw Failure.tooLarge }
        try Self.write(encoded, to: stage.appendingPathComponent("record.json"))
        try Self.syncDirectory(stage)
        try Task.checkCancellation()
        if renameatx_np(rootFD, stageName, rootFD, id.uuidString, UInt32(RENAME_EXCL)) != 0 {
            guard errno == EEXIST else { throw Self.posix() }
            let existing = try read(id)
            guard existing.origin == origin, existing.metadata == metadata, existing.displayName == name, existing.fileExtension == ext,
                  existing.contentHash == record.contentHash, existing.byteCount == record.byteCount else { throw Failure.conflict }
            try beforePublicationSync?()
            try Self.syncDirectory(directory)
            return existing
        }
        // No cancellation check after publication: successful publication must be
        // returned. A sync error may leave a complete record; retry the same ID.
        try beforePublicationSync?()
        try Self.syncDirectory(directory)
        return record
    }

    public func record(id: UUID) throws -> IntakeRecord { try read(id) }
    public func payloadURL(for record: IntakeRecord) throws -> URL {
        guard try read(record.id) == record else { throw Failure.conflict }
        return directory.appendingPathComponent(record.relativePayloadPath)
    }
    /// Explicitly discard only a matching, verified owned record. The caller must
    /// first ensure that no durable inbox/reference still needs these bytes.
    public func discard(_ record: IntakeRecord) throws {
        guard try read(record.id) == record else { throw Failure.conflict }
        let folder = directory.appendingPathComponent(record.id.uuidString)
        let children = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        guard Set(children) == Set(["record.json", "payload." + record.fileExtension]) else { throw Failure.corrupt }
        try FileManager.default.removeItem(at: folder)
        try Self.syncDirectory(directory)
    }
    private func read(_ id: UUID) throws -> IntakeRecord {
        let folder = directory.appendingPathComponent(id.uuidString)
        let metadata = try Self.openSafe(folder.appendingPathComponent("record.json"), flags: O_RDONLY)
        let input = FileHandle(fileDescriptor: metadata, closeOnDealloc: true)
        defer { try? input.close() }
        let info = try Self.regular(metadata)
        guard info.st_size > 0, info.st_size <= Self.maximumRecordBytes,
              let bytes = try input.read(upToCount: Self.maximumRecordBytes + 1), bytes.count <= Self.maximumRecordBytes else { throw Failure.corrupt }
        let record = try JSONDecoder().decode(IntakeRecord.self, from: bytes)
        guard record.id == id, LibraryFiles.extensions.contains(record.fileExtension) || record.fileExtension == "eml",
              record.byteCount > 0, record.byteCount <= Self.maximumFileBytes,
              record.displayName.utf8.count <= 1024, !record.displayName.isEmpty, !record.displayName.contains("\0"),
              record.receivedAt.timeIntervalSince1970.isFinite, record.metadata?.isValid ?? true,
              record.contentHash.count == 64, record.contentHash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { throw Failure.corrupt }
        let actual = try Self.copyAndHash(folder.appendingPathComponent("payload." + record.fileExtension), to: nil, limit: Self.maximumFileBytes)
        guard actual.0 == record.contentHash, actual.1 == record.byteCount else { throw Failure.corrupt }
        return record
    }
    private static func copyAndHash(_ source: URL, to destination: URL?, limit: Int64, didCopyChunk: (@Sendable () throws -> Void)? = nil) throws -> (String, Int64) {
        let fd = try openSafe(source, flags: O_RDONLY)
        defer { close(fd) }
        let before = try regular(fd)
        guard before.st_size > 0 else { throw Failure.empty }
        guard before.st_size <= limit else { throw Failure.tooLarge }
        let outputFD = try destination.map { try openSafe($0, flags: O_WRONLY | O_CREAT | O_EXCL) }
        defer { if let outputFD { close(outputFD) } }
        let reader = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        let writer = outputFD.map { FileHandle(fileDescriptor: $0, closeOnDealloc: false) }
        var hash = SHA256(), count: Int64 = 0
        while try autoreleasepool(invoking: {
            try Task.checkCancellation()
            guard let data = try reader.read(upToCount: 262_144), !data.isEmpty else { return false }
            count += Int64(data.count)
            guard count <= limit else { throw Failure.tooLarge }
            hash.update(data: data); try writer?.write(contentsOf: data)
            try didCopyChunk?()
            return true
        }) { }
        let after = try regular(fd)
        guard before.st_dev == after.st_dev, before.st_ino == after.st_ino, before.st_size == count, after.st_size == count,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec, before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec, before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec else { throw Failure.changed }
        let currentFD = try openSafe(source, flags: O_RDONLY)
        defer { close(currentFD) }
        let current = try regular(currentFD)
        guard current.st_dev == before.st_dev, current.st_ino == before.st_ino else { throw Failure.changed }
        try writer?.synchronize()
        return (hash.finalize().map { String(format: "%02x", $0) }.joined(), count)
    }
    private static func write(_ data: Data, to url: URL) throws {
        let fd = try openSafe(url, flags: O_WRONLY | O_CREAT | O_EXCL)
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        try handle.write(contentsOf: data); try handle.synchronize()
    }
    private static func syncDirectory(_ url: URL) throws {
        let fd = try openSafe(url, flags: O_RDONLY | O_DIRECTORY)
        defer { close(fd) }
        guard fsync(fd) == 0 else { throw posix() }
    }
    private static func regular(_ fd: Int32) throws -> stat {
        var info = stat()
        guard fstat(fd, &info) == 0 else { throw posix() }
        guard info.st_mode & S_IFMT == S_IFREG else { throw Failure.unsafePath }
        return info
    }
    private static func openSafe(_ url: URL, flags: Int32) throws -> Int32 {
        guard url.isFileURL, !url.path.contains("\0"), !url.pathComponents.contains("..") else { throw Failure.unsafePath }
        var path = url.path
        if path.hasPrefix("/var/") || path.hasPrefix("/tmp/") { path = "/private" + path }
        let parts = URL(fileURLWithPath: path).pathComponents
        guard parts.count > 1, let leaf = parts.last, leaf != "." else { throw Failure.unsafePath }
        var fd = open("/", O_EXEC | O_DIRECTORY | O_CLOEXEC)
        guard fd >= 0 else { throw posix() }
        defer { close(fd) }
        for part in parts.dropFirst().dropLast() {
            let next = openat(fd, part, O_EXEC | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard next >= 0 else { throw posix() }
            close(fd); fd = next
        }
        let result = openat(fd, leaf, flags | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, mode_t(0o600))
        guard result >= 0 else { throw posix() }
        return result
    }
    private static func posix() -> Error { POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
}
