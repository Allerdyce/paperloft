import Foundation
import Darwin

public enum FilingMode: String, Codable, Sendable { case copy, move }
public struct FilingRequest: Sendable {
    public let source: URL
    public let receipt: Receipt
    public let mode: FilingMode
    public let expectedContentHash: String?
    public init(source: URL, receipt: Receipt, mode: FilingMode = .copy, expectedContentHash: String? = nil) {
        self.source = source; self.receipt = receipt; self.mode = mode; self.expectedContentHash = expectedContentHash
    }
}
public enum BatchState: String, Codable, Sendable { case filing, complete, undoing, undone }
public struct FilingBatch: Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let state: BatchState
    public let documents: [FiledDocument]
}

private enum EntryState: String, Codable { case planned, staged, published, complete, undone }
private struct JournalEntry: Codable {
    let id: UUID
    let source: URL
    let sourceIdentity: FileIdentity
    let sourceBackup: URL
    let mode: FilingMode
    let stageName: String
    var document: FiledDocument
    var state: EntryState
}
private struct Journal: Codable {
    let version: Int
    let id: UUID
    let createdAt: Date
    var state: BatchState
    var entries: [JournalEntry]
    var createdDirectories: [String]
    var summary: FilingBatch {
        FilingBatch(id: id, createdAt: createdAt, state: state, documents: entries.map(\.document))
    }
}

/// A durable file-first library. The hidden journal and recovery copies are never
/// treated as filed documents. A process-wide filesystem lock serializes writers.
public actor LibraryStore {
    public nonisolated let root: URL
    private let control: URL
    private let historyDirectory: URL
    private let stagingDirectory: URL
    private let recoveryDirectory: URL

    public init(root: URL) throws {
        let root = root.standardizedFileURL.resolvingSymlinksInPath()
        guard FileManager.default.fileExists(atPath: root.path) else { throw LibraryError.missingLibrary }
        try LibraryFiles.directory(root)
        self.root = root
        control = root.appendingPathComponent(".paperloft", isDirectory: true)
        historyDirectory = control.appendingPathComponent("history", isDirectory: true)
        stagingDirectory = control.appendingPathComponent("staging", isDirectory: true)
        recoveryDirectory = control.appendingPathComponent("recovery", isDirectory: true)
        for directory in [control, historyDirectory, stagingDirectory, recoveryDirectory] { try LibraryFiles.createDirectory(directory) }
    }

    private func lock() throws -> Int32 {
        guard LibraryFiles.exists(root) else { throw LibraryError.missingLibrary }
        try LibraryFiles.directory(root)
        for directory in [control, historyDirectory, stagingDirectory, recoveryDirectory] { try LibraryFiles.directory(directory) }
        let descriptor = open(control.appendingPathComponent("lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw LibraryError.unsafePath }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { close(descriptor); throw LibraryError.busy }
        return descriptor
    }
    private func unlock(_ descriptor: Int32) { _ = flock(descriptor, LOCK_UN); close(descriptor) }
    private func journalURL(_ id: UUID) -> URL { historyDirectory.appendingPathComponent(id.uuidString + ".json") }
    private func save(_ journal: Journal) throws { try LibraryFiles.persist(journal, at: journalURL(journal.id)) }

    private func destination(_ relative: String, allowMissingDirectories: Bool = false) throws -> URL {
        let pieces = relative.split(separator: "/", omittingEmptySubsequences: false)
        guard pieces.count == 3, pieces.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("\0") }) else { throw LibraryError.unsafePath }
        var url = root
        for component in pieces.dropLast() {
            url.appendPathComponent(String(component))
            if LibraryFiles.exists(url) || !allowMissingDirectories { try LibraryFiles.directory(url) }
        }
        return url.appendingPathComponent(String(pieces.last!))
    }

    private func documentsUnlocked() throws -> [FiledDocument] {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]) else { throw LibraryError.missingLibrary }
        var records: [FiledDocument] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            guard values.isRegularFile == true, LibraryFiles.extensions.contains(url.pathExtension.lowercased()),
                  var metadata = try LibraryFiles.metadata(url) else { continue }
            metadata.relativePath = String(url.path.dropFirst(root.path.count + 1))
            records.append(metadata)
        }
        return records.sorted { $0.relativePath < $1.relativePath }
    }

    public func documents() throws -> [FiledDocument] {
        let descriptor = try lock(); defer { unlock(descriptor) }
        return try documentsUnlocked()
    }

    public func history() throws -> [FilingBatch] {
        let descriptor = try lock(); defer { unlock(descriptor) }
        return try journals().sorted { $0.createdAt > $1.createdAt }.map(\.summary)
    }

    private func journals() throws -> [Journal] {
        try FileManager.default.contentsOfDirectory(at: historyDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.map { url in
                _ = try LibraryFiles.identity(url)
                guard let journal = try? JSONDecoder().decode(Journal.self, from: Data(contentsOf: url)),
                      journal.version == 1, url.deletingPathExtension().lastPathComponent == journal.id.uuidString else { throw LibraryError.corruptJournal }
                for entry in journal.entries {
                    guard entry.stageName == entry.id.uuidString + ".stage",
                          entry.sourceBackup == entry.source.deletingLastPathComponent().appendingPathComponent(".paperloft-\(entry.id.uuidString).source") else { throw LibraryError.corruptJournal }
                    guard Int(entry.document.relativePath.split(separator: "/").first ?? "") == entry.document.receipt.date.year else { throw LibraryError.corruptJournal }
                    _ = try destination(entry.document.relativePath, allowMissingDirectories: true)
                }
                for relative in journal.createdDirectories {
                    let parts = relative.split(separator: "/", omittingEmptySubsequences: false)
                    guard (1...2).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("\0") }) else { throw LibraryError.corruptJournal }
                }
                return journal
            }
    }

    public func file(_ requests: [FilingRequest]) throws -> FilingBatch {
        let descriptor = try lock(); defer { unlock(descriptor) }
        try recoverUnlocked()
        let existing = try documentsUnlocked()
        var seenHashes = Set(existing.map(\.contentHash))
        var seenIDs = Set(existing.map(\.id))
        var journal = Journal(version: 1, id: UUID(), createdAt: Date(), state: .filing, entries: [], createdDirectories: [])
        for request in requests {
            guard seenIDs.insert(request.receipt.id).inserted else { throw LibraryError.conflict("receipt identifier") }
            guard LibraryFiles.extensions.contains(request.source.pathExtension.lowercased()) else { throw LibraryError.unsupportedFile }
            let source = request.source.standardizedFileURL
            guard !source.path.hasPrefix(control.path + "/") else { throw LibraryError.unsafePath }
            let identity = try LibraryFiles.identity(source), hash = try LibraryFiles.hash(source)
            if let expected = request.expectedContentHash, expected != hash { throw LibraryError.sourceChanged(source.path) }
            guard !seenHashes.contains(hash) else { throw LibraryError.duplicate(existing.first(where: { $0.contentHash == hash })?.relativePath ?? "this batch") }
            seenHashes.insert(hash)
            let relative = "\(request.receipt.date.year)/\(LibraryFiles.safeFolder(request.receipt.category))/\(try ReceiptFilename.name(for: request.receipt, fileExtension: source.pathExtension))"
            let operation = UUID()
            journal.entries.append(JournalEntry(id: operation, source: source, sourceIdentity: identity,
                sourceBackup: source.deletingLastPathComponent().appendingPathComponent(".paperloft-\(operation.uuidString).source"),
                mode: request.mode, stageName: operation.uuidString + ".stage",
                document: FiledDocument(receipt: request.receipt, contentHash: hash, relativePath: relative, filedAt: Date()), state: .planned))
        }
        guard !LibraryFiles.exists(journalURL(journal.id)) else { throw LibraryError.conflict("filing history") }
        try save(journal)
        try finish(&journal)
        return journal.summary
    }

    private func ensureDirectories(_ journal: inout Journal, for relative: String) throws {
        let parts = relative.split(separator: "/")
        guard parts.count == 3 else { throw LibraryError.unsafePath }
        var directory = root; var relativeDirectory = ""
        for component in parts.dropLast() {
            guard component != ".", component != ".." else { throw LibraryError.unsafePath }
            directory.appendPathComponent(String(component))
            relativeDirectory += (relativeDirectory.isEmpty ? "" : "/") + component
            if !LibraryFiles.exists(directory) {
                if !journal.createdDirectories.contains(relativeDirectory) { journal.createdDirectories.append(relativeDirectory); try save(journal) }
                try LibraryFiles.createDirectory(directory)
            } else { try LibraryFiles.directory(directory) }
        }
    }

    private func isPublished(_ entry: JournalEntry, at url: URL) throws -> Bool {
        guard LibraryFiles.exists(url), let metadata = try LibraryFiles.metadata(url), metadata.id == entry.document.id else { return false }
        guard try LibraryFiles.hash(url) == entry.document.contentHash else { throw LibraryError.conflict(url.path) }
        return true
    }

    private func finish(_ journal: inout Journal) throws {
        for index in journal.entries.indices {
            if journal.entries[index].state == .complete { continue }
            try ensureDirectories(&journal, for: journal.entries[index].document.relativePath)
            var entry = journal.entries[index]
            let stage = stagingDirectory.appendingPathComponent(entry.stageName)
            var target = try destination(entry.document.relativePath)
            if entry.state == .planned {
                guard try LibraryFiles.identity(entry.source) == entry.sourceIdentity,
                      try LibraryFiles.hash(entry.source) == entry.document.contentHash else { throw LibraryError.sourceChanged(entry.source.path) }
                if LibraryFiles.exists(stage) {
                    // A killed copy may leave a partial file. Preserve it rather than
                    // deleting any bytes, then retry from the verified original.
                    try LibraryFiles.renameExclusive(stage, recoveryDirectory.appendingPathComponent(UUID().uuidString + ".partial"))
                }
                try FileManager.default.copyItem(at: entry.source, to: stage)
                guard try LibraryFiles.hash(stage) == entry.document.contentHash else { throw LibraryError.sourceChanged(entry.source.path) }
                try LibraryFiles.setMetadata(entry.document, at: stage)
                try LibraryFiles.synchronize(stage)
                entry.state = .staged; journal.entries[index] = entry; try save(journal)
            }
            if entry.state == .staged {
                if try isPublished(entry, at: target) {
                    guard !LibraryFiles.exists(stage) else { throw LibraryError.conflict(target.path) }
                } else {
                    guard LibraryFiles.exists(stage), try LibraryFiles.hash(stage) == entry.document.contentHash else { throw LibraryError.conflict(stage.path) }
                    let base = target.deletingPathExtension().lastPathComponent, ext = target.pathExtension
                    var suffix = 1
                    while true {
                        if LibraryFiles.exists(target) {
                            suffix += 1
                            guard suffix <= 10000 else { throw LibraryError.conflict(target.path) }
                            target = target.deletingLastPathComponent().appendingPathComponent("\(base) (\(suffix)).\(ext)")
                            entry.document.relativePath = String(target.path.dropFirst(root.path.count + 1))
                            try LibraryFiles.setMetadata(entry.document, at: stage)
                            journal.entries[index] = entry; try save(journal)
                            continue
                        }
                        do { try LibraryFiles.renameExclusive(stage, target); break }
                        catch LibraryError.conflict { continue }
                    }
                }
                entry.state = .published; journal.entries[index] = entry; try save(journal)
            }
            if entry.mode == .move {
                guard try isPublished(entry, at: target) else { throw LibraryError.conflict(target.path) }
                if !LibraryFiles.exists(entry.sourceBackup) {
                    guard try LibraryFiles.identity(entry.source) == entry.sourceIdentity,
                          try LibraryFiles.hash(entry.source) == entry.document.contentHash else { throw LibraryError.sourceChanged(entry.source.path) }
                    try LibraryFiles.renameExclusive(entry.source, entry.sourceBackup)
                }
                guard try LibraryFiles.identity(entry.sourceBackup) == entry.sourceIdentity,
                      try LibraryFiles.hash(entry.sourceBackup) == entry.document.contentHash else {
                    if !LibraryFiles.exists(entry.source) { try LibraryFiles.renameExclusive(entry.sourceBackup, entry.source) }
                    throw LibraryError.sourceChanged(entry.source.path)
                }
            }
            entry.state = .complete; journal.entries[index] = entry; try save(journal)
        }
        journal.state = .complete; try save(journal)
    }

    public func recover() throws {
        let descriptor = try lock(); defer { unlock(descriptor) }
        try recoverUnlocked()
    }
    private func recoverUnlocked() throws {
        for var journal in try journals().sorted(by: { $0.createdAt < $1.createdAt }) {
            if journal.state == .filing { try finish(&journal) }
            else if journal.state == .undoing { try finishUndo(&journal) }
        }
    }

    public func undo(batch id: UUID) throws {
        let descriptor = try lock(); defer { unlock(descriptor) }
        guard var journal = try journals().first(where: { $0.id == id }) else { throw LibraryError.corruptJournal }
        if journal.state == .undone { return }
        journal.state = .undoing; try save(journal)
        try finishUndo(&journal)
    }

    private func finishUndo(_ journal: inout Journal) throws {
        for index in journal.entries.indices.reversed() {
            var entry = journal.entries[index]
            if entry.state == .undone { continue }
            if entry.mode == .move, LibraryFiles.exists(entry.sourceBackup) {
                guard !LibraryFiles.exists(entry.source),
                      try LibraryFiles.identity(entry.sourceBackup) == entry.sourceIdentity,
                      try LibraryFiles.hash(entry.sourceBackup) == entry.document.contentHash else { throw LibraryError.conflict(entry.source.path) }
                try LibraryFiles.renameExclusive(entry.sourceBackup, entry.source)
            } else if entry.mode == .move {
                guard try LibraryFiles.identity(entry.source) == entry.sourceIdentity,
                      try LibraryFiles.hash(entry.source) == entry.document.contentHash else { throw LibraryError.conflict(entry.source.path) }
            }
            let target = try destination(entry.document.relativePath, allowMissingDirectories: true)
            let recovered = recoveryDirectory.appendingPathComponent(entry.id.uuidString + ".undone")
            if LibraryFiles.exists(target) {
                if try isPublished(entry, at: target) { try LibraryFiles.renameExclusive(target, recovered) }
                else if entry.state == .published || entry.state == .complete { throw LibraryError.conflict(target.path) }
            } else if entry.state == .published || entry.state == .complete {
                guard try isPublished(entry, at: recovered) else { throw LibraryError.conflict(target.path) }
            }
            let stage = stagingDirectory.appendingPathComponent(entry.stageName)
            if LibraryFiles.exists(stage) {
                try LibraryFiles.renameExclusive(stage, recoveryDirectory.appendingPathComponent(entry.id.uuidString + ".unfiled"))
            }
            entry.state = .undone; journal.entries[index] = entry; try save(journal)
        }
        for relative in journal.createdDirectories.reversed() {
            let directory = root.appendingPathComponent(relative)
            if LibraryFiles.exists(directory) {
                try LibraryFiles.directory(directory)
                if try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty { _ = rmdir(directory.path) }
            }
        }
        journal.state = .undone; try save(journal)
    }
}
