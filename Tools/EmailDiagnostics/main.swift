import AppKit
import Darwin
import Foundation
import CryptoKit
import PaperloftKit

/// Predictions never open labels. Only the separate truth adapter does so.
@main struct EmailDiagnostics {
    typealias Candidate = EmailDiagnosticCandidate
    struct Row: Encodable {
        let id: String
        let sourceHash: String
        let sourcePreserved: Bool
        let candidates: [Candidate]
        let renderingEngine: String?
        let renderingFallbackCode: Int?
        let notices: [String]
        let error: String?
    }
    struct Manifest: Encodable {
        let ids: [String]
        let backend: String
        let renderingPolicy: String
        let buildManifest: String
        let fixtureHashes: [String: String]
    }
    static func hash(_ url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url); defer { try? file.close() }
        var digest = SHA256()
        while let bytes = try file.read(upToCount: 262_144), !bytes.isEmpty { digest.update(data: bytes) }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
    @MainActor static func main() async {
        do { try await run() }
        catch {
            FileHandle.standardError.write(Data("Email diagnostics failed: \(error.localizedDescription)\n".utf8))
            exit(2)
        }
    }
    @MainActor static func run() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count >= 3, ["parser", "system"].contains(args[0]), ["automatic", "native"].contains(args[1]) else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixtures = repo.appendingPathComponent("Tests/MailFixtures")
        let outputs = repo.appendingPathComponent("build/email-diagnostics")
        let output = URL(fileURLWithPath: args[2]).standardizedFileURL
        guard output.deletingLastPathComponent().resolvingSymlinksInPath() == outputs.resolvingSymlinksInPath(),
              !FileManager.default.fileExists(atPath: output.path) else { throw CocoaError(.fileWriteFileExists) }
        guard mkdir(output.path, 0o700) == 0 else { throw CocoaError(.fileWriteFileExists) }
        let requested = Set(args.dropFirst(3))
        let files = try FileManager.default.contentsOfDirectory(at: fixtures, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            .filter { $0.pathExtension == "eml" && (requested.isEmpty || requested.contains($0.deletingPathExtension().lastPathComponent)) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !files.isEmpty, requested.isEmpty || Set(files.map { $0.deletingPathExtension().lastPathComponent }) == requested else { throw CocoaError(.fileNoSuchFile) }
        for source in files {
            let attributes = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard attributes.isRegularFile == true, attributes.isSymbolicLink != true else { throw CocoaError(.fileReadUnsupportedScheme) }
        }
        let buildManifestURL = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent("build-manifest.json")
        let buildManifest = try String(contentsOf: buildManifestURL, encoding: .utf8)
        let buildMetadata = try JSONSerialization.jsonObject(with: Data(buildManifest.utf8)) as? [String: Any]
        guard buildMetadata?["binarySHA256"] as? String == (try hash(URL(fileURLWithPath: CommandLine.arguments[0]))) else { throw CocoaError(.fileReadCorruptFile) }
        let fixtureHashes = try Dictionary(uniqueKeysWithValues: files.map { ($0.deletingPathExtension().lastPathComponent, try hash($0)) })
        let manifest = Manifest(ids: files.map { $0.deletingPathExtension().lastPathComponent }, backend: args[0], renderingPolicy: args[1],
            buildManifest: buildManifest, fixtureHashes: fixtureHashes)
        try JSONEncoder().encode(manifest).write(to: output.appendingPathComponent("run-manifest.json"), options: .atomic)
        NSApplication.shared.setActivationPolicy(.prohibited)
        let backend: any ExtractionBackend = args[0] == "system" ? SystemBackend() : ParserBackend()
        let libraryURL = output.appendingPathComponent("library")
        try FileManager.default.createDirectory(at: libraryURL, withIntermediateDirectories: false)
        let library = try LibraryStore(root: libraryURL)
        let index = try ReceiptIndex.open(at: output.appendingPathComponent("index.sqlite"))
        let engine = ReceiptEngine(library: library, index: index, backend: backend)
        let renderer = OfflineEmailBodyRenderer(policy: args[1] == "native" ? .nativeOnly : .automatic)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let predictions = output.appendingPathComponent("raw-predictions.jsonl")
        guard FileManager.default.createFile(atPath: predictions.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
        let handle = try FileHandle(forWritingTo: predictions); defer { try? handle.close() }
        let materializedRoot = output.appendingPathComponent("materialized")
        try FileManager.default.createDirectory(at: materializedRoot, withIntermediateDirectories: false)
        var status = EmailDiagnosticStatus()
        for source in files {
            let id = source.deletingPathExtension().lastPathComponent
            let before = try hash(source)
            var candidates: [Candidate] = []; var notices: [String] = []; var failure: String?
            var rendered: EmailBodyPDF?
            do {
                let materialized = try MailImport.materialize(source: source, destination: materializedRoot)
                var reviews: [URL: ReviewedDocument] = [:]
                var errors: [URL: String] = [:]
                let prepared = try await MailReviewPreparation.prepare(attachments: materialized.attachments, body: materialized.bodyDocument, understand: { url in
                    do {
                        let review = try await engine.understand(url, emailBodyText: url == materialized.bodyDocument ? rendered?.bodyText : nil, emailHints: materialized.envelope)
                        reviews[url] = review; return review
                    } catch { errors[url] = error.localizedDescription; throw error }
                }, prepareBody: { url in
                    let envelope = materialized.envelope
                    let result = try await renderer.render(.init(body: materialized.htmlBody.map { .html($0) } ?? .plainText(materialized.bodyText),
                        envelope: .init(from: envelope?.from ?? "", to: envelope?.to ?? "", date: envelope?.date ?? "", subject: envelope?.subject ?? "")))
                    try result.data.write(to: url, options: .atomic); rendered = result
                })
                let chosen = Set(prepared.candidates.map(\.source))
                let selectedErrors = Dictionary(uniqueKeysWithValues: prepared.candidates.compactMap { candidate in candidate.issue.map { (candidate.source, $0) } })
                for (position, url) in materialized.attachments.enumerated() {
                    candidates.append(Candidate(source: "attachment", attachmentIndex: position, selected: chosen.contains(url), contentHash: try hash(url), fields: reviews[url]?.fields, error: errors[url] ?? selectedErrors[url]))
                }
                if let body = materialized.bodyDocument {
                    candidates.append(Candidate(source: "body", attachmentIndex: nil, selected: chosen.contains(body), contentHash: try hash(body), fields: reviews[body]?.fields, error: errors[body] ?? selectedErrors[body]))
                }
                notices = materialized.notices + prepared.notices
            } catch { failure = error.localizedDescription }
            let row = Row(id: id, sourceHash: before, sourcePreserved: try hash(source) == before, candidates: candidates,
                renderingEngine: rendered?.engine.rawValue, renderingFallbackCode: rendered?.fallbackDiagnosticCode, notices: notices, error: failure)
            status.record(candidates: row.candidates, error: row.error, sourcePreserved: row.sourcePreserved)
            var data = try encoder.encode(row); data.append(10); try handle.write(contentsOf: data); try handle.synchronize()
            FileHandle.standardError.write(Data("Completed \(id)\n".utf8))
        }
        try encoder.encode(status).write(to: output.appendingPathComponent("run-summary.json"), options: .atomic)
        FileHandle.standardError.write(Data("Completed \(status.completedMessages) messages; \(status.processingErrorMessages) processing-error messages, \(status.classificationFailureMessages) messages with \(status.classificationFailureCandidates) classification failures, \(status.sourceChangedMessages) changed originals. This is not an accuracy verdict.\n".utf8))
        if status.exitCode != 0 {
            FileHandle.standardError.write(Data("Partial or failed results are retained in raw records.\n".utf8))
            exit(status.exitCode)
        }
    }
}
