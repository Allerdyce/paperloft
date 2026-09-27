import AppKit
import ImageIO
import PDFKit
import QuickLook
import PaperloftKit
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Bindable var model: AppModel
    @State private var targeted = false
    private func navigationButton(_ title: String, symbol: String) -> some View {
        Button { model.selection = title } label: {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                if title == "Inbox", model.inboxCount > 0 { Text(model.inboxCount.formatted()).monospacedDigit().foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain).padding(.vertical, 7)
        .listRowBackground(model.selection == title ? Color.accentColor.opacity(0.15) : Color.clear)
        .accessibilityIdentifier("sidebar." + title.lowercased())
    }
    var body: some View {
        NavigationSplitView {
            List {
                navigationButton("Inbox", symbol: "tray")
                navigationButton("Library", symbol: "folder")
                navigationButton("History", symbol: "clock.arrow.circlepath")
            }
            .navigationTitle("Paperloft")
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Label(model.isSampleLibrary ? "Sample library" : "Your library", systemImage: "externaldrive")
                        .font(.caption.weight(.medium))
                    Text(model.libraryURL?.lastPathComponent ?? "Choose a folder to begin")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    if model.isSampleLibrary { Text("Samples do not count toward your monthly limit.").font(.caption2).foregroundStyle(.secondary) }
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(model.selection == "Inbox" ? "A place for your paperwork" : model.selection)
                        .font(.title2.weight(.semibold)).accessibilityIdentifier("content.title")
                    Spacer()
                    if model.busy || model.processing { ProgressView().controlSize(.small).accessibilityLabel("Working") }
                }.padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 16)
                Divider()
                switch model.selection {
                case "Library": BrowseView(model: model)
                case "History": HistoryView(model: model)
                default: InboxView(model: model)
                }
                if !model.activity.isEmpty {
                    Divider()
                    Text(model.activity).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        .padding(.horizontal, 20).padding(.vertical, 8).accessibilityIdentifier("activity.status")
                }
            }
            .navigationTitle(model.selection)
            .toolbar {
                ToolbarItemGroup {
                    Button { Task { await model.importFiles() } } label: { Label("Import", systemImage: "square.and.arrow.down") }
                        .accessibilityIdentifier("toolbar.import").help("Import PDF and image receipts")
                    Button { Task { await model.trySamples() } } label: { Label("Try samples", systemImage: "doc.text") }
                        .accessibilityIdentifier("toolbar.samples").disabled(model.busy)
                    SettingsLink { Label("Settings", systemImage: "gearshape") }
                        .accessibilityIdentifier("toolbar.settings")
                }
            }
        }
        .tint(Color(red: 0.06, green: 0.29, blue: 0.18))
        .frame(minWidth: 960, minHeight: 620)
        .onDrop(of: [.fileURL], isTargeted: $targeted) { acceptDrop($0, model: model) }
        .overlay { if targeted { RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: 3).padding(8).allowsHitTesting(false) } }
        .alert("Paperloft", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("OK") { model.message = nil }.accessibilityIdentifier("message.ok")
        } message: { Text(model.message ?? "") }
        .quickLookPreview($model.quickLookURL)
    }
}

struct InboxView: View {
    @Bindable var model: AppModel
    var body: some View {
        if model.libraryURL == nil {
            VStack(spacing: 18) {
                Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 48)).foregroundStyle(Color.accentColor).accessibilityHidden(true)
                Text("From loose receipts to an organized folder").font(.title2.weight(.medium))
                Text("Choose where your receipts belong. Paperloft reads them on your Mac, then helps you check, name and file them.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 450)
                Button("Choose Library Folder…") { Task { await model.chooseLibrary() } }
                    .buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("onboarding.chooseFolder")
                Button("Try with Five Sample Receipts") { Task { await model.trySamples() } }
                    .accessibilityIdentifier("onboarding.samples")
                Text("No account or API key. Your documents stay on your Mac.").font(.caption).foregroundStyle(.secondary)
            }.padding(36).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.inboxCount == 0 {
            VStack(spacing: 16) {
                Image(systemName: "tray").font(.system(size: 44)).foregroundStyle(.secondary).accessibilityHidden(true)
                Text("Drop receipts here").font(.title2.weight(.medium))
                Text("PDF, PNG, JPEG and HEIC. Copies are filed by default, so your originals stay where they are.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 420)
                HStack {
                    Button("Import Receipts…") { Task { await model.importFiles() } }.accessibilityIdentifier("inbox.import")
                    Button("Try Samples") { Task { await model.trySamples() } }.accessibilityIdentifier("inbox.samples")
                }
                Button("Paste an Image") { model.pasteImage() }.buttonStyle(.link).accessibilityIdentifier("inbox.paste")
            }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HSplitView {
                List(selection: $model.selectedItemID) {
                    ForEach(model.items.filter { $0.status != "aside" }) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.name).lineLimit(2).font(.callout.weight(.medium))
                            Label(status(item), systemImage: item.status == "failed" ? "exclamationmark.triangle" : item.status == "ready" ? "doc.text" : "clock")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4).tag(item.id).accessibilityIdentifier("inbox.item." + item.id.uuidString)
                    }
                }.frame(minWidth: 145, idealWidth: 175, maxWidth: 240).accessibilityIdentifier("inbox.list")
                if let item = model.selectedItem {
                    if item.status == "ready" { ReviewView(model: model, item: item).id(item.id) }
                    else {
                        VStack(spacing: 14) {
                            if item.status == "failed" {
                                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange).accessibilityHidden(true)
                                Text("This document needs attention").font(.headline)
                                Text(item.issue ?? "Import the document again.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                                Button("Set Aside") { model.setAside(item.id) }.accessibilityIdentifier("inbox.setAsideError")
                            } else { ProgressView("Reading your document…").accessibilityIdentifier("inbox.reading") }
                        }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
    }
    private func status(_ item: InboxItem) -> String {
        if item.review?.duplicate != nil { return "Duplicate" }
        switch item.status { case "ready": return "Ready to review"; case "processing": return "Reading…"; case "failed": return "Needs attention"; default: return "Waiting" }
    }
}

struct ReviewView: View {
    @Bindable var model: AppModel
    let item: InboxItem
    @State private var draft: ReceiptDraft
    private enum Field: Hashable { case vendor, date, total, tax, currency }
    @FocusState private var focusedField: Field?
    init(model: AppModel, item: InboxItem) { self.model = model; self.item = item; _draft = State(initialValue: item.draft) }
    private var needsReview: Bool {
        guard let review = item.review else { return true }
        return !ExtractionAssessment(fields: review.fields, parser: ParserBackend.parse(review.text)).canAutoFile
    }
    var body: some View {
        HSplitView {
            DocumentPreview(url: item.source).frame(minWidth: 240, idealWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Document preview").accessibilityIdentifier("review.preview")
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Review document").font(.title3.weight(.semibold))
                    if let duplicate = item.review?.duplicate {
                        Label("Already filed: \(duplicate)", systemImage: "doc.on.doc").font(.callout).foregroundStyle(.orange).accessibilityIdentifier("review.duplicate")
                    } else if item.review?.fields.kind == "not_receipt" {
                        Label("This may not be a receipt. Check it or set it aside.", systemImage: "questionmark.circle").font(.callout).foregroundStyle(.orange).accessibilityIdentifier("review.warning")
                    } else if needsReview {
                        Label("Check the suggested fields before filing.", systemImage: "checkmark.circle").font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("review.warning")
                    }
                }
                Form {
                    TextField("Vendor", text: $draft.vendor).focused($focusedField, equals: .vendor).accessibilityIdentifier("review.vendor")
                    TextField("Date", text: $draft.date, prompt: Text("YYYY-MM-DD")).focused($focusedField, equals: .date).accessibilityIdentifier("review.date")
                    TextField("Total", text: $draft.total).monospacedDigit().focused($focusedField, equals: .total).accessibilityIdentifier("review.total")
                    TextField("Tax (optional)", text: $draft.tax).monospacedDigit().focused($focusedField, equals: .tax).accessibilityIdentifier("review.tax")
                    TextField("Currency", text: $draft.currency).focused($focusedField, equals: .currency).accessibilityIdentifier("review.currency")
                    Picker("Category", selection: $draft.category) {
                        ForEach(Array(Set(model.categories + [draft.category])).sorted(), id: \.self) { Text($0).tag($0) }
                    }.accessibilityIdentifier("review.category")
                    Picker("Document type", selection: $draft.kind) {
                        Text("Receipt").tag(DocumentKind.receipt)
                        Text("Invoice").tag(DocumentKind.invoice)
                        Text("Bill").tag(DocumentKind.bill)
                    }.accessibilityIdentifier("review.kind")
                }
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await model.fileSelected() } }
                if let error = validationMessage {
                    Text(error).font(.caption).foregroundStyle(.orange).accessibilityIdentifier("review.validation")
                }
                Spacer(minLength: 0)
                Text("Files into \(String(draft.date.prefix(4)))/\(draft.category)/")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2).accessibilityIdentifier("review.destination")
                HStack {
                    Button("Set Aside") { model.setAside(item.id) }.accessibilityIdentifier("review.setAside")
                    Spacer()
                    Button(model.mode == .copy ? "File Copy" : "Move & File") { Task { await model.fileSelected() } }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                        .disabled(!model.canFile).accessibilityIdentifier("review.file")
                }
                Text("Return to file · Tab to move between fields").font(.caption2).foregroundStyle(.secondary)
            }.padding(22).frame(minWidth: 290, idealWidth: 340, maxWidth: 400)
        }
        .onAppear { focusedField = .vendor }
        .onChange(of: draft.vendor) { save() }.onChange(of: draft.date) { save() }
        .onChange(of: draft.total) { save() }.onChange(of: draft.tax) { save() }
        .onChange(of: draft.currency) { save() }.onChange(of: draft.category) { save() }
        .onChange(of: draft.kind) { save() }
    }
    private func save() { model.edit(draft, id: item.id) }
    private var validationMessage: String? {
        do { _ = try draft.receipt(); return nil } catch { return error.localizedDescription }
    }
}

struct DocumentPreview: View {
    let url: URL
    @State private var image: NSImage?
    var body: some View {
        Group {
            if url.pathExtension.lowercased() == "pdf" { PDFPreview(url: url) }
            else if let image { Image(nsImage: image).resizable().scaledToFit().padding(16) }
            else { ProgressView("Loading preview…") }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(nsColor: .underPageBackgroundColor))
        .task(id: url) {
            guard url.pathExtension.lowercased() != "pdf" else { return }
            let data = await Task.detached(priority: .utility) {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1800] as CFDictionary) else { return Data?.none }
                return NSBitmapImageRep(cgImage: thumbnail).representation(using: .png, properties: [:])
            }.value
            if let data { image = NSImage(data: data) }
        }
    }
}
struct PDFPreview: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> PDFView { let view = PDFView(); view.autoScales = true; view.displayMode = .singlePageContinuous; return view }
    func updateNSView(_ view: PDFView, context: Context) { if view.document?.documentURL != url { view.document = PDFDocument(url: url) } }
}

struct BrowseView: View {
    @Bindable var model: AppModel
    @State private var selected: UUID?
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                TextField("Search vendor, notes or receipt text", text: $model.search).textFieldStyle(.roundedBorder).accessibilityIdentifier("library.search")
                Picker("Year", selection: $model.yearFilter) {
                    Text("All years").tag("All years")
                    ForEach(Array(Set(model.documents.map { String($0.receipt.date.year) } + (model.yearFilter == "All years" ? [] : [model.yearFilter]))).sorted().reversed(), id: \.self) { Text($0).tag($0) }
                }.frame(width: 145).accessibilityIdentifier("library.year")
            }
            HStack {
                Picker("Category", selection: $model.categoryFilter) {
                    Text("All categories").tag("All categories")
                    ForEach(Array(Set(model.categories + model.documents.map { $0.receipt.category })).sorted(), id: \.self) { Text($0).tag($0) }
                }.accessibilityIdentifier("library.category")
                Picker("Type", selection: $model.kindFilter) {
                    Text("All types").tag("All types")
                    Text("Receipt").tag("receipt"); Text("Invoice").tag("invoice"); Text("Bill").tag("bill")
                }.accessibilityIdentifier("library.kind")
                Spacer()
                Button("Quick Look") { if let document = selectedDocument, let root = model.libraryURL { model.quickLookURL = root.appendingPathComponent(document.relativePath) } }
                    .disabled(selectedDocument == nil).accessibilityIdentifier("library.quickLook")
                Button("Reveal") { model.reveal(selectedDocument) }.disabled(selectedDocument == nil).accessibilityIdentifier("library.reveal")
            }
            Table(model.documents, selection: $selected) {
                TableColumn("Date") { Text($0.receipt.date.formatted).monospacedDigit() }.width(100)
                TableColumn("Vendor") { Text($0.receipt.vendor) }
                TableColumn("Category") { Text($0.receipt.category) }
                TableColumn("Total") { Text(amount($0.receipt)).monospacedDigit() }.width(100)
                TableColumn("Type") { Text($0.receipt.kind.rawValue.capitalized) }.width(75)
            }.accessibilityIdentifier("library.table")
                .overlay { if model.documents.isEmpty { ContentUnavailableView("No matching documents", systemImage: "doc.text.magnifyingglass", description: Text("File a receipt from the Inbox, or adjust your search and filters.")) } }
            Text("\(model.documents.count) documents").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("library.count")
        }.padding(20)
        .onChange(of: model.search) { model.scheduleSearch() }.onChange(of: model.yearFilter) { model.scheduleSearch() }
        .onChange(of: model.categoryFilter) { model.scheduleSearch() }.onChange(of: model.kindFilter) { model.scheduleSearch() }
    }
    private var selectedDocument: FiledDocument? { model.documents.first { $0.id == selected } }
    private func amount(_ receipt: Receipt) -> String { receipt.currency + " " + ((try? Money(minorUnits: receipt.totalMinorUnits, currency: receipt.currency).decimal) ?? "—") }
}

struct HistoryView: View {
    @Bindable var model: AppModel
    var body: some View {
        if model.batches.isEmpty {
            ContentUnavailableView("Your filing history will appear here", systemImage: "clock.arrow.circlepath", description: Text("Every filing can be undone. Your original documents are preserved."))
        } else {
            List(model.batches) { batch in
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: batch.state == .undone ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                        .foregroundStyle(batch.state == .undone ? Color.secondary : Color.accentColor).font(.title2).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(batch.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                        ForEach(batch.documents) { Text($0.relativePath).font(.callout).foregroundStyle(.secondary) }
                        Text(batch.state == .undone ? "Undone" : batch.state == .complete ? "Filed" : "Recovery needs attention").font(.caption).accessibilityIdentifier("history.state." + batch.id.uuidString)
                    }
                    Spacer()
                    Button("Undo") { Task { await model.undo(batch) } }
                        .disabled(model.busy || batch.state == .undone)
                        .accessibilityIdentifier("history.undo." + batch.id.uuidString)
                }.padding(.vertical, 10)
            }.accessibilityIdentifier("history.list")
        }
    }
}

struct PaperloftSettings: View {
    @Bindable var model: AppModel
    @State private var newCategory = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Paperloft Settings").font(.title2.weight(.semibold))
                GroupBox("Library") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(model.libraryURL?.path ?? "No library folder chosen").font(.callout).textSelection(.enabled)
                        HStack {
                            Button("Choose Folder…") { Task { await model.chooseLibrary() } }.accessibilityIdentifier("settings.chooseFolder")
                            Button("Reveal Folder") { model.reveal() }.disabled(model.libraryURL == nil).accessibilityIdentifier("settings.reveal")
                            Button("Rebuild Index") { Task { await model.rebuildIndex() } }.disabled(model.busy || model.libraryURL == nil).accessibilityIdentifier("settings.rebuild")
                        }
                        Button("Start Fresh Sample Library") {
                            for item in model.items where item.status != "aside" { model.setAside(item.id) }
                            Task { do { try await model.newSampleLibrary() } catch { model.message = error.localizedDescription } }
                        }.accessibilityIdentifier("settings.newSampleLibrary")
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Filing") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Original documents", selection: $model.mode) {
                            Text("Copy — keep the original in place").tag(FilingMode.copy)
                            Text("Move — allow restoring the original with Undo").tag(FilingMode.move)
                        }.pickerStyle(.radioGroup).accessibilityIdentifier("settings.filingMode")
                        Text("Moving requires access to the original folder. Recovery copies are kept so Undo can restore your files.").font(.caption).foregroundStyle(.secondary)
                        Button("Renew Original Folder Access…") { Task { _ = await model.grantMoveFolder() } }.accessibilityIdentifier("settings.moveAccess")
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Categories") {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Organizational categories, not tax advice. Changes affect future filing; existing documents stay in their folders.").font(.caption).foregroundStyle(.secondary)
                        ForEach(Array(model.categories.enumerated()), id: \.offset) { index, category in
                            HStack {
                                TextField("Category", text: Binding(get: { model.categories.indices.contains(index) ? model.categories[index] : category }, set: { if model.categories.indices.contains(index) { model.categories[index] = $0; model.saveCategories() } }))
                                    .accessibilityIdentifier("settings.category.\(index)")
                                Button { model.categories.remove(at: index); model.saveCategories() } label: { Image(systemName: "minus.circle") }
                                    .accessibilityLabel("Remove \(category)").accessibilityIdentifier("settings.removeCategory.\(index)")
                            }
                        }
                        HStack {
                            TextField("New category", text: $newCategory).accessibilityIdentifier("settings.newCategory")
                            Button("Add") {
                                let value = newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !value.isEmpty && !model.categories.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) { model.categories.append(value); model.saveCategories(); newCategory = "" }
                            }.disabled(newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("settings.addCategory")
                        }
                    }.padding(8)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Paperloft Receipts").font(.headline)
                    Text("On-device processing. No analytics or tracking.").foregroundStyle(.secondary)
                    Text("© 2026 EvidencePair LLC").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(24)
        }.frame(width: 610, height: 660).accessibilityIdentifier("settings.root")
    }
}
