import Foundation
import Darwin
import PaperloftHandoff

/// Synthetic payload benchmark for the handoff writer only; no receipt reading.
@main struct HandoffPerformance {
    static func main() async throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Pass a disposable output directory") }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let workspace = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: workspace) }
        let payload = Data(repeating: 0x5A, count: 250_000)
        var inputs: [HandoffInput] = []
        for index in 0..<20 {
            let file = workspace.appendingPathComponent("synthetic-\(index).pdf")
            guard FileManager.default.createFile(atPath: file.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
            let handle = try FileHandle(forWritingTo: file)
            for _ in 0..<20 { try handle.write(contentsOf: payload) }
            try handle.synchronize(); try handle.close()
            inputs.append(HandoffInput(fileURL: file, type: .pdf))
        }
        let store = try HandoffStore(containerURL: workspace.appendingPathComponent("Group"))
        let start = ContinuousClock.now
        _ = try await store.publish(inputs)
        let duration = start.duration(to: .now).components
        let seconds = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { throw CocoaError(.fileReadUnknown) }
        let peak = usage.ru_maxrss // Darwin reports bytes, including setup and runtime.
        let items = try await store.availableItems()
        guard items.count == 20, items.reduce(0, { $0 + $1.byteCount }) == 100_000_000 else { fatalError("Incomplete handoff") }
        for input in inputs {
            guard let claim = try await store.claim(input.id) else { fatalError("Missing handoff") }
            let source = try FileHandle(forReadingFrom: input.fileURL)
            let copy = try FileHandle(forReadingFrom: claim.fileURL)
            defer { try? source.close(); try? copy.close() }
            while let bytes = try source.read(upToCount: 250_000), !bytes.isEmpty {
                guard bytes == payload, bytes == (try copy.read(upToCount: 250_000)) else { fatalError("Payload changed") }
            }
            guard try copy.read(upToCount: 1)?.isEmpty != false else { fatalError("Payload grew") }
        }
        let result: [String: Any] = ["files":20, "bytes":100_000_000, "writerSeconds":seconds, "processPeakBytes":peak,
            "originalsAndCopiesMatch":true, "timingPass":seconds < 10, "memoryPass":peak < 60_000_000]
        print(String(decoding: try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
        if seconds >= 10 || peak >= 60_000_000 { exit(1) }
    }
}
