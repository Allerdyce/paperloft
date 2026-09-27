import AppKit
import Darwin
import CryptoKit
import Foundation
import Observation
import PaperloftKit
import UniformTypeIdentifiers

struct ReceiptDraft: Codable, Sendable {
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
struct StoredReview: Codable, Sendable {
    let hash: String
    let text: String
    let fields: ExtractedFields
    var duplicate: String?
    // Derived once from immutable extraction inputs, never from editable draft fields.
    // Do not persist it: restored inboxes recompute with the current assessment rules.
    let assessment: ExtractionAssessment
    let sourceCheck: ExtractedFields
    private enum CodingKeys: String, CodingKey { case hash, text, fields, duplicate }
    init(_ review: ReviewedDocument) {
        hash = review.contentHash; text = review.text; fields = review.fields
        duplicate = review.duplicateOf; assessment = review.assessment; sourceCheck = ParserBackend.parse(review.text)
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        hash = try values.decode(String.self, forKey: .hash)
        text = try values.decode(String.self, forKey: .text)
        fields = try values.decode(ExtractedFields.self, forKey: .fields)
        duplicate = try values.decodeIfPresent(String.self, forKey: .duplicate)
        sourceCheck = ParserBackend.parse(text)
        assessment = ExtractionAssessment(fields: fields, parser: sourceCheck)
    }
}
struct WatchedDeliveryProof: Codable, Equatable, Sendable {
    let sourceKey: String
    let contentHash: String
    let sequence: Int64
}
struct InboxItem: Codable, Identifiable, Sendable {
    let id: UUID
    var source: URL
    var bookmark: Data?
    var watchedDelivery: WatchedDeliveryProof?
    var review: StoredReview?
    var draft = ReceiptDraft()
    var status = "waiting"
    var issue: String?
    var sample = false
    var importNotices: [String]?
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

@Observable @MainActor final class AppModel {
    var selection = "Inbox"
    var items: [InboxItem] = []
    var selectedItemID: UUID?
    var documents: [FiledDocument] = []
    var deletedDocuments: [DeletedReceipt] = []
    var allDocuments: [FiledDocument] = []
    var batches: [FilingBatch] = []
    var libraryURL: URL?
    var isSampleLibrary = false
    enum OperationKind { case libraryMutation, background }
    private var manualBusy = false
    private var activeOperations: [UUID: OperationKind] = [:]
    var busy: Bool {
        get { manualBusy || !activeOperations.isEmpty }
        set { manualBusy = newValue }
    }
    private var filingBlocked: Bool {
        manualBusy || activeOperations.values.contains { $0 == .libraryMutation }
    }
    @discardableResult func beginOperation(_ kind: OperationKind) -> UUID {
        let token = UUID(); activeOperations[token] = kind; return token
    }
    func endOperation(_ token: UUID) { activeOperations[token] = nil }
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
    var watchedFolderURL: URL?
    var watchedEnabled = false
    var watchedStatus = "Choose a folder to send new documents to review."
    var watchedIssues: [String] = []
    @ObservationIgnored private var watchedAccess: LibraryAccess?
    @ObservationIgnored private var watchedScanner: WatchedFolderScanner?
    @ObservationIgnored private var watchedTask: Task<Void, Never>?
    @ObservationIgnored private var watchedGeneration = UUID()
    @ObservationIgnored private var watchedConfiguration = UUID()
    @ObservationIgnored private(set) var watchedConfigurationPending = false
    @ObservationIgnored private var watchedStoppingTask: Task<Void, Never>?
    @ObservationIgnored private var watchedScanning = false
    @ObservationIgnored private var watchedDeliveries: [String: WatchedDeliveryProof] = [:]
    @ObservationIgnored private var watchedDeliverySequence: Int64 = 0
    @ObservationIgnored private var watchedLedgerTask: Task<Void, any Error>?
    @ObservationIgnored private var watchedLedgerToken: UUID?
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
    @ObservationIgnored private var refreshGeneration = UUID()
    @ObservationIgnored private var inboxMayBeMutated = false
    @ObservationIgnored private var startupTask: Task<Void, any Error>?
    @ObservationIgnored private let proEntitlement: @MainActor () -> Bool

    static func argument(_ key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let position = args.firstIndex(of: key), position + 1 < args.count else { return nil }
        return args[position + 1]
    }
    init(support suppliedSupport: URL? = nil, preferences suppliedPreferences: UserDefaults? = nil,
         proEntitlement: @escaping @MainActor () -> Bool = AppModel.defaultProEntitlement) {
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
    var filingUnavailableReason: String? {
        if filingBlocked { return "Finishing a library change. Filing will be available when it completes." }
        guard inboxMayBeMutated, engine != nil else { return "Choose a library before filing a receipt." }
        guard let item = selectedItem else { return "Select a receipt to file." }
        guard item.status == "ready" else { return "Wait for this receipt to finish processing." }
        if item.review?.duplicate != nil { return "This receipt is already in your library. Remove the duplicate from the Inbox." }
        do { _ = try item.draft.receipt() }
        catch { return error.localizedDescription }
        return templateError
    }
    var canFile: Bool { filingUnavailableReason == nil }

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
        guard !busy else { throw AppIssue("Wait for the current operation to finish before opening the inbox.") }
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
        let operation = beginOperation(.libraryMutation); defer { endOperation(operation) }
        inboxMayBeMutated = false
        let support = support
        // Parsing restored assessments and reading the snapshot must not block UI.
        // Publish only after the entire snapshot has decoded successfully.
        let restored = try await Task.detached(priority: .userInitiated) {
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            let inboxURL = support.appendingPathComponent("inbox.json")
            do { return try JSONDecoder().decode([InboxItem].self, from: Data(contentsOf: inboxURL)) }
            catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                // A broken symlink or inaccessible history is not an empty inbox.
                // lstat also avoids following a dangling link when checking absence.
                var status = stat()
                if lstat(inboxURL.path, &status) == -1 && errno == ENOENT { return [InboxItem]() }
                throw error
            }
        }.value
        items = restored
        let deliveryURL = support.appendingPathComponent("watched-deliveries.json")
        var deliveryInfo = stat()
        let deliveryExists = lstat(deliveryURL.path, &deliveryInfo) == 0
        guard deliveryExists || errno == ENOENT else { throw AppIssue("Watched-folder delivery history could not be inspected.") }
        if deliveryExists {
            let restored = try await Task.detached(priority: .utility) {
                let data = try Self.readWatchedLedger(deliveryURL)
                let records = try JSONDecoder().decode([String: WatchedDeliveryProof].self, from: data)
                guard records.count <= 25_000, records.allSatisfy({ key, proof in
                    key == proof.sourceKey && key.count == 64 && proof.contentHash.count == 64 && proof.sequence > 0
                        && (key + proof.contentHash).utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
                }) else { throw AppIssue("Watched-folder delivery history is corrupt. Documents were preserved.") }
                return (records, records.values.map(\.sequence).max() ?? 0)
            }.value
            watchedDeliveries = restored.0; watchedDeliverySequence = restored.1
        }
        // A crash after inbox commit but before scanner acknowledgment must not enqueue it twice.
        try await recordWatchedDeliveries(items.compactMap(\.watchedDelivery))
        inboxMayBeMutated = true
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
        if preferences.bool(forKey: "watchedFolderEnabled"), !watchedConfigurationPending {
            let configuration = watchedConfiguration
            Task { [weak self] in
                guard let self, self.watchedConfiguration == configuration else { return }
                await self.restoreWatchedFolder()
            }
        }
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
        do { try await awaitRestoredInbox() }
        catch { message = error.localizedDescription; return }
        guard !busy else { return }
        let operation = beginOperation(.libraryMutation); defer { endOperation(operation) }
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
        try await awaitRestoredInbox()
        guard !busy else { throw AppIssue("Wait for the current operation to finish before changing libraries.") }
        let operation = beginOperation(.libraryMutation); defer { endOperation(operation) }
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
            await intake(urls, sample: true)
        } catch { message = error.localizedDescription }
    }
    func importFiles() async {
        let panel = NSOpenPanel(); panel.title = "Import receipts"
        panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.pdf, .png, .jpeg, .heic, UTType(filenameExtension: "eml") ?? .emailMessage]
        if await panel.begin() == .OK { await intake(panel.urls) }
    }
    func intake(_ urls: [URL], sample: Bool = false) async {
        // Acquire permissions before the first suspension. A drag/open URL's
        // temporary sandbox access must survive the startup wait.
        var grants: [FileGrant] = []
        for url in urls {
            do {
                guard ["pdf", "png", "jpg", "jpeg", "heic", "eml"].contains(url.pathExtension.lowercased()) else { throw AppIssue("Import PDF, PNG, JPEG, HEIC or EML email files.") }
                grants.append(try FileGrant(url: url))
            } catch { message = error.localizedDescription }
        }
        guard !grants.isEmpty else { return }
        do { try await awaitStartup() }
        catch { message = error.localizedDescription; return }
        for grant in grants {
            guard !items.contains(where: { $0.source == grant.url && $0.status != "aside" }) else { continue }
            let item = InboxItem(id: UUID(), source: grant.url, bookmark: grant.bookmark, sample: sample)
            sourceGrants[item.id] = grant; items.append(item)
            if selectedItemID == nil { selectedItemID = item.id }
        }
        selection = "Inbox"; persist(); processWaiting()
    }
    func pasteImage() async {
        do {
            guard let image = NSImage(pasteboard: .general), let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { throw AppIssue("Copy an image first, then choose Paste Image.") }
            let folder = support.appendingPathComponent("Pasted", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(UUID().uuidString + ".png"); try png.write(to: url, options: .atomic)
            await intake([url])
        } catch { message = error.localizedDescription }
    }
    private func processWaiting() {
        guard inboxMayBeMutated, !processing, let engine else { return }
        let token = generation; processing = true
        processingTask = Task {
            defer { if generation == token { processing = false; activity = "" } }
            while let position = items.firstIndex(where: { $0.status == "waiting" }) {
                if Task.isCancelled || generation != token { return }
                let id = items[position].id, source = items[position].source
                items[position].status = "processing"; activity = "Reading \(items[position].name)…"; persist()
                do {
                    if source.pathExtension.lowercased() == "eml" {
                        let grant = sourceGrants[id]
                        let destination = support
                        let imported = try await Task.detached(priority: .userInitiated) {
                            defer { withExtendedLifetime(grant) {} }
                            return try MailImport.materialize(source: source, destination: destination)
                        }.value
                        guard !Task.isCancelled, generation == token, let index = items.firstIndex(where: { $0.id == id }) else { return }
                        guard items[index].status == "processing" else { continue }
                        let sample = items[index].sample
                        var replacements: [InboxItem] = []
                        for url in imported.documents {
                            let access = try FileGrant(url: url)
                            let item = InboxItem(id: UUID(), source: url, bookmark: access.bookmark, sample: sample, importNotices: imported.notices)
                            sourceGrants[item.id] = access; replacements.append(item)
                        }
                        items.replaceSubrange(index...index, with: replacements)
                        sourceGrants[id] = nil
                        if selectedItemID == id { selectedItemID = replacements.first?.id }
                        persist()
                        continue
                    }
                    let review = try await engine.understand(source)
                    guard !Task.isCancelled, generation == token, let index = items.firstIndex(where: { $0.id == id }) else { return }
                    guard items[index].status == "processing" else { continue }
                    items[index].review = StoredReview(review)
                    items[index].draft = ReceiptDraft(review.fields); items[index].status = "ready"
                } catch {
                    guard !Task.isCancelled, generation == token, let index = items.firstIndex(where: { $0.id == id }) else { return }
                    guard items[index].status == "processing" else { continue }
                    items[index].status = "failed"; items[index].issue = error.localizedDescription + (source.pathExtension.lowercased() == "eml" ? " The original email is unchanged. Save the receipt as a PDF from Mail or import the email again." : "")
                }
                persist()
            }
        }
    }
    func edit(_ draft: ReceiptDraft, id: UUID) {
        guard canMutateRestoredInbox() else { return }
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].draft = draft; persist()
    }
    func setAside(_ id: UUID) {
        guard canMutateRestoredInbox() else { return }
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].status = "aside"; sourceGrants[id] = nil
        selectedItemID = items.first { $0.status != "aside" }?.id; persist()
    }
    func fileSelected() async {
        guard !filingBlocked, inboxMayBeMutated, let engine, let item = selectedItem, item.status == "ready", let stored = item.review else { return }
        guard stored.duplicate == nil else { message = "This document is already in the library. Remove this duplicate from the Inbox."; return }
        let operation = beginOperation(.libraryMutation); defer { endOperation(operation) }
        let sourceAccess = sourceGrants[item.id], activeLibraryAccess = libraryAccess
        defer { withExtendedLifetime(sourceAccess) {}; withExtendedLifetime(activeLibraryAccess) {} }
        do {
            if let proof = item.watchedDelivery { try await recordWatchedDelivery(proof) }
            let receipt = try item.draft.receipt()
            if mode == .move, !FileGrant.isInternal(item.source), moveGrants[item.source.deletingLastPathComponent().path] == nil {
                guard await grantMoveFolder(required: item.source.deletingLastPathComponent()) else { return }
            }
            let reviewed = ReviewedDocument(id: item.id, source: item.source, contentHash: stored.hash, text: stored.text, fields: stored.fields, duplicateOf: stored.duplicate)
            let outcome = try await engine.file(reviewed, confirmed: receipt, mode: mode, filenameTemplate: filenameTemplate)
            items.removeAll { $0.id == item.id }; sourceGrants[item.id] = nil
            if selectedItemID == item.id { selectedItemID = items.first { $0.status != "aside" }?.id }
            persist(); await refresh()
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
        guard let engine, !busy else { return }; let operation = beginOperation(.libraryMutation); defer { endOperation(operation) }
        let access = libraryAccess
        defer { withExtendedLifetime(access) {} }
        do {
            let indexed = try await engine.undo(batch); await refresh()
            if !indexed { message = "Undo completed. Rebuild the search index in Settings." }
        } catch { message = error.localizedDescription }
    }
    func deleteDocument(_ document: FiledDocument) async {
        guard inboxMayBeMutated, !busy, let engine else { return }
        let operation = beginOperation(.libraryMutation); defer { endOperation(operation) }
        let access = libraryAccess
        defer { withExtendedLifetime(access) {} }
        do {
            try await engine.library.delete(document)
            do { try await engine.index.remove(ids: [document.id]) }
            catch { message = "Receipt deleted. Rebuild search in Settings if needed." }
            quickLookURL = nil
            await refresh()
        } catch { message = error.localizedDescription }
    }
    func restoreDocument(_ receipt: DeletedReceipt) async {
        guard inboxMayBeMutated, !busy, let engine else { return }
        let operation = beginOperation(.libraryMutation); defer { endOperation(operation) }
        let access = libraryAccess
        defer { withExtendedLifetime(access) {} }
        do {
            try await engine.library.restore(receipt)
            do { _ = try await engine.index.rebuild(from: engine.library) }
            catch { message = "Receipt restored. Rebuild search in Settings to find it." }
            await refresh()
        } catch { message = error.localizedDescription }
    }
    func refresh() async {
        guard inboxMayBeMutated, let engine else { return }
        let token = generation, request = UUID()
        refreshGeneration = request
        do {
            let history = try await engine.library.history()
            let deleted = try await engine.library.deletedDocuments()
            let records = try await engine.library.documents()
            let results = try await engine.index.search(query)
            guard token == generation, request == refreshGeneration, !Task.isCancelled else { return }
            deletedDocuments = deleted
            batches = history
            allDocuments = records
            for i in items.indices {
                if let hash = items[i].review?.hash {
                    items[i].review?.duplicate = allDocuments.first { $0.contentHash == hash }?.relativePath
                }
            }
            persist()
            let activeByID = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            documents = results.filter { activeByID[$0.id] == $0 }
        } catch { if token == generation, request == refreshGeneration, !Task.isCancelled { message = error.localizedDescription } }
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
        guard let engine, !busy else { return }
        let operation = beginOperation(.background); defer { endOperation(operation); activity = "" }
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
        let operation = beginOperation(.background); defer { endOperation(operation) }
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
    static func defaultProEntitlement() -> Bool {
        #if DEBUG || QA
        // The documented mock-store hook is never compiled into Release.
        if argument("-PaperloftStoreMock") == "YES" { return true }
        #endif
        // Commerce integration supplies the cached, verified StoreKit entitlement.
        return false
    }
    var isPro: Bool { proEntitlement() }

    func chooseWatchedFolder() async {
        guard isPro else { watchedStatus = "Watched folders require Pro."; return }
        guard !busy else { watchedStatus = "Wait for the current operation to finish."; return }
        let panel = NSOpenPanel()
        panel.title = "Choose a watched folder"
        panel.message = "New PDF and image documents will be copied into the review inbox. Originals stay here."
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        guard await panel.begin() == .OK, let url = panel.url else { return }
        do {
            let bookmark = try LibraryAccess.bookmark(for: url)
            let access = try LibraryAccess(bookmark: bookmark)
            try await installWatchedFolder(at: access.url, access: access)
            preferences.set(bookmark, forKey: "watchedFolderBookmark")
        } catch is CancellationError { return }
        catch { watchedStatus = error.localizedDescription }
    }

    func restoreWatchedFolder() async {
        guard isPro else { watchedStatus = "Paused: watched folders require Pro."; return }
        do {
            guard let bookmark = preferences.data(forKey: "watchedFolderBookmark") else {
                throw AppIssue("Choose a watched folder to grant access.")
            }
            let access = try LibraryAccess(bookmark: bookmark)
            try await installWatchedFolder(at: access.url, access: access)
        } catch is CancellationError { return }
        catch { watchedEnabled = false; watchedStatus = "Choose the watched folder again to renew access. " + error.localizedDescription }
    }

    func disableWatchedFolder() async {
        let request = UUID(); watchedConfiguration = request; watchedConfigurationPending = false
        guard await stopWatchedFolder(for: request) else { return }
        watchedStatus = "Watched folder is off. Existing inbox documents are unchanged."
    }

    private func stopWatchedFolder(for request: UUID) async -> Bool {
        guard watchedConfiguration == request else { return false }
        watchedEnabled = false; preferences.set(false, forKey: "watchedFolderEnabled")
        watchedGeneration = UUID()
        let task = watchedTask ?? watchedStoppingTask
        watchedStoppingTask = task; watchedTask = nil; task?.cancel()
        await task?.value
        // A newer configuration owns the scanner now; an older continuation cannot clear it.
        guard watchedConfiguration == request else { return false }
        watchedStoppingTask = nil; watchedScanner = nil; watchedAccess = nil
        return true
    }

    /// The production caller supplies a retained security grant. Ordinary path injection supports local coordinator tests.
    func installWatchedFolder(at url: URL, access: LibraryAccess? = nil, schedule: Bool = true,
                              stableInterval: Duration = .seconds(2)) async throws {
        let request = UUID(); watchedConfiguration = request; watchedConfigurationPending = true
        defer { if watchedConfiguration == request { watchedConfigurationPending = false } }
        do { try await awaitStartup() }
        catch {
            guard watchedConfiguration == request else { throw CancellationError() }
            throw error
        }
        guard watchedConfiguration == request else { throw CancellationError() }
        guard isPro else { throw AppIssue("Watched folders require Paperloft Pro.") }
        guard await stopWatchedFolder(for: request) else { throw CancellationError() }
        let physical = url.resolvingSymlinksInPath()
        let folder = support.appendingPathComponent("Watched-State", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = SHA256.hash(data: Data(physical.path.utf8)).map { String(format: "%02x", $0) }.joined()
        let scanner = try WatchedFolderScanner(root: physical, stateURL: folder.appendingPathComponent(name + ".json"), minimumStableInterval: stableInterval)
        guard isPro else { throw AppIssue("Watched folders require Paperloft Pro.") }
        watchedScanner = scanner; watchedAccess = access; watchedFolderURL = physical
        watchedEnabled = true; preferences.set(true, forKey: "watchedFolderEnabled")
        watchedStatus = "Watching for stable documents. Every document needs review."
        let token = watchedGeneration
        if schedule {
            watchedTask = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self, self.watchedGeneration == token else { return }
                    await self.scanWatchedFolder()
                    do { try await Task.sleep(for: .seconds(3)) } catch { return }
                }
            }
        }
    }

    func scanWatchedFolder() async {
        guard watchedEnabled, !watchedScanning, let scanner = watchedScanner else { return }
        guard isPro else { watchedStatus = "Paused: watched folders require Pro."; return }
        guard !busy else { watchedStatus = "Waiting for the current operation to finish."; return }
        watchedScanning = true; defer { watchedScanning = false }
        let token = watchedGeneration, grant = watchedAccess
        defer { withExtendedLifetime(grant) {} }
        do {
            let result = try await scanner.scan()
            guard watchedEnabled, watchedGeneration == token, isPro else { return }
            watchedIssues = result.issues.map { $0.filename.isEmpty ? $0.message : $0.filename + ": " + $0.message }
            var queued = 0
            for candidate in result.candidates {
                guard watchedEnabled, watchedGeneration == token, isPro, !Task.isCancelled else { break }
                if (candidate.filename as NSString).pathExtension.lowercased() == "eml" {
                    watchedIssues.append(candidate.filename + ": Mail import is not connected to watched folders yet. This file remains unacknowledged.")
                    continue
                }
                do {
                    try await queueWatchedCandidate(candidate, generation: token)
                    guard watchedEnabled, watchedGeneration == token, isPro else { break }
                    try await scanner.acknowledge(candidate)
                    queued += 1
                } catch {
                    guard watchedEnabled, watchedGeneration == token else { break }
                    watchedIssues.append(candidate.filename + ": " + error.localizedDescription)
                }
            }
            watchedStatus = watchedIssues.isEmpty ? (queued > 0 ? "Copied \(queued) documents to review. Originals are unchanged." : "Watching for stable documents. Every document needs review.") : "Some documents need attention; they will be checked again."
        } catch {
            guard watchedEnabled, watchedGeneration == token else { return }
            watchedStatus = "Watched folder paused: " + error.localizedDescription
        }
    }

    func queueWatchedCandidate(_ candidate: WatchedFolderScanner.Candidate, generation token: UUID? = nil) async throws {
        try await awaitStartup()
        guard isPro else { throw AppIssue("Watched folders require Paperloft Pro.") }
        guard !busy else { throw AppIssue("Wait for the current operation to finish before importing.") }
        guard watchedEnabled, token == nil || token == watchedGeneration, let root = watchedFolderURL else {
            throw AppIssue("The watched folder was turned off or changed. This document remains pending.")
        }
        guard ["pdf", "png", "jpg", "jpeg", "heic"].contains((candidate.filename as NSString).pathExtension.lowercased()) else {
            throw AppIssue("Watched folders support PDF, PNG, JPEG and HEIC documents.")
        }
        let operation = beginOperation(.background); defer { endOperation(operation) }
        let key = SHA256.hash(data: Data((root.path + "\0" + candidate.filename).utf8)).map { String(format: "%02x", $0) }.joined()
        if watchedDeliveries[key]?.contentHash == candidate.contentHash { return }
        if let pending = items.compactMap(\.watchedDelivery).filter({ $0.sourceKey == key }).max(by: { $0.sequence < $1.sequence }),
           pending.sequence > (watchedDeliveries[key]?.sequence ?? 0), pending.contentHash == candidate.contentHash {
            try await recordWatchedDelivery(pending); return
        }
        guard watchedDeliverySequence < Int64.max else { throw AppIssue("Watched-folder delivery history is full.") }
        let proof = WatchedDeliveryProof(sourceKey: key, contentHash: candidate.contentHash, sequence: watchedDeliverySequence + 1)
        let folder = support.appendingPathComponent("Watched-Imports", isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
        // Copying large immutable inputs never blocks the main actor. Inbox metadata is
        // committed only after returning, using the current items so concurrent edits survive.
        let source = folder.appendingPathComponent(candidate.filename), storage = support
        try await Task.detached(priority: .utility) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Self.writeWatchedData(candidate.data, to: source)
            try Self.synchronizeWatchedDirectory(folder.deletingLastPathComponent())
            try Self.synchronizeWatchedDirectory(storage)
        }.value
        guard watchedEnabled, token == nil || token == watchedGeneration, isPro else { throw CancellationError() }
        let item = InboxItem(id: UUID(), source: source, watchedDelivery: proof)
        let updated = items + [item]
        try Self.writeWatchedData(JSONEncoder().encode(updated), to: support.appendingPathComponent("inbox.json"))
        items = updated; selectedItemID = item.id; selection = "Inbox"
        try await recordWatchedDelivery(proof)
        processWaiting()
    }

    private func recordWatchedDelivery(_ proof: WatchedDeliveryProof) async throws {
        try await recordWatchedDeliveries([proof])
    }

    private func recordWatchedDeliveries(_ proofs: [WatchedDeliveryProof]) async throws {
        // A watched intake and receipt confirmation may overlap. Serialize durable
        // ledger snapshots so the later writer always includes the earlier proof.
        let predecessor = watchedLedgerTask, token = UUID()
        let task = Task { @MainActor in
            if let predecessor { _ = try? await predecessor.value }
            try await self.commitWatchedDeliveries(proofs)
        }
        watchedLedgerTask = task; watchedLedgerToken = token
        defer {
            if watchedLedgerToken == token { watchedLedgerTask = nil; watchedLedgerToken = nil }
        }
        try await task.value
    }

    private func commitWatchedDeliveries(_ proofs: [WatchedDeliveryProof]) async throws {
        var updated = watchedDeliveries
        for proof in proofs {
            guard proof.sourceKey.count == 64, proof.contentHash.count == 64, proof.sequence > 0,
                  (proof.sourceKey + proof.contentHash).utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
                throw AppIssue("A watched-folder delivery record is corrupt. The inbox was preserved.")
            }
            watchedDeliverySequence = max(watchedDeliverySequence, proof.sequence)
            if let existing = updated[proof.sourceKey], existing.sequence == proof.sequence, existing != proof {
                throw AppIssue("Watched-folder delivery records disagree. The inbox was preserved.")
            }
            guard (updated[proof.sourceKey]?.sequence ?? 0) < proof.sequence else { continue }
            guard updated[proof.sourceKey] != nil || updated.count < 25_000 else { throw AppIssue("Watched-folder delivery history is full. No document was acknowledged.") }
            updated[proof.sourceKey] = proof
        }
        guard updated != watchedDeliveries else { return }
        let destination = support.appendingPathComponent("watched-deliveries.json"), snapshot = updated
        try await Task.detached(priority: .utility) {
            let data = try JSONEncoder().encode(snapshot)
            guard data.count <= 8 * 1024 * 1024 else { throw AppIssue("Watched-folder delivery history is full. No document was acknowledged.") }
            try Self.writeWatchedData(data, to: destination)
        }.value
        watchedDeliveries = updated
    }

    private nonisolated static func readWatchedLedger(_ url: URL) throws -> Data {
        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw AppIssue("Watched-folder delivery history could not be read.") }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_size <= 8 * 1024 * 1024 else {
            throw AppIssue("Watched-folder delivery history is invalid or exceeds 8 MB.")
        }
        var data = Data()
        while let chunk = try handle.read(upToCount: min(65_536, 8 * 1024 * 1024 - data.count + 1)), !chunk.isEmpty {
            data.append(chunk)
            guard data.count <= 8 * 1024 * 1024 else { throw AppIssue("Watched-folder delivery history exceeds 8 MB.") }
        }
        return data
    }

    private nonisolated static func synchronizeWatchedDirectory(_ url: URL) throws {
        let descriptor = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw AppIssue("The inbox folder could not be synchronized. Nothing was acknowledged.") }
        defer { close(descriptor) }
        guard fsync(descriptor) == 0 else { throw AppIssue("The inbox folder could not be synchronized. Nothing was acknowledged.") }
    }

    private nonisolated static func writeWatchedData(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
        try synchronizeWatchedDirectory(url.deletingLastPathComponent())
    }

    private func awaitRestoredInbox() async throws {
        do { try await awaitStartup() }
        catch {
            // Choosing another library may repair a revoked library bookmark,
            // but must never discard an inbox that has not decoded successfully.
            guard inboxMayBeMutated else { throw error }
        }
    }

    private func canMutateRestoredInbox() -> Bool {
        guard inboxMayBeMutated else {
            message = "Your saved inbox has not finished opening. Resolve any opening error, then try again."
            return false
        }
        return true
    }

    private func persist() {
        guard canMutateRestoredInbox() else { return }
        do { try JSONEncoder().encode(items).write(to: support.appendingPathComponent("inbox.json"), options: .atomic) }
        catch { message = "The inbox could not be saved. Your originals are unchanged. " + error.localizedDescription }
    }
}
