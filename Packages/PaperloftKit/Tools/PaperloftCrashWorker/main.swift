import Foundation
import PaperloftKit

/// Separate integration-test process; no test-only branch is compiled into the app.
@main struct CrashWorker {
    struct Input: Decodable {
        let root: URL
        let requests: [Request]
        struct Request: Decodable { let source: URL; let receipt: Receipt; let mode: FilingMode }
    }
    static func main() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 2 else { throw NSError(domain: "CrashWorkerUsage", code: 1) }
        let input = try JSONDecoder().decode(Input.self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
        let library = try LibraryStore(root: input.root)
        switch args[0] {
        case "file":
            _ = try await library.file(input.requests.map { FilingRequest(source: $0.source, receipt: $0.receipt, mode: $0.mode) })
        case "recover": try await library.recover()
        case "undo":
            for batch in try await library.history() where batch.state != .undone { try await library.undo(batch: batch.id) }
        default: throw NSError(domain: "CrashWorkerUsage", code: 2)
        }
        let records = try await library.documents()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(records))
    }
}
