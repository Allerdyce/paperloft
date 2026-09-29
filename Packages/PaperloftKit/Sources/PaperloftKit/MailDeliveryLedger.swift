import Foundation
import CryptoKit
import Darwin

/// Committed email deliveries, independent of document content hashes.
/// Persist a Proof with the inbox replacement first, then commit it here. On launch,
/// replay proofs from the durable inbox to close the crash window between the two writes.
/// Never commit an attempt whose selected candidates failed or whose inbox save failed.
public actor MailDeliveryLedger {
    public struct Proof: Codable, Sendable, Equatable {
        public let messageKey: String
        public let deliveryID: UUID
    }
    public enum Failure: Error, Sendable { case unsafePath, corrupt, full, io }
    private struct State: Codable { let version: Int; var deliveries: [String: UUID] }
    public static let maximumEntries = 25_000
    private static let maximumBytes = 4 * 1024 * 1024
    private let directory: URL

    /// The app supplies its own private support directory. No mail addresses or raw IDs are stored.
    public init(directory: URL) throws {
        try LibraryFiles.directory(directory)
        self.directory = directory
    }

    /// Preserve case and spelling within the RFC Message-ID. Invalid/missing IDs use the
    /// separate content-hash duplicate check; they must never share an empty dedup key.
    public nonisolated static func proof(messageID: String?, deliveryID: UUID = UUID()) -> Proof? {
        guard let messageID else { return nil }
        let value = messageID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.utf8.count <= 998, value.first == "<", value.last == ">" else { return nil }
        let inner = value.dropFirst().dropLast()
        let address = inner.split(separator: "@", omittingEmptySubsequences: false)
        guard address.count == 2, address.allSatisfy({ !$0.isEmpty }),
              inner.unicodeScalars.allSatisfy({ $0.value > 32 && $0.value < 127 && $0 != "<" && $0 != ">" }) else { return nil }
        let key = SHA256.hash(data: Data(inner.utf8)).map { String(format: "%02x", $0) }.joined()
        return Proof(messageKey: key, deliveryID: deliveryID)
    }

    public func committedDelivery(messageID: String?) throws -> UUID? {
        try committedDeliverySynchronously(messageID: messageID)
    }

    public nonisolated func committedDeliverySynchronously(messageID: String?) throws -> UUID? {
        guard let proof = Self.proof(messageID: messageID) else { return nil }
        return try locked { try read().deliveries[proof.messageKey] }
    }

    /// Idempotent: an existing successful delivery wins. Caller must have durably saved
    /// the inbox proof before calling; this API intentionally has no begin/attempt marker.
    @discardableResult public func commit(_ proof: Proof) throws -> UUID {
        try commitSynchronously(proof)
    }

    /// Short synchronous adapter for a main-actor inbox transaction: no suspension between
    /// publishing its durable snapshot and recording its proof. The file lock still applies.
    @discardableResult public nonisolated func commitSynchronously(_ proof: Proof) throws -> UUID {
        guard proof.messageKey.count == 64, proof.messageKey.allSatisfy({ "0123456789abcdef".contains($0) }) else { throw Failure.corrupt }
        return try locked {
            var state = try read()
            if let existing = state.deliveries[proof.messageKey] { return existing }
            guard state.deliveries.count < Self.maximumEntries else { throw Failure.full }
            state.deliveries[proof.messageKey] = proof.deliveryID
            let data = try JSONEncoder().encode(state)
            guard data.count <= Self.maximumBytes else { throw Failure.full }
            try write(data)
            return proof.deliveryID
        }
    }

    public nonisolated func validateSynchronously() throws { _ = try locked { try read() } }

    private nonisolated func locked<T>(_ body: () throws -> T) throws -> T {
        try LibraryFiles.directory(directory)
        let descriptor = open(directory.appendingPathComponent("mail-deliveries.lock").path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw Failure.unsafePath }
        defer { close(descriptor) }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { throw Failure.unsafePath }
        guard flock(descriptor, LOCK_EX) == 0 else { throw Failure.io }
        defer { flock(descriptor, LOCK_UN) }
        return try body()
    }

    private nonisolated func read() throws -> State {
        let url = directory.appendingPathComponent("mail-deliveries.json")
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        if descriptor < 0 {
            if errno == ENOENT { return State(version: 1, deliveries: [:]) }
            throw Failure.unsafePath
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { throw Failure.unsafePath }
        guard info.st_size >= 0, info.st_size <= Self.maximumBytes,
              let data = try handle.read(upToCount: Self.maximumBytes + 1), data.count <= Self.maximumBytes else { throw Failure.corrupt }
        let state: State
        do { state = try JSONDecoder().decode(State.self, from: data) } catch { throw Failure.corrupt }
        guard state.version == 1, state.deliveries.count <= Self.maximumEntries,
              state.deliveries.keys.allSatisfy({ $0.count == 64 && $0.allSatisfy({ "0123456789abcdef".contains($0) }) }) else { throw Failure.corrupt }
        return state
    }

    private nonisolated func write(_ data: Data) throws {
        let target = directory.appendingPathComponent("mail-deliveries.json")
        if LibraryFiles.exists(target) { _ = try LibraryFiles.identity(target) }
        let temporary = directory.appendingPathComponent("mail-deliveries-" + UUID().uuidString + ".tmp")
        let descriptor = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw Failure.io }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close(); try? FileManager.default.removeItem(at: temporary) }
        try handle.write(contentsOf: data)
        guard fsync(descriptor) == 0 else { throw Failure.io }
        guard rename(temporary.path, target.path) == 0 else { throw Failure.io }
        let folder = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard folder >= 0 else { throw Failure.io }
        defer { close(folder) }
        guard fsync(folder) == 0 else { throw Failure.io }
    }
}
