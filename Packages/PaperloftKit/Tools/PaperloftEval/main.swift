import Foundation
import PaperloftKit

@main
struct Evaluate {
    struct Prediction: Encodable {
        let id: String
        let kind: String
        let vendor: String?
        let date: String?
        let total: String?
        let category: String?
        let backend: String
    }
    static func main() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 3, ["stub", "parser", "system"].contains(args[0]) else {
            throw NSError(domain: "PaperloftEval", code: 2, userInfo: [NSLocalizedDescriptionKey: "Usage: PaperloftEval stub|parser|system input-directory predictions.jsonl"])
        }
        let backend: any ExtractionBackend
        switch args[0] {
        case "stub": backend = StubBackend()
        case "system": backend = SystemBackend()
        default: backend = ParserBackend()
        }
        let input = URL(fileURLWithPath: args[1], isDirectory: true)
        let output = URL(fileURLWithPath: args[2])
        let extensions: Set<String> = ["pdf", "png", "jpg", "jpeg", "heic"]
        let files = try FileManager.default.contentsOfDirectory(at: input, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]).filter {
            extensions.contains($0.pathExtension.lowercased()) && ((try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true)
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !files.isEmpty else { throw NSError(domain: "PaperloftEval", code: 3, userInfo: [NSLocalizedDescriptionKey: "No supported documents found"] ) }
        let ids = files.map { $0.deletingPathExtension().lastPathComponent }
        guard Set(ids).count == ids.count else { throw NSError(domain: "PaperloftEval", code: 4, userInfo: [NSLocalizedDescriptionKey: "Duplicate document identifiers"] ) }
        let recognizer = DocumentRecognizer()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard FileManager.default.createFile(atPath: output.path, contents: nil) else { throw NSError(domain: "PaperloftEval", code: 5) }
        let outputHandle = try FileHandle(forWritingTo: output)
        defer { try? outputHandle.close() }
        var failures = 0
        var failureTypes: [String: Int] = [:]
        var backends: [String: Int] = [:]
        for (index, file) in files.enumerated() {
            do {
                let text = try recognizer.text(at: file)
                let fields = try await backend.extract(text: text)
                let prediction = Prediction(id: file.deletingPathExtension().lastPathComponent, kind: fields.kind, vendor: fields.vendor, date: fields.date, total: fields.total, category: fields.category, backend: fields.backend)
                var row = try encoder.encode(prediction); row.append(10)
                try outputHandle.write(contentsOf: row)
                backends[fields.backend, default: 0] += 1
            } catch {
                // Missing predictions are scored as failures. Never fabricate a result.
                failures += 1
                let category = String(reflecting: type(of: error)) + "." + (Mirror(reflecting: error).children.first?.label ?? "unknown")
                failureTypes[category, default: 0] += 1
            }
            if (index + 1) % 10 == 0 || index == 0 {
                FileHandle.standardError.write(Data("Progress: \(index + 1)/\(files.count) documents\n".utf8))
            }
        }
        let summary = "Processed \(files.count) documents; failures \(failures); backends \(backends); failure types \(failureTypes)\n"
        FileHandle.standardError.write(Data(summary.utf8))
    }
}
