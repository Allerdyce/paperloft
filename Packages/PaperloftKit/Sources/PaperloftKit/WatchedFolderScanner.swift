import Foundation
import Darwin
import CryptoKit

/// Caller keeps the folder grant alive and enforces Pro entitlement. No files are filed or changed here.
public actor WatchedFolderScanner {
    public struct Candidate: Sendable, Equatable, Identifiable {
        public let id: UUID
        public let filename: String
        public let contentHash: String
        /// Stable across a rename on the same volume; used only with the content hash.
        public let fileIdentity: String
        public let data: Data
    }
    public struct Issue: Sendable, Equatable {
        public let filename: String
        public let message: String
    }
    public struct Scan: Sendable {
        public let candidates: [Candidate]
        public let issues: [Issue]
    }
    public enum Failure: Error, LocalizedError, Sendable {
        case unsafeLocation, unavailable, stateCorrupt, stateBusy, stateChanged, stateWrite, unknownCandidate, stateLimit
        public var errorDescription: String? {
            switch self {
            case .unsafeLocation: "Choose a real watched folder and a state file outside it; symbolic links are not supported."
            case .unavailable: "The watched folder is unavailable or was replaced. Choose it again."
            case .stateCorrupt: "Watched-folder history is unreadable. Existing documents were preserved."
            case .stateBusy: "Another scanner is using this watched-folder history."
            case .stateChanged: "Watched-folder history changed outside this scanner. Nothing was acknowledged."
            case .stateWrite: "Watched-folder history could not be saved. The document will be offered again."
            case .unknownCandidate: "This document was not offered by this scanner. Scan again before acknowledging it."
            case .stateLimit: "Watched-folder history reached its capacity (10,000 filenames or 4 MB). Choose a new watched folder and history."
            }
        }
    }
    public static let maximumFileBytes = 32 * 1024 * 1024
    public static let maximumScanBytes = 64 * 1024 * 1024
    public static let maximumEntries = 1_000
    private static let maximumHistory = 10_000
    private let root: URL
    private let rootFD: Int32
    private let stateFD: Int32
    private let lockFD: Int32
    private let stateName: String
    private let interval: Duration
    private let rootIdentity: Snapshot
    private var history: History
    private var persisted: Data?
    private var observations: [String: Observation] = [:]
    private var offered: [String: Candidate] = [:]
    private var verified: [String: (Snapshot, String)] = [:]
    private struct History: Codable {
        let version: Int
        let rootDevice: Int32
        let rootInode: UInt64
        var hashes: [String: String]
        var identities: [String: String]?
    }
    private struct Snapshot: Equatable, Sendable {
        let device: Int32, inode: UInt64, size: Int64, modified: timespec, changed: timespec
        init(_ info: stat) {
            device = info.st_dev; inode = info.st_ino; size = info.st_size
            modified = info.st_mtimespec; changed = info.st_ctimespec
        }
        var identity: String { "\(device):\(inode)" }
        static func == (a: Self, b: Self) -> Bool {
            a.device == b.device && a.inode == b.inode && a.size == b.size
                && a.modified.tv_sec == b.modified.tv_sec && a.modified.tv_nsec == b.modified.tv_nsec
                && a.changed.tv_sec == b.changed.tv_sec && a.changed.tv_nsec == b.changed.tv_nsec
        }
    }
    private struct Observation { let snapshot: Snapshot; let since: ContinuousClock.Instant }

    public init(root: URL, stateURL: URL, minimumStableInterval: Duration = .seconds(2)) throws {
        guard minimumStableInterval > .zero, Self.safeName(stateURL.lastPathComponent),
              root.isFileURL, stateURL.isFileURL else { throw Failure.unsafeLocation }
        let rootPath = root.standardizedFileURL.path
        let parent = stateURL.deletingLastPathComponent()
        guard parent.path != rootPath, !parent.path.hasPrefix(rootPath + "/") else { throw Failure.unsafeLocation }
        let openedRoot = try Self.directory(root, listing: true)
        var openedState: Int32 = -1, openedLock: Int32 = -1
        do {
            openedState = try Self.directory(parent, listing: true)
            var info = stat()
            guard fstat(openedRoot, &info) == 0 else { throw Failure.unavailable }
            let identity = Snapshot(info)
            // Check physical ancestry as well as spelling (including mount/path aliases).
            guard try !Self.isWithin(openedState, ancestor: identity) else { throw Failure.unsafeLocation }
            let name = stateURL.lastPathComponent
            openedLock = openat(openedState, "." + name + ".lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK, 0o600)
            var lockInfo = stat()
            guard openedLock >= 0, fstat(openedLock, &lockInfo) == 0,
                  lockInfo.st_mode & S_IFMT == S_IFREG, lockInfo.st_nlink == 1,
                  flock(openedLock, LOCK_EX | LOCK_NB) == 0 else { throw Failure.stateBusy }
            let bytes = try Self.readState(openedState, name)
            let loaded: History
            if let bytes {
                guard let decoded = try? JSONDecoder().decode(History.self, from: bytes), decoded.version == 1,
                      decoded.rootDevice == identity.device, decoded.rootInode == identity.inode,
                      decoded.hashes.count <= Self.maximumHistory,
                      (decoded.identities?.count ?? 0) <= Self.maximumHistory,
                      (decoded.identities ?? [:]).allSatisfy({ Self.validIdentity($0.key) && Self.validHash($0.value) }),
                      decoded.hashes.allSatisfy({ Self.safeName($0.key) && $0.value.count == 64 && $0.value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) } }) else {
                    throw Failure.stateCorrupt
                }
                loaded = decoded
            } else { loaded = History(version: 1, rootDevice: identity.device, rootInode: identity.inode, hashes: [:], identities: [:]) }
            self.root = root; rootFD = openedRoot; stateFD = openedState; lockFD = openedLock
            stateName = name; interval = minimumStableInterval; rootIdentity = identity
            history = loaded; persisted = bytes
        } catch {
            close(openedRoot)
            if openedState >= 0 { close(openedState) }
            if openedLock >= 0 { close(openedLock) }
            throw error
        }
    }
    deinit { close(rootFD); close(stateFD); close(lockFD) }

    public func scan() throws -> Scan {
        guard try Self.readState(stateFD, stateName) == persisted else { throw Failure.stateChanged }
        let reopened = try Self.directory(root, listing: false)
        defer { close(reopened) }
        var info = stat()
        guard fstat(reopened, &info) == 0, info.st_dev == rootIdentity.device, info.st_ino == rootIdentity.inode else {
            throw Failure.unavailable
        }
        // A separate open description avoids sharing the directory cursor with any previous scan.
        let listing = openat(rootFD, ".", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard listing >= 0 else { throw Failure.unavailable }
        guard let directory = fdopendir(listing) else { close(listing); throw Failure.unavailable }
        defer { closedir(directory) }
        var seen = Set<String>(), candidates: [Candidate] = [], issues: [Issue] = [], entries = 0, bytesRead = 0
        while true {
            errno = 0
            guard let entry = readdir(directory) else {
                if errno != 0 { throw Failure.unavailable }
                break
            }
            entries += 1
            guard entries <= Self.maximumEntries + 2 else {
                issues.append(Issue(filename: "", message: "Only 1,000 directory entries can be scanned. Reduce the folder contents.")); break
            }
            let name = withUnsafePointer(to: entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(validatingCString: $0) }
            }
            guard let name else { issues.append(Issue(filename: "", message: "A filename has invalid text encoding.")); continue }
            if name == "." || name == ".." { continue }
            if name.hasPrefix(".") || !Self.safeName(name) { continue }
            let ext = (name as NSString).pathExtension.lowercased()
            guard ["pdf", "png", "jpg", "jpeg", "heic", "tif", "tiff", "eml"].contains(ext) else { continue }
            var metadata = stat()
            guard fstatat(rootFD, name, &metadata, AT_SYMLINK_NOFOLLOW) == 0 else {
                issues.append(Issue(filename: name, message: "The file could not be inspected.")); continue
            }
            if metadata.st_mode & S_IFMT == S_IFDIR { continue }
            guard metadata.st_mode & S_IFMT == S_IFREG else {
                issues.append(Issue(filename: name, message: "Symbolic links and nonregular files cannot be imported.")); continue
            }
            seen.insert(name)
            guard metadata.st_size > 0, metadata.st_size <= Self.maximumFileBytes else {
                observations[name] = nil; offered[name] = nil
                issues.append(Issue(filename: name, message: "The file is empty or exceeds 32 MB.")); continue
            }
            let snapshot = Snapshot(metadata), now = ContinuousClock.now
            guard let old = observations[name], old.snapshot == snapshot else {
                observations[name] = Observation(snapshot: snapshot, since: now); offered[name] = nil; verified[name] = nil; continue
            }
            guard old.since.duration(to: now) >= interval else { continue }
            if let known = verified[name], known.0 == snapshot {
                if acknowledged(name: name, identity: snapshot.identity, hash: known.1) { continue }
                if let previous = offered[name], previous.contentHash == known.1 { candidates.append(previous); continue }
            }
            guard bytesRead + Int(snapshot.size) <= Self.maximumScanBytes,
                  offered.values.reduce(0, { $0 + $1.data.count }) + Int(snapshot.size) <= Self.maximumScanBytes else {
                issues.append(Issue(filename: name, message: "The 64 MB scan budget was reached; retry after other documents are queued.")); continue
            }
            bytesRead += Int(snapshot.size)
            do {
                let data = try readFile(name, expected: snapshot)
                let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                verified[name] = (snapshot, hash)
                if acknowledged(name: name, identity: snapshot.identity, hash: hash) { offered[name] = nil; continue }
                let candidate: Candidate
                if let previous = offered[name], previous.contentHash == hash { candidate = previous }
                else { candidate = Candidate(id: UUID(), filename: name, contentHash: hash, fileIdentity: snapshot.identity, data: data) }
                offered[name] = candidate; candidates.append(candidate)
            } catch {
                observations[name] = nil; offered[name] = nil
                issues.append(Issue(filename: name, message: "The file changed while being read or is unavailable. It will be checked again."))
            }
        }
        observations = observations.filter { seen.contains($0.key) }
        offered = offered.filter { seen.contains($0.key) }
        verified = verified.filter { seen.contains($0.key) }
        return Scan(candidates: candidates, issues: issues)
    }

    /// Call only after the candidate's bytes and review item are durably persisted in the inbox.
    public func acknowledge(_ candidate: Candidate) throws {
        guard offered[candidate.filename]?.id == candidate.id else { throw Failure.unknownCandidate }
        guard history.hashes[candidate.filename] != nil || history.hashes.count < Self.maximumHistory else { throw Failure.stateLimit }
        guard history.identities?[candidate.fileIdentity] != nil || (history.identities?.count ?? 0) < Self.maximumHistory else { throw Failure.stateLimit }
        guard try Self.readState(stateFD, stateName) == persisted else { throw Failure.stateChanged }
        var updated = history
        updated.hashes[candidate.filename] = candidate.contentHash
        if updated.identities == nil { updated.identities = [:] }
        updated.identities?[candidate.fileIdentity] = candidate.contentHash
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(updated)
        guard bytes.count <= 4 * 1024 * 1024 else { throw Failure.stateLimit }
        let temporary = ".paperloft-state-" + UUID().uuidString
        let fd = openat(stateFD, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw Failure.stateWrite }
        defer { close(fd); unlinkat(stateFD, temporary, 0) }
        do {
            try bytes.withUnsafeBytes { buffer in
                var offset = 0
                while offset < buffer.count {
                    let written = Darwin.write(fd, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                    if written < 0 && errno == EINTR { continue }
                    guard written > 0 else { throw Failure.stateWrite }
                    offset += written
                }
            }
            guard fsync(fd) == 0, renameat(stateFD, temporary, stateFD, stateName) == 0, fsync(stateFD) == 0 else {
                throw Failure.stateWrite
            }
        } catch { throw Failure.stateWrite }
        history = updated; persisted = bytes; offered[candidate.filename] = nil
    }

    private func readFile(_ name: String, expected: Snapshot) throws -> Data {
        let fd = openat(rootFD, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw Failure.unavailable }
        defer { close(fd) }
        // Respect cooperative writers holding an exclusive advisory lock. Stable
        // metadata still cannot prove that an uncooperative writer has closed.
        guard flock(fd, LOCK_SH | LOCK_NB) == 0 else { throw Failure.unavailable }
        var before = stat(), after = stat(), atName = stat()
        guard fstat(fd, &before) == 0, before.st_mode & S_IFMT == S_IFREG, Snapshot(before) == expected else { throw Failure.unavailable }
        var data = Data(), buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = Darwin.read(fd, &buffer, min(buffer.count, Int(expected.size) - data.count + 1))
            if count < 0 && errno == EINTR { continue }
            guard count >= 0 else { throw Failure.unavailable }
            if count == 0 { break }
            guard data.count + count <= Int(expected.size) else { throw Failure.unavailable }
            data.append(contentsOf: buffer.prefix(count))
        }
        guard fstat(fd, &after) == 0, Snapshot(after) == expected, data.count == Int(expected.size),
              fstatat(rootFD, name, &atName, AT_SYMLINK_NOFOLLOW) == 0, Snapshot(atName) == expected else { throw Failure.unavailable }
        return data
    }

    private func acknowledged(name: String, identity: String, hash: String) -> Bool {
        if let acknowledgedHash = history.identities?[identity] { return acknowledgedHash == hash }
        // Old history files have no identities. Preserve their prior filename
        // behavior; new acknowledgments additionally survive rename and restart.
        return history.hashes[name] == hash
    }
    private static func validIdentity(_ value: String) -> Bool {
        value.utf8.count <= 42 && value.range(of: #"^-?[0-9]+:[0-9]+$"#, options: .regularExpression) != nil
    }
    private static func validHash(_ value: String) -> Bool {
        value.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    private static func safeName(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".." && !value.contains("/") && !value.contains("\0") && value.utf8.count <= 255
    }
    private static func directory(_ url: URL, listing: Bool) throws -> Int32 {
        guard url.isFileURL, url.path.hasPrefix("/") else { throw Failure.unsafeLocation }
        let parts = url.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard parts.allSatisfy(safeName) else { throw Failure.unsafeLocation }
        var fd = open("/", O_EXEC | O_DIRECTORY | O_CLOEXEC)
        guard fd >= 0 else { throw Failure.unavailable }
        for (index, part) in parts.enumerated() {
            let flags = listing && index == parts.count - 1 ? O_RDONLY : O_EXEC
            let next = openat(fd, part, flags | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            close(fd)
            guard next >= 0 else { throw Failure.unsafeLocation }
            fd = next
        }
        return fd
    }
    private static func isWithin(_ child: Int32, ancestor: Snapshot) throws -> Bool {
        var fd = dup(child)
        guard fd >= 0 else { throw Failure.unsafeLocation }
        defer { close(fd) }
        for _ in 0..<256 {
            var info = stat(), parentInfo = stat()
            guard fstat(fd, &info) == 0 else { throw Failure.unsafeLocation }
            if info.st_dev == ancestor.device && info.st_ino == ancestor.inode { return true }
            let parent = openat(fd, "..", O_EXEC | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard parent >= 0 else { throw Failure.unsafeLocation }
            guard fstat(parent, &parentInfo) == 0 else { close(parent); throw Failure.unsafeLocation }
            if info.st_dev == parentInfo.st_dev && info.st_ino == parentInfo.st_ino { close(parent); return false }
            close(fd); fd = parent
        }
        throw Failure.unsafeLocation
    }
    private static func readState(_ directory: Int32, _ name: String) throws -> Data? {
        let fd = openat(directory, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        if fd < 0 && errno == ENOENT { return nil }
        guard fd >= 0 else { throw Failure.stateCorrupt }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1,
              info.st_size <= 4 * 1024 * 1024 else { throw Failure.stateCorrupt }
        var data = Data(), buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count < 0 && errno == EINTR { continue }
            guard count >= 0, data.count + max(count, 0) <= 4 * 1024 * 1024 else { throw Failure.stateCorrupt }
            if count == 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}
