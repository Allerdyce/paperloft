import AppKit
import CryptoKit
import Foundation
import Observation
import os
import PaperloftKit
import UniformTypeIdentifiers

struct ReceiptDraft: Codable {
    var vendor = ""
    var date = ""
    var total = ""
    var tax = ""
    var currency = "USD"
    var category = "Other expenses"
    var kind = DocumentKind.receipt
    init() {}
    init(_ fields: ExtractedFields) {
        vendor = fields.vendor ?? ""; date = fields.date ?? ""; total = fields.total ?? ""
        tax = fields.tax ?? ""; currency = fields.currency ?? "USD"
        category = fields.category ?? "Other expenses"; kind = DocumentKind(rawValue: fields.kind) ?? .receipt
    }
    func receipt() throws -> Receipt {
        guard !vendor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppIssue("Enter the vendor name.") }
        guard let date = try? ReceiptDate(iso8601: date) else { throw AppIssue("Enter a valid date as YYYY-MM-DD.") }
        let code = currency.uppercased().trimmingCharacters(in: .whitespaces)
        guard let amount = try? Money(decimal: total, currency: code) else { throw AppIssue("Enter a valid nonnegative total and a three-letter currency code, such as USD.") }
        let taxAmount: Int64?
        if tax.trimmingCharacters(in: .whitespaces).isEmpty { taxAmount = nil }
        else {
            guard let value = try? Money(decimal: tax, currency: code) else { throw AppIssue("Enter a valid nonnegative tax amount, or leave it empty.") }
            taxAmount = value.minorUnits
        }
        guard !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppIssue("Choose or enter a category.") }
        guard taxAmount == nil || taxAmount! <= amount.minorUnits else { throw AppIssue("Tax cannot exceed the total.") }
        return try Receipt(vendor: vendor, date: date, totalMinorUnits: amount.minorUnits, currency: code, category: category, kind: kind, taxMinorUnits: taxAmount)
    }
}
struct AppIssue: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
struct StoredReview: Codable {
    let hash: String
    let text: String
    let fields: ExtractedFields
    var duplicate: String?
}
struct InboxItem: Codable, Identifiable {
    let id: UUID
    var source: URL
    var bookmark: Data?
    var review: StoredReview?
    var draft = ReceiptDraft()
    var status = "waiting"
    var issue: String?
    var sample = false
    var name: String { source.lastPathComponent }
}
/// Owns a user-granted file's sandbox extension for its entire review lifetime.
final class FileGrant: @unchecked Sendable {
    let url: URL
    let bookmark: Data?
    private let scoped: Bool
    init(url: URL) throws {
        self.url = url
        if Self.isInternal(url) { scoped = false; bookmark = nil }
        else {
            let started = url.startAccessingSecurityScopedResource()
            do { bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) }
            catch { if started { url.stopAccessingSecurityScopedResource() }; throw error }
            scoped = started
        }
    }
    init(bookmark: Data) throws {
        var stale = false
        let resolved = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale)
        guard !stale else { throw AppIssue("This document's permission needs to be renewed. Import it again.") }
        guard resolved.startAccessingSecurityScopedResource() else { throw AppIssue("This document is unavailable. Import it again to renew permission.") }
        url = resolved; self.bookmark = bookmark; scoped = true
    }
    static func isInternal(_ url: URL) -> Bool {
        let base = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL.resolvingSymlinksInPath().path + "/"
        return url.standardizedFileURL.resolvingSymlinksInPath().path.hasPrefix(base)
    }
    deinit { if scoped { url.stopAccessingSecurityScopedResource() } }
}

@Observable @MainActor final class AppModel: PaperloftIntentService {
    var selection = "Inbox"
    var items: [InboxItem] = []
    var selectedItemID: UUID?
    var documents: [FiledDocument] = []
    var allDocuments: [FiledDocument] = []
    var batches: [FilingBatch] = []
    var libraryURL: URL?
    var isSampleLibrary = false
    var busy = false
    var processing = false
    var activity = ""
    var message: String?
    var search = ""
    var yearFilter = "All years"
    var categoryFilter = "All categories"
    var kindFilter = "All types"
    var categories: [String]
    var filenameTemplate: String { didSet { preferences.set(filenameTemplate, forKey: "filenameTemplate") } }
    var mode: FilingMode { didSet { preferences.set(mode.rawValue, forKey: "filingMode") } }
    var quickLookURL: URL?
    var showExport = false
    var exportResult: AccountantPackResult?
    var exportError: String?
    let testMode: Bool
    let support: URL
    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private var libraryAccess: LibraryAccess?
    @ObservationIgnored private var exportAccess: LibraryAccess?
    @ObservationIgnored private var sourceGrants: [UUID: FileGrant] = [:]
    @ObservationIgnored private var moveGrants: [String: LibraryAccess] = [:]
    @ObservationIgnored private var engine: ReceiptEngine?
    @ObservationIgnored private var processingTask: Task<Void, Never>?
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var startupTask: Task<Void, any Error>?
    @ObservationIgnored private let proEntitlement: @MainActor () -> Bool
    @ObservationIgnored var openInboxWindow: (@MainActor () -> Void)?

    static func argument(_ key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let position = args.firstIndex(of: key), position + 1 < args.count else { return nil }
        return args[position + 1]
    }
    init(support suppliedSupport: URL? = nil, preferences suppliedPreferences: UserDefaults? = nil,
         proEntitlement: @escaping @MainActor () -> Bool = AppModel.defaultIntentProEntitlement) {
        testMode = Self.argument("-PaperloftUITestMode") == "YES"
        preferences = suppliedPreferences ?? (testMode ? UserDefaults(suiteName: "app.paperloft.receipts.UI")! : .standard)
        self.proEntitlement = proEntitlement
        categories = preferences.stringArray(forKey: "categories") ?? ["Advertising", "Contract labor", "Insurance", "Legal and professional services", "Meals", "Office supplies", "Rent", "Repairs", "Software", "Taxes and licenses", "Travel", "Utilities", "Vehicle", "Other expenses"]
        filenameTemplate = preferences.string(forKey: "filenameTemplate") ?? ReceiptNameTemplate.defaultPattern
        mode = FilingMode(rawValue: preferences.string(forKey: "filingMode") ?? "copy") ?? .copy
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        support = suppliedSupport ?? base.appendingPathComponent(testMode ? "Paperloft-UI" : "Paperloft", isDirectory: true)
    }
    var selectedItem: InboxItem? { items.first { $0.id == selectedItemID } ?? items.first { $0.status != "aside" } }
    var inboxCount: Int { items.filter { $0.status != "aside" }.count }
    var canFile: Bool { !busy && selectedItem?.status == "ready" && selectedItem?.review?.duplicate == nil && (try? selectedItem?.draft.receipt()) != nil && templateError == nil }

    var templateError: String? {
        do {
            let template = try ReceiptNameTemplate(filenameTemplate)
            if let item = selectedItem, let receipt = try? item.draft.receipt() { _ = try template.name(for: receipt, fileExtension: item.source.pathExtension) }
            return nil
        } catch { return error.localizedDescription }
    }
    func start() async {
        do { try await awaitStartup() }
        catch { message = error.localizedDescription }
    }
    private func awaitStartup() async throws {
        if let startupTask { return try await startupTask.value }
        let task = Task { @MainActor in
            do { try await self.loadStartupState() }
            catch {
                // Only this task clears its failure; a waiting caller must never
                // erase a later retry's task after the actor becomes reentrant.
                self.startupTask = nil
                throw error
            }
        }
        startupTask = task
        try await task.value
    }
    private func loadStartupState() async throws {
        busy = true; defer { busy = false }
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let inboxURL = support.appendingPathComponent("inbox.json")
        if FileManager.default.fileExists(atPath: inboxURL.path) {
            items = try JSONDecoder().decode([InboxItem].self, from: Data(contentsOf: inboxURL))
        }
        for i in items.indices where items[i].status != "aside" {
            do {
                let grant: FileGrant
                if let bookmark = items[i].bookmark { grant = try FileGrant(bookmark: bookmark) }
                else {
                    guard FileGrant.isInternal(items[i].source) else { throw AppIssue("Import this document again to renew access.") }
                    grant = try FileGrant(url: items[i].source)
                }
                sourceGrants[items[i].id] = grant; items[i].source = grant.url
                if items[i].status == "processing" { items[i].status = "waiting" }
            } catch { items[i].status = "failed"; items[i].issue = error.localizedDescription }
        }
        let saved = preferences.dictionary(forKey: "moveFolderBookmarks") as? [String: Data] ?? [:]
        for (path, bookmark) in saved { if let access = try? LibraryAccess(bookmark: bookmark) { moveGrants[path] = access } }
        if let bookmark = preferences.data(forKey: "paperloft.libraryBookmark") {
            let access = try LibraryAccess(bookmark: bookmark); libraryAccess = access
            try await configure(access.url, sample: false)
        } else if let path = preferences.string(forKey: "paperloft.demoLibraryPath"), URL(fileURLWithPath: path).path.hasPrefix(support.path + "/") {
            try await configure(URL(fileURLWithPath: path), sample: true)
        } else if testMode { try await createSampleLibrary(discardInbox: false) }
        selectedItemID = items.first { $0.status != "aside" }?.id
    }
    private func configure(_ url: URL, sample: Bool) async throws {
        processingTask?.cancel(); generation = UUID(); processing = false
        for i in items.indices where items[i].status == "processing" { items[i].status = "waiting" }
        let library = try LibraryStore(root: url)
        let key = SHA256.hash(data: Data(library.root.path.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
        let indexURL = support.appendingPathComponent("index-\(key).sqlite")
        let index = try await Task.detached(priority: .utility) { try ReceiptIndex.open(at: indexURL) }.value
        let backend: any ExtractionBackend
        switch Self.argument("-PaperloftModel") {
        case "stub": backend = StubBackend()
        case "parser": backend = ParserBackend()
        default: backend = SystemBackend()
        }
        engine = ReceiptEngine(library: library, index: index, backend: backend)
        libraryURL = library.root; isSampleLibrary = sample
        do { try await library.recover() } catch { message = "Recovery needs attention: " + error.localizedDescription }
        let records = try await library.documents()
        if try await index.search() != records.sorted(by: { $0.receipt.date.formatted == $1.receipt.date.formatted ? $0.relativePath < $1.relativePath : $0.receipt.date.formatted > $1.receipt.date.formatted }) {
            activity = "Rebuilding search index…"
            let report = try await index.rebuild(from: library)
            if !report.textFailures.isEmpty { message = "The library is available. Text search could not be rebuilt for \(report.textFailures.count) documents." }
            activity = ""
        }
        await refresh(); processWaiting()
    }
    func chooseLibrary() async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        let panel = NSOpenPanel(); panel.title = "Choose your Paperloft library"
        panel.message = "Choose a folder, or create a Paperloft folder in Documents. Your filed documents stay here as ordinary files."
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        panel.nameFieldStringValue = "Paperloft"
        guard await panel.begin() == .OK, let url = panel.url else { return }
        do {
            let bookmark = try LibraryAccess.bookmark(for: url)
            let access = try LibraryAccess(bookmark: bookmark)
            try await configure(access.url, sample: false)
            libraryAccess = access; preferences.set(bookmark, forKey: "paperloft.libraryBookmark")
            preferences.removeObject(forKey: "paperloft.demoLibraryPath")
        } catch { message = error.localizedDescription }
    }
    func newSampleLibrary(discardInbox: Bool = false) async throws {
        guard !busy else { throw AppIssue("Wait for the current operation to finish before changing libraries.") }
        busy = true; defer { busy = false }
        try await createSampleLibrary(discardInbox: discardInbox)
    }
    private func createSampleLibrary(discardInbox: Bool) async throws {
        let url = support.appendingPathComponent("Sample-Library-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try await configure(url, sample: true)
        if discardInbox {
            for item in items where item.status != "aside" { setAside(item.id) }
        }
        libraryAccess = nil; preferences.removeObject(forKey: "paperloft.libraryBookmark")
        preferences.set(url.path, forKey: "paperloft.demoLibraryPath")
    }
    func trySamples() async {
        do {
            if engine == nil { try await newSampleLibrary() }
            guard let resources = Bundle.main.resourceURL else { throw AppIssue("Sample receipts are unavailable.") }
            let names = ["01-office", "02-meal", "03-travel", "04-software", "05-utilities"]
            let folder = support.appendingPathComponent("Sample-Imports-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var urls: [URL] = []
            for name in names {
                let options = [resources.appendingPathComponent(name + ".pdf"), resources.appendingPathComponent("Resources/Samples/" + name + ".pdf"), resources.appendingPathComponent("Samples/" + name + ".pdf")]
                guard let original = options.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else { throw AppIssue("A bundled sample receipt is missing.") }
                let copy = folder.appendingPathComponent(original.lastPathComponent)
                try FileManager.default.copyItem(at: original, to: copy); urls.append(copy)
            }
            intake(urls, sample: true)
        } catch { message = error.localizedDescription }
    }
    func importFiles() async {
        let panel = NSOpenPanel(); panel.title = "Import receipts"
        panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.pdf, .png, .jpeg, .heic]
        if await panel.begin() == .OK { intake(panel.urls) }
    }
    func intake(_ urls: [URL], sample: Bool = false) {
        for url in urls {
            do {
                guard ["pdf", "png", "jpg", "jpeg", "heic"].contains(url.pathExtension.lowercased()) else { throw AppIssue("Import PDF, PNG, JPEG or HEIC documents.") }
                guard !items.contains(where: { $0.source == url && $0.status != "aside" }) else { continue }
                let grant = try FileGrant(url: url)
                let item = InboxItem(id: UUID(), source: grant.url, bookmark: grant.bookmark, sample: sample)
                sourceGrants[item.id] = grant; items.append(item)
                if selectedItemID == nil { selectedItemID = item.id }
            } catch { message = error.localizedDescription }
        }
        selection = "Inbox"; persist(); processWaiting()
    }
    func pasteImage() {
        do {
            guard let image = NSImage(pasteboard: .general), let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { throw AppIssue("Copy an image first, then choose Paste Image.") }
            let folder = support.appendingPathComponent("Pasted", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(UUID().uuidString + ".png"); try png.write(to: url, options: .atomic)
            intake([url])
        } catch { message = error.localizedDescription }
    }
    private func processWaiting() {
        guard !processing, let engine else { return }
        let token = generation; processing = true
        processingTask = Task {
            let log = OSLog(subsystem: "app.paperloft.receipts", category: "Pipeline")
            let interval = OSSignpostID(log: log)
            os_signpost(.begin, log: log, name: "UnderstandInboxBatch", signpostID: interval)
            defer {
                os_signpost(.end, log: log, name: "UnderstandInboxBatch", signpostID: interval)
                if generation == token { processing = false; activity = "" }
            }
            while let position = items.firstIndex(where: { $0.status == "waiting" }) {
                if Task.isCancelled || generation != token { return }
                let id = items[position].id, source = items[position].source
                items[position].status = "processing"; activity = "Reading \(items[position].name)…"; persist()
                do {
                    let review = try await engine.understand(source)
                    guard !Task.isCancelled, generation == token, let index = items.firstIndex(where: { $0.id == id }) else { return }
                    guard items[index].status == "processing" else { continue }
                    items[index].review = StoredReview(hash: review.contentHash, text: review.text, fields: review.fields, duplicate: review.duplicateOf)
                    items[index].draft = ReceiptDraft(review.fields); items[index].status = "ready"
                } catch {
                    guard !Task.isCancelled, generation == token, let index = items.firstIndex(where: { $0.id == id }) else { return }
                    guard items[index].status == "processing" else { continue }
                    items[index].status = "failed"; items[index].issue = error.localizedDescription
                }
                persist()
            }
        }
    }
    func edit(_ draft: ReceiptDraft, id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].draft = draft; persist()
    }
    func setAside(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].status = "aside"; sourceGrants[id] = nil
        selectedItemID = items.first { $0.status != "aside" }?.id; persist()
    }
    func fileSelected() async {
        guard !busy, let engine, let item = selectedItem, item.status == "ready", let stored = item.review else { return }
        guard stored.duplicate == nil else { message = "This document is already in the library. Set this duplicate aside."; return }
        busy = true; defer { busy = false }
        let sourceAccess = sourceGrants[item.id], activeLibraryAccess = libraryAccess
        defer { withExtendedLifetime(sourceAccess) {}; withExtendedLifetime(activeLibraryAccess) {} }
        do {
            let receipt = try item.draft.receipt()
            if mode == .move, !FileGrant.isInternal(item.source), moveGrants[item.source.deletingLastPathComponent().path] == nil {
                guard await grantMoveFolder(required: item.source.deletingLastPathComponent()) else { return }
            }
            let reviewed = ReviewedDocument(id: item.id, source: item.source, contentHash: stored.hash, text: stored.text, fields: stored.fields, duplicateOf: stored.duplicate)
            let outcome = try await engine.file(reviewed, confirmed: receipt, mode: mode, filenameTemplate: filenameTemplate)
            items.removeAll { $0.id == item.id }; sourceGrants[item.id] = nil
            selectedItemID = items.first { $0.status != "aside" }?.id; persist(); await refresh()
            if outcome.indexNeedsRebuild { message = "The document was filed. Rebuild the search index in Settings to update search." }
        } catch { message = error.localizedDescription }
    }
    func grantMoveFolder(required: URL? = nil) async -> Bool {
        let panel = NSOpenPanel(); panel.title = "Allow moving and undo"
        panel.message = required.map { "Choose \($0.lastPathComponent) so Paperloft can move the original and restore it when you undo." } ?? "Choose an original document's folder to renew access for moving or undo."
        panel.directoryURL = required; panel.canChooseFiles = false; panel.canChooseDirectories = true
        guard await panel.begin() == .OK, let url = panel.url else { return false }
        do {
            if let required, url.standardizedFileURL.resolvingSymlinksInPath() != required.standardizedFileURL.resolvingSymlinksInPath() { throw AppIssue("Choose the original document's folder.") }
            let bookmark = try LibraryAccess.bookmark(for: url), access = try LibraryAccess(bookmark: bookmark)
            moveGrants[url.path] = access
            var saved = preferences.dictionary(forKey: "moveFolderBookmarks") as? [String: Data] ?? [:]
            saved[url.path] = bookmark; preferences.set(saved, forKey: "moveFolderBookmarks")
            return true
        } catch { message = error.localizedDescription; return false }
    }
    func undo(_ batch: FilingBatch) async {
        guard let engine, !busy else { return }; busy = true; defer { busy = false }
        let access = libraryAccess
        defer { withExtendedLifetime(access) {} }
        do {
            let indexed = try await engine.undo(batch); await refresh()
            if !indexed { message = "Undo completed. Rebuild the search index in Settings." }
        } catch { message = error.localizedDescription }
    }
    func refresh() async {
        guard let engine else { return }
        let token = generation
        do {
            let history = try await engine.library.history()
            let records = try await engine.library.documents()
            let results = try await engine.index.search(query)
            guard token == generation, !Task.isCancelled else { return }
            batches = history
            allDocuments = records
            for i in items.indices {
                if let hash = items[i].review?.hash {
                    items[i].review?.duplicate = allDocuments.first { $0.contentHash == hash }?.relativePath
                }
            }
            persist()
            documents = results
        } catch { if token == generation, !Task.isCancelled { message = error.localizedDescription } }
    }
    private var query: ReceiptQuery {
        ReceiptQuery(text: search, year: Int(yearFilter), category: categoryFilter == "All categories" ? nil : categoryFilter, kind: DocumentKind(rawValue: kindFilter))
    }
    func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            await refresh()
        }
    }
    func rebuildIndex() async {
        guard let engine, !busy else { return }; busy = true; defer { busy = false; activity = "" }
        activity = "Rebuilding search index…"
        do {
            let report = try await engine.index.rebuild(from: engine.library); await refresh()
            message = report.textFailures.isEmpty ? "Search index rebuilt for \(report.indexedDocuments) documents." : "Indexed \(report.indexedDocuments) documents; text was unavailable for \(report.textFailures.count)."
        } catch { message = error.localizedDescription }
    }
    func beginExport() {
        guard !busy else { return }
        exportResult = nil; exportAccess = nil; exportError = nil; quickLookURL = nil; showExport = true
    }
    func export(range: ExportDateRange, zipped: Bool) async {
        guard !busy, let engine else { return }
        busy = true; defer { busy = false }
        exportError = nil
        let sourceAccess = libraryAccess
        defer { withExtendedLifetime(sourceAccess) {} }
        do {
            let destination: URL
            let destinationAccess: LibraryAccess?
            if testMode {
                destination = support.appendingPathComponent("Exports", isDirectory: true)
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                destinationAccess = nil
            } else {
                let panel = NSOpenPanel(); panel.title = "Choose export destination"
                panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
                guard await panel.begin() == .OK, let url = panel.url else { return }
                let access = try LibraryAccess(bookmark: LibraryAccess.bookmark(for: url))
                destination = access.url; destinationAccess = access
            }
            defer { withExtendedLifetime(destinationAccess) {} }
            let records = try await engine.library.documents()
            let root = await engine.library.root.resolvingSymlinksInPath()
            let target = destination.resolvingSymlinksInPath()
            exportResult = try await Task.detached(priority: .userInitiated) {
                try AccountantPackExporter.export(documents: records, libraryRoot: root, destination: target, range: range, zip: zipped)
            }.value
            exportAccess = destinationAccess
        } catch { exportError = "The accountant pack could not be completed. " + error.localizedDescription }
    }
    func revealExport() {
        if let result = exportResult { NSWorkspace.shared.activateFileViewerSelecting([result.zipURL ?? result.folderURL]) }
    }
    func saveCategories() { preferences.set(categories, forKey: "categories") }
    func reveal(_ document: FiledDocument? = nil) {
        guard let libraryURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([document.map { libraryURL.appendingPathComponent($0.relativePath) } ?? libraryURL])
    }
    static func defaultIntentProEntitlement() -> Bool {
        #if DEBUG || QA
        // The documented mock-store hook is never compiled into Release.
        if argument("-PaperloftStoreMock") == "YES" { return true }
        #endif
        // Commerce integration supplies the cached, verified StoreKit entitlement.
        return false
    }
    var isPro: Bool { proEntitlement() }

    func queueDocumentForReview(data: Data, filename: String) async throws {
        try await awaitStartup()
        guard !busy else { throw AppIssue("Wait for the current operation to finish before importing.") }
        try IntentDocumentInput.validate(data)
        let name = URL(fileURLWithPath: filename).lastPathComponent
        guard ["pdf", "png", "jpg", "jpeg", "heic"].contains(URL(fileURLWithPath: name).pathExtension.lowercased()) else { throw PaperloftIntentError.unsupportedDocument }
        busy = true; defer { busy = false }
        let folder = support.appendingPathComponent("Intent-Imports", isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let source = folder.appendingPathComponent(name)
        try data.write(to: source, options: .atomic)
        let item = InboxItem(id: UUID(), source: source)
        let updated = items + [item]
        // Commit the inbox before exposing success or scheduling extraction. A failed
        // inbox write leaves the copied input intact for recovery, never silently filed.
        try JSONEncoder().encode(updated).write(to: support.appendingPathComponent("inbox.json"), options: .atomic)
        items = updated
        selectedItemID = item.id; selection = "Inbox"
        processWaiting()
    }

    func intentReceipts() async throws -> [Receipt] {
        try await awaitStartup()
        guard !busy else { throw AppIssue("Wait for the current operation to finish before reading totals.") }
        guard let engine else { throw PaperloftIntentError.unavailable }
        busy = true; defer { busy = false }
        return try await engine.library.documents().map(\.receipt)
    }

    func exportAccountantPack(range: ExportDateRange) async throws -> URL {
        try await awaitStartup()
        guard isPro else { throw PaperloftIntentError.proRequired }
        guard !busy else { throw AppIssue("Wait for the current operation to finish before exporting.") }
        guard let engine else { throw PaperloftIntentError.unavailable }
        busy = true; defer { busy = false }
        let sourceAccess = libraryAccess
        defer { withExtendedLifetime(sourceAccess) {} }
        // Intent output lives in durable app-owned storage. No external destination
        // grant can expire while the system copies the returned IntentFile.
        let destination = support.appendingPathComponent("Intent-Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let records = try await engine.library.documents()
        let root = await engine.library.root.resolvingSymlinksInPath()
        let target = destination.resolvingSymlinksInPath()
        guard isPro else { throw PaperloftIntentError.proRequired }
        let result = try await Task.detached(priority: .userInitiated) {
            try AccountantPackExporter.export(documents: records, libraryRoot: root, destination: target, range: range, zip: true)
        }.value
        guard let zip = result.zipURL else { throw AppIssue("The accountant pack ZIP could not be created.") }
        return zip
    }

    func openIntentInbox() async throws {
        try await awaitStartup()
        selection = "Inbox"
        if let openInboxWindow { openInboxWindow() }
        NSApplication.shared.activate()
        NSApplication.shared.windows.first(where: { $0.title == "Paperloft Receipts" })?.makeKeyAndOrderFront(nil)
    }

    private func persist() {
        do { try JSONEncoder().encode(items).write(to: support.appendingPathComponent("inbox.json"), options: .atomic) }
        catch { message = "The inbox could not be saved. Your originals are unchanged. " + error.localizedDescription }
    }
}
