import Foundation

public enum HandoffError: Error, Equatable {
    case tooManyFiles, unsupportedType, unsafePath, invalidItem, fileTooLarge, sourceChanged
}

public enum HandoffFileType: String, Codable, Sendable {
    case pdf = "com.adobe.pdf", jpeg = "public.jpeg", png = "public.png"
    case heic = "public.heic", tiff = "public.tiff"
    case email = "public.email-message", appleEmail = "com.apple.mail.email"

    public var fileExtension: String {
        switch self {
        case .pdf: "pdf"
        case .jpeg: "jpg"
        case .png: "png"
        case .heic: "heic"
        case .tiff: "tiff"
        case .email, .appleEmail: "eml"
        }
    }

    public func accepts(filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch self {
        case .jpeg: return ["jpg", "jpeg"].contains(ext)
        case .tiff: return ["tif", "tiff"].contains(ext)
        default: return ext == fileExtension
        }
    }
}

public struct HandoffInput: Sendable {
    public let id: UUID
    public let fileURL: URL
    public let type: HandoffFileType
    public let sourceApp: String?
    public init(id: UUID = UUID(), fileURL: URL, type: HandoffFileType, sourceApp: String? = nil) {
        self.id = id; self.fileURL = fileURL; self.type = type; self.sourceApp = sourceApp
    }
}

public struct HandoffItem: Codable, Equatable, Sendable {
    public let id: UUID
    public let originalName: String
    public let type: HandoffFileType
    public let createdAt: Date
    public let sourceApp: String?
    public let byteCount: Int64
    public var payloadName: String { "document." + type.fileExtension }
}

public struct HandoffClaim: Sendable {
    public let item: HandoffItem
    public let fileURL: URL
    fileprivate init(item: HandoffItem, fileURL: URL) { self.item = item; self.fileURL = fileURL }
}

/// One main-app consumer must own this actor. Writers may live in other processes.
/// Claims survive process exit. Call outstandingClaims() on launch and retry ingestion
/// using item.id as the destination store's durable idempotency key before acknowledge().
public actor HandoffStore {
    public static let maximumFiles = 20
    public static let maximumFileBytes: Int64 = 200_000_000
    private let inbox: URL
    private let fm = FileManager.default

    public init(containerURL: URL) throws {
        guard containerURL.isFileURL else { throw HandoffError.unsafePath }
        inbox = containerURL.appendingPathComponent("Inbox", isDirectory: true)
        try Self.rejectSymlinks(inbox)
        for url in [inbox, inbox.appendingPathComponent(".incoming"),
                    inbox.appendingPathComponent(".claimed"), inbox.appendingPathComponent(".receipts")] {
            try Self.rejectSymlinks(url)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// Each file is an atomic item, not an atomic batch. On any error, retry the same
    /// inputs with the same UUIDs; already published/claimed/acknowledged IDs are no-ops.
    /// Type is the provider's declared type; actual decoding belongs to main-app intake.
    public func publish(_ inputs: [HandoffInput], now: Date = Date()) throws -> [UUID] {
        guard inputs.count <= Self.maximumFiles else { throw HandoffError.tooManyFiles }
        guard Set(inputs.map(\.id)).count == inputs.count else { throw HandoffError.invalidItem }
        for input in inputs {
            try validateName(input.fileURL.lastPathComponent)
            guard (input.sourceApp?.utf8.count ?? 0) <= 1_024 else { throw HandoffError.invalidItem }
            guard input.type.accepts(filename: input.fileURL.lastPathComponent) else { throw HandoffError.unsupportedType }
        }
        for input in inputs {
            if try isKnown(input.id) { continue }
            try publishOne(input, now: now)
        }
        return inputs.map(\.id)
    }

    /// Returns nil immediately when another process/actor owns the consumer lease.
    /// Hold the returned token through recovery, ingestion and acknowledgement.
    public func acquireConsumerLease() throws -> HandoffConsumerLease? {
        try safeDirectory(inbox)
        return try HandoffConsumerLease.acquire(at: inbox.appendingPathComponent(".consumer.lock"))
    }

    /// Only fully published directories are discoverable. Partial stages stay hidden.
    public func availableItems() throws -> [HandoffItem] {
        try safeDirectory(inbox)
        return try fm.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)
            .filter { UUID(uuidString: $0.lastPathComponent) != nil }
            .map { try readItem($0) }.sorted { $0.createdAt < $1.createdAt }
    }

    public func claim(_ id: UUID) throws -> HandoffClaim? {
        if try hasReceipt(id) { try removeOwned(location(".claimed", id)); try removeOwned(location(nil, id)); return nil }
        let source = location(nil, id), destination = location(".claimed", id)
        try safeDirectory(destination.deletingLastPathComponent())
        guard fm.fileExists(atPath: source.path) else { return nil }
        let item = try readItem(source)
        try fm.moveItem(at: source, to: destination)
        return HandoffClaim(item: item, fileURL: destination.appendingPathComponent(item.payloadName))
    }

    /// Resume only after the previous consumer has stopped; this is not a timed lease.
    public func outstandingClaims() throws -> [HandoffClaim] {
        let directory = inbox.appendingPathComponent(".claimed")
        try safeDirectory(directory)
        var claims: [HandoffClaim] = []
        for url in try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            guard let id = UUID(uuidString: url.lastPathComponent) else { continue }
            if try hasReceipt(id) { try removeOwned(url); continue }
            let item = try readItem(url)
            claims.append(HandoffClaim(item: item, fileURL: url.appendingPathComponent(item.payloadName)))
        }
        return claims
    }

    /// Call only after intake commits durably. Receipt precedes deletion, so a crash
    /// between these operations is repaired by outstandingClaims()/claim().
    public func acknowledge(_ claim: HandoffClaim) throws {
        let id = claim.item.id
        if try hasReceipt(id) { try removeOwned(location(".claimed", id)); return }
        let directory = location(".claimed", id)
        guard try readItem(directory) == claim.item else { throw HandoffError.invalidItem }
        let receipt = location(".receipts", id)
        try safeDirectory(receipt.deletingLastPathComponent())
        try JSONEncoder().encode(claim.item).write(to: receipt, options: .atomic)
        try removeOwned(directory)
    }

    /// Removes only our stages, never published items, claims, receipts or originals.
    /// The owner should run cleanup before starting writes; active writes must not
    /// overlap this maintenance call across processes.
    @discardableResult public func cleanupStaleIncoming(now: Date = Date()) throws -> Int {
        let directory = inbox.appendingPathComponent(".incoming")
        try safeDirectory(directory)
        var removed = 0
        for url in try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            guard UUID(uuidString: url.lastPathComponent) != nil else { continue }
            try safeDirectory(url)
            let attrs = try fm.attributesOfItem(atPath: url.path)
            guard let modified = attrs[.modificationDate] as? Date,
                  now.timeIntervalSince(modified) > 24 * 60 * 60 else { continue }
            try removeOwned(url); removed += 1
        }
        return removed
    }

    private func publishOne(_ input: HandoffInput, now: Date) throws {
        let staging = location(".incoming", UUID())
        try safeDirectory(staging.deletingLastPathComponent())
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? removeOwned(staging) }
        let payload = staging.appendingPathComponent("document." + input.type.fileExtension)
        let count = try HandoffFileCopy.copy(source: input.fileURL, destination: payload)
        let item = HandoffItem(id: input.id, originalName: input.fileURL.lastPathComponent,
                               type: input.type, createdAt: now, sourceApp: input.sourceApp, byteCount: count)
        let metadata = staging.appendingPathComponent("item.json")
        try JSONEncoder().encode(item).write(to: metadata)
        let metadataHandle = try FileHandle(forWritingTo: metadata)
        try metadataHandle.synchronize(); try metadataHandle.close()
        try safeDirectory(inbox)
        // Same-volume rename is the publication boundary. Never overwrite a destination.
        do { try fm.moveItem(at: staging, to: location(nil, input.id)) }
        catch { if try !isKnown(input.id) { throw error } }
    }

    private func readItem(_ directory: URL) throws -> HandoffItem {
        try safeDirectory(directory)
        let metadata = directory.appendingPathComponent("item.json")
        try Self.rejectSymlinks(metadata)
        let attrs = try fm.attributesOfItem(atPath: metadata.path)
        guard attrs[.type] as? FileAttributeType == .typeRegular,
              (attrs[.size] as? NSNumber)?.intValue ?? Int.max <= 64 * 1_024 else { throw HandoffError.invalidItem }
        let item = try JSONDecoder().decode(HandoffItem.self, from: Data(contentsOf: metadata))
        guard item.id.uuidString == directory.lastPathComponent,
              item.byteCount >= 0, item.byteCount <= Self.maximumFileBytes,
              item.type.accepts(filename: item.originalName) else { throw HandoffError.invalidItem }
        try validateName(item.originalName)
        let payload = directory.appendingPathComponent(item.payloadName)
        try Self.rejectSymlinks(payload)
        let payloadAttrs = try fm.attributesOfItem(atPath: payload.path)
        guard payloadAttrs[.type] as? FileAttributeType == .typeRegular,
              (payloadAttrs[.size] as? NSNumber)?.int64Value == item.byteCount else { throw HandoffError.invalidItem }
        return item
    }

    private func location(_ group: String?, _ id: UUID) -> URL {
        (group.map { inbox.appendingPathComponent($0) } ?? inbox).appendingPathComponent(id.uuidString)
    }
    private func isKnown(_ id: UUID) throws -> Bool {
        if try hasReceipt(id) { return true }
        for url in [location(nil, id), location(".claimed", id)] where fm.fileExists(atPath: url.path) {
            _ = try readItem(url); return true
        }
        return false
    }
    private func hasReceipt(_ id: UUID) throws -> Bool {
        let url = location(".receipts", id)
        try Self.rejectSymlinks(url)
        guard fm.fileExists(atPath: url.path) else { return false }
        let attrs = try fm.attributesOfItem(atPath: url.path)
        guard attrs[.type] as? FileAttributeType == .typeRegular,
              (attrs[.size] as? NSNumber)?.intValue ?? Int.max <= 64 * 1_024 else { throw HandoffError.invalidItem }
        let receipt = try JSONDecoder().decode(HandoffItem.self, from: Data(contentsOf: url))
        guard receipt.id == id else { throw HandoffError.invalidItem }
        return true
    }
    private func validateName(_ name: String) throws {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"),
              !name.contains("\\"), !name.contains("\0"), name.utf8.count <= 1_024 else { throw HandoffError.unsafePath }
    }
    private func safeDirectory(_ url: URL) throws {
        try Self.rejectSymlinks(url)
        guard try fm.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType == .typeDirectory else { throw HandoffError.unsafePath }
    }
    private func removeOwned(_ url: URL) throws {
        try Self.rejectSymlinks(url)
        if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
    }
    private static func rejectSymlinks(_ url: URL) throws {
        guard url.isFileURL, !url.pathComponents.contains("..") else { throw HandoffError.unsafePath }
        var cursor = url
        while cursor.path != "/" {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: cursor.path),
               attrs[.type] as? FileAttributeType == .typeSymbolicLink { throw HandoffError.unsafePath }
            cursor.deleteLastPathComponent()
        }
    }
}
