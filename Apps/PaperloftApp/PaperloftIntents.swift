import AppIntents
import Foundation
import PaperloftKit
import UniformTypeIdentifiers

/// The app installs its live service during App.init, before an intent can run.
/// Each operation must await library startup and propagate failures rather than showing a dialog only.
@MainActor public protocol PaperloftIntentService: AnyObject {
    var isPro: Bool { get }
    /// Copy bytes to app-owned durable storage, persist the inbox entry, then return.
    /// Never auto-file: the user must confirm the extracted fields in the review inbox.
    func queueDocumentForReview(data: Data, filename: String) async throws
    /// Export the complete library, not the current table's filtered rows. Recheck Pro here.
    /// Return an app-owned ZIP that is never rewritten; the intent returns its bytes, not the URL.
    func exportAccountantPack(range: ExportDateRange) async throws -> URL
    /// Return all committed receipts; exclude unconfirmed inbox drafts.
    func intentReceipts() async throws -> [Receipt]
    func openIntentInbox() async throws
}

@MainActor public enum PaperloftIntentRuntime {
    public static var service: (any PaperloftIntentService)?
    public static func requireService() throws -> any PaperloftIntentService {
        guard let service else { throw PaperloftIntentError.unavailable }
        return service
    }
}

public enum PaperloftIntentError: LocalizedError {
    case unavailable, proRequired, unsupportedDocument, emptyDocument, invalidDateRange, oversizedDocument, oversizedExport
    public var errorDescription: String? {
        switch self {
        case .unavailable: "Open Paperloft and choose a library before using this action."
        case .proRequired: "Accountant packs require Paperloft Pro. Open Paperloft to view upgrade options."
        case .unsupportedDocument: "Choose a PDF, PNG, JPEG or HEIC document."
        case .emptyDocument: "This document is empty or could not be read."
        case .oversizedDocument: "This document exceeds 100 MB. Import a smaller copy."
        case .oversizedExport: "This accountant pack exceeds 100 MB. Choose a shorter period, or export it from Paperloft."
        case .invalidDateRange: "Enter valid dates as YYYY-MM-DD, with the start date on or before the end date."
        }
    }
}

/// Bound intent transfers before persisting. URL-backed files are streamed off-main,
/// and their current size is checked before allocating the output buffer.
public enum IntentDocumentInput {
    public static let maximumBytes = 100 * 1024 * 1024
    public static func validate(_ data: Data) throws {
        guard !data.isEmpty else { throw PaperloftIntentError.emptyDocument }
        guard data.count <= maximumBytes else { throw PaperloftIntentError.oversizedDocument }
    }
    public static func load(_ file: IntentFile) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            guard let url = file.fileURL else {
                let data = file.data
                try validate(data)
                return data
            }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let attributes = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard attributes.isRegularFile == true else { throw PaperloftIntentError.unsupportedDocument }
            if let size = attributes.fileSize, size > maximumBytes { throw PaperloftIntentError.oversizedDocument }
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var result = Data()
            while let chunk = try handle.read(upToCount: min(1024 * 1024, maximumBytes + 1 - result.count)), !chunk.isEmpty {
                result.append(chunk)
                guard result.count <= maximumBytes else { throw PaperloftIntentError.oversizedDocument }
            }
            try validate(result)
            return result
        }.value
    }
}

/// Accountant packs are returned as bounded, memory-mapped data. A URL-backed result
/// depends on a sandbox extension the consuming process was observed unable to use.
public enum IntentExportOutput {
    public static let maximumBytes = 100 * 1024 * 1024
    public static func file(for url: URL) async throws -> IntentFile {
        let data = try await Task.detached(priority: .userInitiated) {
            // Check an uncached size first so a mapping fallback cannot read an oversized file,
            // then bound the mapped length, which reserves address space without copying.
            let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
            guard size <= maximumBytes else { throw PaperloftIntentError.oversizedExport }
            let data = try Data(contentsOf: url, options: .alwaysMapped)
            guard !data.isEmpty else { throw AppIssue("The accountant pack ZIP could not be read.") }
            guard data.count <= maximumBytes else { throw PaperloftIntentError.oversizedExport }
            return data
        }.value
        return IntentFile(data: data, filename: url.lastPathComponent, type: .zip)
    }
}

public enum SpendingPeriod: String, AppEnum {
    case thisMonth, lastMonth, thisYear, lastYear, allTime
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Period"
    public static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .thisMonth: "This month", .lastMonth: "Last month", .thisYear: "This year",
        .lastYear: "Last year", .allTime: "All time"
    ]
    public func range(now: Date = Date(), timeZone: TimeZone = .current) throws -> ExportDateRange {
        if self == .allTime { return try ExportDateRange(start: ReceiptDate(year: 1, month: 1, day: 1), end: ReceiptDate(year: 9999, month: 12, day: 31)) }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        let component: Calendar.Component = (self == .thisMonth || self == .lastMonth) ? .month : .year
        let date = (self == .lastMonth || self == .lastYear) ? calendar.date(byAdding: component, value: -1, to: now)! : now
        let interval = calendar.dateInterval(of: component, for: date)!
        let end = calendar.date(byAdding: .day, value: -1, to: interval.end)!
        return try ExportDateRange(start: IntentSpending.receiptDate(interval.start, calendar: calendar), end: IntentSpending.receiptDate(end, calendar: calendar))
    }
}

public enum IntentSpending {
    public static func receiptDate(_ date: Date, calendar: Calendar) throws -> ReceiptDate {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return try ReceiptDate(year: parts.year!, month: parts.month!, day: parts.day!)
    }
    /// Stable ISO currency labels and exact decimal amounts; no currency conversion.
    public static func summary(receipts: [Receipt], category: String?, range: ExportDateRange) throws -> String {
        let requested = category?.trimmingCharacters(in: .whitespacesAndNewlines)
        var totals: [String: Int64] = [:]
        for receipt in receipts where range.contains(receipt.date) {
            if let requested, !requested.isEmpty, receipt.category.caseInsensitiveCompare(requested) != .orderedSame { continue }
            let sum = totals[receipt.currency, default: 0].addingReportingOverflow(receipt.totalMinorUnits)
            guard !sum.overflow else { throw ReceiptError.invalidAmount }
            totals[receipt.currency] = sum.partialValue
        }
        guard !totals.isEmpty else { return "No filed documents match this category and period." }
        return try totals.keys.sorted().map { currency in
            "\(currency) \(try Money(minorUnits: totals[currency]!, currency: currency).decimal)"
        }.joined(separator: "; ")
    }
}

public struct FileDocumentIntent: AppIntent {
    public static let title: LocalizedStringResource = "File Document"
    public static let description = IntentDescription("Send a document to the review inbox. Confirm its details in Paperloft before filing.")
    public static let openAppWhenRun = true
    @Parameter(title: "Document", supportedContentTypes: [.pdf, .png, .jpeg, .heic]) public var document: IntentFile
    public init() {}
    @MainActor public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let name = URL(fileURLWithPath: document.filename).lastPathComponent
        guard ["pdf", "png", "jpg", "jpeg", "heic"].contains(URL(fileURLWithPath: name).pathExtension.lowercased()) else { throw PaperloftIntentError.unsupportedDocument }
        let data = try await IntentDocumentInput.load(document)
        let service = try PaperloftIntentRuntime.requireService()
        try await service.queueDocumentForReview(data: data, filename: name)
        try await service.openIntentInbox()
        return .result(value: "Queued for review", dialog: "Added to your inbox. Review the details in Paperloft to finish filing.")
    }
}

public struct ExportAccountantPackIntent: AppIntent {
    public static let title: LocalizedStringResource = "Export Accountant Pack"
    public static let description = IntentDescription("Export a ZIP with documents, a CSV and a summary PDF. Requires Paperloft Pro. Dates are inclusive, in YYYY-MM-DD format.")
    public static let openAppWhenRun = true
    @Parameter(title: "Start date", description: "First date, YYYY-MM-DD") public var startDate: String
    @Parameter(title: "End date", description: "Last date, YYYY-MM-DD") public var endDate: String
    public init() {}
    @MainActor public func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let range: ExportDateRange
        do { range = try ExportDateRange(start: ReceiptDate(iso8601: startDate), end: ReceiptDate(iso8601: endDate)) }
        catch { throw PaperloftIntentError.invalidDateRange }
        let service = try PaperloftIntentRuntime.requireService()
        guard service.isPro else { throw PaperloftIntentError.proRequired }
        let url = try await service.exportAccountantPack(range: range)
        return .result(value: try await IntentExportOutput.file(for: url))
    }
}

public struct TotalSpentIntent: AppIntent {
    public static let title: LocalizedStringResource = "Total Spent"
    public static let description = IntentDescription("Total filed documents for a category and period. Returns a separate exact total for each currency, without conversion. Leave category empty for all categories.")
    public static let openAppWhenRun = true
    @Parameter(title: "Category") public var category: String?
    @Parameter(title: "Period", default: .thisYear) public var period: SpendingPeriod
    public init() {}
    @MainActor public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let service = try PaperloftIntentRuntime.requireService()
        let receipts = try await service.intentReceipts()
        let text = try IntentSpending.summary(receipts: receipts, category: category, range: period.range())
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}

public struct OpenInboxIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Inbox"
    public static let description = IntentDescription("Open Paperloft's document review inbox.")
    public static let openAppWhenRun = true
    public init() {}
    @MainActor public func perform() async throws -> some IntentResult {
        try await PaperloftIntentRuntime.requireService().openIntentInbox()
        return .result()
    }
}

public struct PaperloftShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenInboxIntent(), phrases: ["Open my inbox in \(.applicationName)"], shortTitle: "Open Inbox", systemImageName: "tray")
        AppShortcut(intent: FileDocumentIntent(), phrases: ["File a document in \(.applicationName)"], shortTitle: "File Document", systemImageName: "doc.badge.plus")
        AppShortcut(intent: TotalSpentIntent(), phrases: ["Show my total spent in \(.applicationName)"], shortTitle: "Total Spent", systemImageName: "sum")
        AppShortcut(intent: ExportAccountantPackIntent(), phrases: ["Export an accountant pack in \(.applicationName)"], shortTitle: "Accountant Pack", systemImageName: "shippingbox")
    }
}
