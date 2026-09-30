import Foundation
import PaperloftKit

/// Throughput diagnostic: for each fixture, times OCR and the system extraction, alternating
/// sequential and concurrent document-type classification by document index so both modes see
/// comparable documents. Each document runs once. Usage: PipelineTiming <fixtures-dir> <out.jsonl> [count]
struct Row: Encodable { let id: String; let mode: String; let ocr: Double; let model: Double; let classifierAlone: Double?; let chars: Int; let kind: String?; let classificationError: String?; let error: String? }

@main struct PipelineTiming {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count >= 3 else { print("usage: PipelineTiming fixtures out.jsonl [count]"); exit(64) }
        let dir = URL(fileURLWithPath: args[1])
        let count = args.count > 3 ? Int(args[3]) ?? 40 : 40
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { ["jpg", "png", "pdf", "jpeg", "heic"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }.prefix(count)
        FileManager.default.createFile(atPath: args[2], contents: nil)
        let out = try FileHandle(forWritingTo: URL(fileURLWithPath: args[2]))
        let recognizer = DocumentRecognizer(), backend = SystemBackend()
        let clock = ContinuousClock()
        func seconds(_ d: Duration) -> Double { Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18 }
        var totals: [String: (Double, Int)] = [:]
        let wall = clock.now
        for (index, file) in files.enumerated() {
            // Alternate by pairs so photo and scanned fixtures (which alternate by index) reach both modes.
            let concurrent = (index / 2) % 2 == 1
            var text = "", ocr = 0.0, model = 0.0, classifierAlone: Double?, fields: ExtractedFields?, failure: String?
            let t0 = clock.now
            do { text = try recognizer.text(at: file) } catch { failure = "ocr: \(error)" }
            ocr = seconds(clock.now - t0)
            if failure == nil {
                let t1 = clock.now
                do { fields = try await backend.extract(text: text, concurrentClassification: concurrent) } catch { failure = "model: \(error)" }
                model = seconds(clock.now - t1)
                if !concurrent && failure == nil && fields?.classificationError == nil {
                    // Timing only: the classifier alone on the same text (skipped if it refused above).
                    let t2 = clock.now
                    _ = try? await SystemBackend.classifyDocumentType("Document text:\n" + String(text.prefix(12000)))
                    classifierAlone = seconds(clock.now - t2)
                }
            }
            let mode = concurrent ? "concurrent" : "sequential"
            let row = Row(id: file.deletingPathExtension().lastPathComponent, mode: mode, ocr: ocr, model: model, classifierAlone: classifierAlone, chars: text.count,
                          kind: fields?.kind, classificationError: fields?.classificationError, error: failure)
            out.write(try JSONEncoder().encode(row)); out.write(Data("\n".utf8))
            let t = totals[mode] ?? (0, 0); totals[mode] = (t.0 + model, t.1 + 1)
            print(String(format: "%@ %@ ocr=%.2fs model=%.2fs", row.id, mode, ocr, model))
        }
        try out.close()
        for (mode, t) in totals.sorted(by: { $0.key < $1.key }) { print(String(format: "%@: mean model %.2fs over %d", mode, t.0 / Double(t.1), t.1)) }
        print(String(format: "wall %.1fs", seconds(clock.now - wall)))
    }
}
