// Verifier-owned AC-12 harness. Files randomized receipts through the public LibraryStore, exports
// accountant packs for several ranges, and writes the verifier's own expectations (computed here from
// the generated inputs, never from the exporter) plus the PDF text for check.py to compare.
import Foundation
import CryptoKit
import CoreGraphics
import CoreText
import PDFKit
import PaperloftKit

struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

let arguments = CommandLine.arguments
guard arguments.count == 4, let seed = UInt64(arguments[2]), let count = Int(arguments[3]) else {
    FileHandle.standardError.write(Data("usage: IndependentExport <work-dir> <seed> <count>\n".utf8)); exit(2)
}
let work = URL(fileURLWithPath: arguments[1], isDirectory: true)
var rng = SplitMix(state: seed)
let fm = FileManager.default
let library = work.appendingPathComponent("library"), sources = work.appendingPathComponent("sources"), packs = work.appendingPathComponent("packs")
for url in [library, sources, packs] { try fm.createDirectory(at: url, withIntermediateDirectories: true) }

func sha256(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

func makePDF(_ text: String) -> Data {
    let data = NSMutableData()
    var box = CGRect(x: 0, y: 0, width: 300, height: 420)
    let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &box, nil)!
    context.beginPDFPage(nil)
    let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
    context.textPosition = CGPoint(x: 20, y: 210)
    CTLineDraw(line, context)
    context.endPDFPage(); context.closePDF()
    return data as Data
}

let categories = ["Office supplies", "Meals", "Travel", "Software", "Legal and professional services",
                  "Cafe, \"Bistro\"", "A/B", "交通費", "Other expenses", "office supplies"]
let vendors = ["Office Depot", "Fern Cafe", "Acme, Inc.", "\"Quoted\" Vendor", "Line\nBreak Shop", "東京ストア", "Zürich Bahn", "O'Brien & Sons"]
let currencies: [(String, Int)] = [("USD", 2), ("USD", 2), ("USD", 2), ("USD", 2), ("EUR", 2), ("JPY", 0), ("KWD", 3)]
func daysIn(_ year: Int, _ month: Int) -> Int { [31, (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1] }
var dates: [(Int, Int, Int)] = []
for (year, month) in [(2025, 11), (2025, 12), (2026, 1), (2026, 2), (2026, 3), (2026, 4), (2026, 5)] {
    for day in 1...daysIn(year, month) { dates.append((year, month, day)) }
}
let forced: [(Int, Int, Int)] = [(2025, 12, 31), (2026, 1, 1), (2026, 2, 28), (2026, 3, 1), (2026, 3, 31), (2026, 4, 1)]

struct Record: Codable { let id: String; let date: String; let vendor: String; let category: String; let currency: String; let digits: Int; let minor: Int64; let tax: Int64?; let sha256: String }
var records: [Record] = []
var requests: [FilingRequest] = []
for index in 0..<count {
    let (y, m, d) = index < forced.count ? forced[index] : dates.randomElement(using: &rng)!
    let (currency, digits) = currencies.randomElement(using: &rng)!
    let minor = Int64.random(in: 1...2_500_000, using: &rng)
    let tax: Int64? = Bool.random(using: &rng) ? Int64.random(in: 0...minor, using: &rng) : nil
    let category = categories.randomElement(using: &rng)!
    let vendor = vendors.randomElement(using: &rng)!
    let receipt = try Receipt(vendor: vendor, date: ReceiptDate(year: y, month: m, day: d), totalMinorUnits: minor,
                              currency: currency, category: category, taxMinorUnits: tax)
    let data = makePDF("Verifier receipt \(index) seed \(seed) \(UUID().uuidString)")
    let source = sources.appendingPathComponent("source-\(index).pdf")
    try data.write(to: source)
    requests.append(FilingRequest(source: source, receipt: receipt))
    records.append(Record(id: receipt.id.uuidString, date: receipt.date.formatted, vendor: receipt.vendor, category: receipt.category,
                          currency: currency, digits: digits, minor: minor, tax: tax, sha256: sha256(data)))
}

let store = try LibraryStore(root: library)
var start = 0
while start < requests.count {
    _ = try await store.file(Array(requests[start..<min(start + 25, requests.count)]))
    start += 25
}
let documents = try await store.documents()
guard documents.count == records.count else { FileHandle.standardError.write(Data("filed \(documents.count) of \(records.count)\n".utf8)); exit(1) }

struct PackOutput: Codable {
    let name: String; let start: String; let end: String; let folder: String; let zip: String?
    let expectedIDs: [String]; let expectedCategoryTotals: [String: Int64]; let expectedMonthTotals: [String: Int64]
    let pdfOpened: Bool; let pdfPages: Int; let pdfTextFile: String
}
var outputs: [PackOutput] = []
let ranges: [(String, ExportDateRange)] = [
    ("q1-2026", try ExportDateRange.quarter(year: 2026, quarter: 1)),
    ("custom-2026-02-28-to-2026-03-01", try ExportDateRange(start: ReceiptDate(year: 2026, month: 2, day: 28), end: ReceiptDate(year: 2026, month: 3, day: 1))),
    ("year-2026", try ExportDateRange.year(2026)),
    ("empty-2030", try ExportDateRange.year(2030)),
]
for (name, range) in ranges {
    let lo = range.start.formatted, hi = range.end.formatted
    let selected = records.filter { lo <= $0.date && $0.date <= hi }
    var categoryTotals: [String: Int64] = [:], monthTotals: [String: Int64] = [:]
    for record in selected {
        categoryTotals[record.category + " | " + record.currency, default: 0] += record.minor
        monthTotals[String(record.date.prefix(7)) + " | " + record.currency, default: 0] += record.minor
    }
    let result = try AccountantPackExporter.export(documents: documents, libraryRoot: library, destination: packs, range: range, zip: true)
    let pdf = PDFDocument(url: result.folderURL.appendingPathComponent("summary.pdf"))
    let textFile = work.appendingPathComponent(name + "-summary.txt")
    try (pdf?.string ?? "").write(to: textFile, atomically: true, encoding: .utf8)
    outputs.append(PackOutput(name: name, start: lo, end: hi, folder: result.folderURL.path, zip: result.zipURL?.path,
                              expectedIDs: selected.map(\.id), expectedCategoryTotals: categoryTotals, expectedMonthTotals: monthTotals,
                              pdfOpened: pdf != nil, pdfPages: pdf?.pageCount ?? 0, pdfTextFile: textFile.path))
}
struct Manifest: Codable { let seed: UInt64; let records: [Record]; let packs: [PackOutput] }
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(Manifest(seed: seed, records: records, packs: outputs)).write(to: work.appendingPathComponent("manifest.json"))
print("filed \(documents.count) receipts; exported \(outputs.count) packs into \(packs.path)")
