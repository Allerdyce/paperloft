import Foundation
import PaperloftKit

/// AC-10 diagnostic: does understanding two documents at once raise throughput with the system model?
/// Every document is new, single-use synthetic text (never a fixture and never resubmitted), and the
/// arms alternate in blocks so heat and background load affect both.
/// Usage: ConcurrencyProbe <out.jsonl> [blocks per arm] [documents per block]
struct Row: Encodable { let block: Int; let width: Int; let documents: Int; let wall: Double; let perDocument: Double; let failures: Int }

@main struct ConcurrencyProbe {
    static let vendors = ["Alder", "Birch", "Cedar", "Dune", "Ember", "Fjord", "Grove", "Harbor", "Iris", "Juniper", "Kestrel", "Linden", "Meadow", "Nimbus", "Orchard", "Pike"]
    static let trades = ["Stationers", "Cafe", "Hardware", "Print Shop", "Bakery", "Books", "Garage", "Florist", "Deli", "Supply Co"]
    static let items = ["Notebook", "Coffee", "Printer paper", "Sandwich", "Cable", "Stamps", "Folders", "Tea", "Batteries", "Pens"]

    /// A unique receipt or invoice, 250–700 characters, like the fixture mix.
    static func document(_ n: Int, _ rng: inout SystemRandomNumberGenerator) -> String {
        let vendor = "\(vendors.randomElement(using: &rng)!) \(trades.randomElement(using: &rng)!) \(Int.random(in: 100...999, using: &rng))"
        let invoice = n % 3 == 2
        let day = Int.random(in: 1...28, using: &rng), month = Int.random(in: 1...12, using: &rng)
        var lines = [vendor, "\(Int.random(in: 10...999, using: &rng)) Probe Street, Testville", invoice ? "INVOICE #\(Int.random(in: 1000...99999, using: &rng))" : "RECEIPT",
                     String(format: "Date: 2026-%02d-%02d", month, day)]
        var subtotal = 0
        for _ in 0..<Int.random(in: 2...6, using: &rng) {
            let cents = Int.random(in: 150...4_500, using: &rng); subtotal += cents
            lines.append(String(format: "%@  %d.%02d", items.randomElement(using: &rng)!, cents / 100, cents % 100))
        }
        let tax = subtotal * 8 / 100
        lines += [String(format: "Subtotal  %d.%02d", subtotal / 100, subtotal % 100), String(format: "Tax  %d.%02d", tax / 100, tax % 100),
                  String(format: "%@  USD %d.%02d", invoice ? "Amount due" : "Total", (subtotal + tax) / 100, (subtotal + tax) % 100),
                  invoice ? "Payment due within 30 days" : "Paid by card ending \(Int.random(in: 1000...9999, using: &rng))", "Synthetic probe document \(UUID().uuidString.prefix(8))"]
        return lines.joined(separator: "\n")
    }

    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count >= 2 else { print("usage: ConcurrencyProbe out.jsonl [blocks] [perBlock]"); exit(64) }
        let blocks = args.count > 2 ? Int(args[2]) ?? 3 : 3, perBlock = args.count > 3 ? Int(args[3]) ?? 6 : 6
        FileManager.default.createFile(atPath: args[1], contents: nil)
        let out = try FileHandle(forWritingTo: URL(fileURLWithPath: args[1]))
        let backend = SystemBackend(), clock = ContinuousClock()
        func seconds(_ d: Duration) -> Double { Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18 }
        var rng = SystemRandomNumberGenerator(), serial = 0
        var totals: [Int: (Double, Int)] = [:]
        for block in 0..<(blocks * 2) {
            let width = block % 2 == 0 ? 1 : 2
            let texts = (0..<perBlock).map { _ -> String in serial += 1; return document(serial, &rng) }
            let start = clock.now
            var failures = 0
            if width == 1 {
                for text in texts { do { _ = try await backend.extract(text: text) } catch { failures += 1 } }
            } else {
                // Two at a time, as a bounded pipeline would.
                failures = await withTaskGroup(of: Bool.self) { group in
                    var next = 0, failed = 0
                    for _ in 0..<min(width, texts.count) { let text = texts[next]; next += 1; group.addTask { (try? await backend.extract(text: text)) == nil } }
                    while let failedOne = await group.next() {
                        if failedOne { failed += 1 }
                        if next < texts.count { let text = texts[next]; next += 1; group.addTask { (try? await backend.extract(text: text)) == nil } }
                    }
                    return failed
                }
            }
            let wall = seconds(clock.now - start)
            let row = Row(block: block, width: width, documents: perBlock, wall: wall, perDocument: wall / Double(perBlock), failures: failures)
            out.write(try JSONEncoder().encode(row)); out.write(Data("\n".utf8))
            let t = totals[width] ?? (0, 0); totals[width] = (t.0 + wall, t.1 + perBlock)
            print(String(format: "block %d width %d: %.2fs for %d documents (%.2fs each), %d failed", block, width, wall, perBlock, wall / Double(perBlock), failures))
        }
        try out.close()
        for (width, t) in totals.sorted(by: { $0.key < $1.key }) { print(String(format: "width %d: %.2fs per document over %d", width, t.0 / Double(t.1), t.1)) }
    }
}
