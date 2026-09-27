import Foundation
import CryptoKit
import CoreGraphics
import CoreText
import Darwin

public struct ExportDateRange: Equatable, Sendable {
    public let start: ReceiptDate
    public let end: ReceiptDate
    public init(start: ReceiptDate, end: ReceiptDate) throws {
        guard start.formatted <= end.formatted else { throw ReceiptError.invalidDate }
        self.start = start; self.end = end
    }
    public static func year(_ year: Int) throws -> Self {
        try Self(start: ReceiptDate(year: year, month: 1, day: 1), end: ReceiptDate(year: year, month: 12, day: 31))
    }
    public static func quarter(year: Int, quarter: Int) throws -> Self {
        guard (1...4).contains(quarter) else { throw ReceiptError.invalidDate }
        let month = quarter * 3
        return try Self(start: ReceiptDate(year: year, month: month - 2, day: 1),
                        end: ReceiptDate(year: year, month: month, day: [3, 12].contains(month) ? 31 : 30))
    }
    public func contains(_ date: ReceiptDate) -> Bool { (start.formatted...end.formatted).contains(date.formatted) }
}

public struct ExportTotal: Equatable, Sendable {
    public let label: String
    public let currency: String
    public let minorUnits: Int64
}
public struct AccountantPackResult: Sendable {
    public let folderURL: URL
    public let zipURL: URL?
    public let documentCount: Int
    public let categoryTotals: [ExportTotal]
    public let monthTotals: [ExportTotal]
}

/// Local, copy-only export. Each invocation creates a new pack; errors preserve all inputs
/// and any partial output for recovery. No existing file is overwritten or removed.
public enum AccountantPackExporter {
    public static func totals(documents: [FiledDocument], range: ExportDateRange, byMonth: Bool = false) throws -> [ExportTotal] {
        var values: [String: [String: Int64]] = [:]
        for document in documents where range.contains(document.receipt.date) {
            let r = document.receipt
            let label = byMonth ? String(r.date.formatted.prefix(7)) : r.category
            let sum = (values[label]?[r.currency] ?? 0).addingReportingOverflow(r.totalMinorUnits)
            guard !sum.overflow else { throw ReceiptError.invalidAmount }
            values[label, default: [:]][r.currency] = sum.partialValue
        }
        return values.keys.sorted().flatMap { label in
            values[label]!.keys.sorted().map { ExportTotal(label: label, currency: $0, minorUnits: values[label]![$0]!) }
        }
    }

    public static func export(documents: [FiledDocument], libraryRoot: URL, destination: URL,
                              range: ExportDateRange, zip: Bool = false) throws -> AccountantPackResult {
        let selected = documents.filter { range.contains($0.receipt.date) }.sorted {
            ($0.receipt.date.formatted, $0.id.uuidString) < ($1.receipt.date.formatted, $1.id.uuidString)
        }
        guard Set(selected.map(\.id)).count == selected.count else { throw LibraryError.conflict("duplicate receipt identifiers") }
        let categories = try totals(documents: selected, range: range)
        let months = try totals(documents: selected, range: range, byMonth: true)
        let source = try ExportDirectory(url: libraryRoot)
        let parent = try ExportDirectory(url: destination)
        let name = "Accountant Pack \(range.start.formatted) to \(range.end.formatted) \(UUID().uuidString)"
        let stagingName = ".Paperloft-export-incomplete-" + UUID().uuidString
        let output = try parent.create(stagingName)
        let folder = destination.appendingPathComponent(name, isDirectory: true)
        var folders: [String: ExportDirectory] = [:]
        var folderNames: [String: String] = [:]
        var rows = [["date", "vendor", "category", "kind", "currency", "total", "total_minor_units", "tax", "file", "sha256"]]
        for document in selected {
            let r = document.receipt
            if folders[r.category] == nil {
                // Unique suffix also handles case-insensitive and sanitized-name collisions.
                let categoryName = ReceiptFilename.safeComponent(r.category) + "-" + UUID().uuidString
                folders[r.category] = try output.create(categoryName)
                folderNames[r.category] = categoryName
            }
            let ext = URL(fileURLWithPath: document.relativePath).pathExtension.lowercased()
            guard LibraryFiles.extensions.contains(ext) else { throw LibraryError.unsupportedFile }
            let filename = r.id.uuidString + "." + ext
            try source.copy(document.relativePath, to: folders[r.category]!, name: filename, expectedHash: document.contentHash)
            rows.append([r.date.formatted, r.vendor, r.category, r.kind.rawValue, r.currency,
                         try Money(minorUnits: r.totalMinorUnits, currency: r.currency).decimal,
                         String(r.totalMinorUnits), try r.taxMinorUnits.map { try Money(minorUnits: $0, currency: r.currency).decimal } ?? "",
                         folderNames[r.category]! + "/" + filename, document.contentHash])
        }
        let csv = rows.map { $0.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
        try output.write(Data(csv.utf8), name: "transactions.csv")
        try output.write(summary(range: range, count: selected.count, categories: categories, months: months), name: "summary.pdf")
        guard renameatx_np(parent.fd, stagingName, parent.fd, name, UInt32(RENAME_EXCL)) == 0 else {
            throw LibraryError.conflict(name)
        }
        var zipURL: URL?
        if zip {
            var coordinationError: NSError?
            var copyError: (any Error)?
            NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinationError) { archive in
                do {
                    guard let canonical = realpath(archive.path, nil) else { throw LibraryError.unsafePath }
                    defer { free(canonical) }
                    let resolvedArchive = URL(fileURLWithPath: String(cString: canonical))
                    let archiveParent = try ExportDirectory(url: resolvedArchive.deletingLastPathComponent())
                    try archiveParent.copy(resolvedArchive.lastPathComponent, to: parent, name: name + ".zip", expectedHash: nil)
                    zipURL = destination.appendingPathComponent(name + ".zip")
                } catch { copyError = error }
            }
            if let coordinationError { throw coordinationError }
            if let copyError { throw copyError }
            guard zipURL != nil else { throw LibraryError.conflict("ZIP could not be created") }
        }
        return AccountantPackResult(folderURL: folder, zipURL: zipURL, documentCount: selected.count, categoryTotals: categories, monthTotals: months)
    }

    private static func summary(range: ExportDateRange, count: Int, categories: [ExportTotal], months: [ExportTotal]) throws -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(data: data), let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { throw LibraryError.conflict("PDF creation failed") }
        var lines = ["Paperloft Accountant Pack", "\(range.start.formatted) through \(range.end.formatted) (inclusive)",
                     "\(count) documents", "Not tax advice. No currency conversion.", "", "Totals by category"]
        for total in categories { lines.append("\(total.label) | \(total.currency) | \(try Money(minorUnits: total.minorUnits, currency: total.currency).decimal)") }
        lines += ["", "Totals by month"]
        for total in months { lines.append("\(total.label) | \(total.currency) | \(try Money(minorUnits: total.minorUnits, currency: total.currency).decimal)") }
        let font = CTFontCreateWithName("Helvetica" as CFString, 11, nil)
        var y: CGFloat = 744
        context.beginPDFPage(nil)
        for line in lines {
            // Preserve every character and wrap long labels across lines/pages.
            let text = NSAttributedString(string: line.isEmpty ? " " : line, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
            let setter = CTTypesetterCreateWithAttributedString(text)
            var offset = 0
            while offset < text.length {
                let count = max(1, CTTypesetterSuggestLineBreak(setter, offset, 516))
                if y < 48 { context.endPDFPage(); context.beginPDFPage(nil); y = 744 }
                context.textPosition = CGPoint(x: 48, y: y)
                CTLineDraw(CTTypesetterCreateLine(setter, CFRange(location: offset, length: count)), context)
                y -= 17; offset += count
            }
        }
        context.endPDFPage(); context.closePDF()
        return data as Data
    }
}

/// Descriptor-relative access rejects traversal and symbolic links, including races
/// replacing path components. Descriptors pin opened directories for the operation.
private final class ExportDirectory {
    let fd: Int32
    init(fd: Int32) { self.fd = fd }
    convenience init(url: URL) throws {
        guard url.isFileURL else { throw LibraryError.unsafePath }
        let components = url.path.split(separator: "/").map(String.init)
        guard components.allSatisfy({ $0 != "." && $0 != ".." && !$0.contains("\0") }) else { throw LibraryError.unsafePath }
        var descriptor = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard descriptor >= 0 else { throw LibraryError.unsafePath }
        for component in components {
            let next = openat(descriptor, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            close(descriptor)
            guard next >= 0 else { throw LibraryError.unsafePath }
            descriptor = next
        }
        self.init(fd: descriptor)
    }
    deinit { close(fd) }
    func create(_ name: String) throws -> ExportDirectory {
        guard mkdirat(fd, name, 0o700) == 0 else { throw LibraryError.conflict(name) }
        let child = openat(fd, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard child >= 0 else { throw LibraryError.unsafePath }
        return ExportDirectory(fd: child)
    }
    func write(_ data: Data, name: String) throws {
        let descriptor = openat(fd, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw LibraryError.conflict(name) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        try handle.write(contentsOf: data); try handle.synchronize(); try handle.close()
    }
    func copy(_ relative: String, to destination: ExportDirectory, name: String, expectedHash: String?) throws {
        let parts = relative.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !parts.isEmpty, parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("\0") }) else { throw LibraryError.unsafePath }
        var current = dup(fd)
        guard current >= 0 else { throw LibraryError.unsafePath }
        defer { close(current) }
        for part in parts.dropLast() {
            let next = openat(current, part, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard next >= 0 else { throw LibraryError.unsafePath }
            close(current); current = next
        }
        let input = openat(current, parts.last!, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard input >= 0 else { throw LibraryError.unsafePath }
        let reader = FileHandle(fileDescriptor: input, closeOnDealloc: true)
        defer { try? reader.close() }
        var info = stat()
        guard fstat(input, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { throw LibraryError.unsafePath }
        let output = openat(destination.fd, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard output >= 0 else { throw LibraryError.conflict(name) }
        let writer = FileHandle(fileDescriptor: output, closeOnDealloc: true)
        defer { try? writer.close() }
        var hash = SHA256()
        while let chunk = try reader.read(upToCount: 1_048_576), !chunk.isEmpty {
            hash.update(data: chunk); try writer.write(contentsOf: chunk)
        }
        try writer.synchronize()
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        if let expectedHash, digest != expectedHash { throw LibraryError.sourceChanged(relative) }
    }
}
