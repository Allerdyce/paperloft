import AppKit
import ImageIO
import PDFKit
import QuickLook
import PaperloftKit
import SwiftUI
import UniformTypeIdentifiers

private func inboxDisplayStatus(_ item: InboxItem) -> String {
    if item.review?.duplicate != nil { return "Duplicate" }
    if item.status == "failed" { return "Issue" }
    if item.status == "ready" {
        if item.review?.assessment.canAutoFile != true || (try? item.draft.receipt()) == nil { return "Issue" }
        return "Ready"
    }
    return "Processing"
}

struct LibraryView: View {
    @Bindable var model: AppModel
    @State private var targeted = false
    @Environment(\.colorScheme) private var scheme
    private func navigationButton(_ title: String, symbol: String) -> some View {
        Button { model.selection = title } label: {
            HStack {
                Label { Text(title) } icon: { Image(systemName: symbol).foregroundStyle(Color(red: 0.36, green: 0.86, blue: 0.61)) }
                Spacer()
                if title == "Inbox", model.inboxCount > 0 { Text(model.inboxCount.formatted()).monospacedDigit().foregroundStyle(.white) }
            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(.white).padding(.vertical, 10)
        .listRowBackground(model.selection == title ? Color.white.opacity(0.12) : Color.clear)
        .accessibilityIdentifier("sidebar." + title.lowercased())
    }
    var body: some View {
        NavigationSplitView {
            List {
                HStack(spacing: 10) {
                    Image(systemName: "tray.full.fill").font(.title2).foregroundStyle(Color(red: 0.36, green: 0.86, blue: 0.61))
                    Text("Paperloft").font(.system(size: 22, weight: .semibold, design: .serif)).foregroundStyle(.white)
                }.padding(.vertical, 18).accessibilityElement(children: .combine)
                navigationButton("Inbox", symbol: "tray")
                navigationButton("Library", symbol: "folder")
                navigationButton("History", symbol: "clock.arrow.circlepath")
                Section {
                    navigationButton("Settings", symbol: "gearshape")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.025, green: 0.15, blue: 0.12))
            .navigationTitle("Paperloft")
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Label(model.isSampleLibrary ? "Sample library" : "Saved on this Mac", systemImage: "externaldrive")
                        .font(.caption.weight(.medium))
                    Text(model.isSampleLibrary ? "Practice receipts" : (model.libraryURL?.lastPathComponent ?? "Choose a folder to begin"))
                        .font(.callout).foregroundStyle(.white.opacity(0.8)).lineLimit(2)
                    if model.isSampleLibrary { Text("Samples do not count toward your monthly limit.").font(.caption).foregroundStyle(.white.opacity(0.8)) }
                }.foregroundStyle(.white).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color(red: 0.025, green: 0.15, blue: 0.12))
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
            .accessibilityElement(children: .contain).accessibilityLabel("Navigation and library location")
            .background(WindowAccessibility(label: "Navigation and library location", target: .splitPane))
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(model.selection == "Inbox" ? "A place for your paperwork" : model.selection)
                        .font(.system(size: 28, weight: .semibold, design: .serif)).accessibilityIdentifier("content.title")
                    Spacer()
                    if model.selection == "Inbox", model.inboxCount > 0 {
                        let pending = model.items.filter { $0.status == "processing" || $0.status == "waiting" }.count
                        if pending > 0 { ReceiptStatusPill(title: "Processing · \(pending)", symbol: "clock.fill", color: .blue).accessibilityIdentifier("inbox.processingCount") }
                    }
                    if model.selection != "Inbox", model.busy || model.processing { ProgressView().controlSize(.small).accessibilityLabel("Working") }
                }.padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 16)
                Divider()
                switch model.selection {
                case "Library": BrowseView(model: model)
                case "History": HistoryView(model: model)
                case "Settings": PaperloftSettings(model: model, embedded: true)
                default: InboxView(model: model)
                }
                if !model.activity.isEmpty {
                    Divider()
                    Text(model.activity).font(.caption).foregroundStyle(.primary).lineLimit(1)
                        .padding(.horizontal, 20).padding(.vertical, 8).accessibilityIdentifier("activity.status")
                }
            }
            .accessibilityElement(children: .contain).accessibilityLabel(model.selection + " workspace")
            .background(WindowAccessibility(label: model.selection, target: .splitPane))
            .navigationTitle(model.selection)

        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Paperloft workspace")
        .tint(Color.accentColor)
        .frame(minWidth: 960, minHeight: 620)
        .onDrop(of: [.fileURL], isTargeted: $targeted) { acceptDrop($0, model: model) }
        .overlay { if targeted { RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: 3).padding(8).allowsHitTesting(false) } }
        .alert("Paperloft", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("OK") { model.message = nil }.accessibilityIdentifier("message.ok")
        } message: { Text(model.message ?? "") }
        .quickLookPreview($model.quickLookURL)
        .sheet(isPresented: $model.showExport) { ExportView(model: model) }
    }
}

struct InboxView: View {
    @Bindable var model: AppModel
    @State private var filter = "All"
    @State private var pinnedReviewID: UUID?
    @State private var removalSelection: Set<UUID> = []
    private let filters = ["All", "Ready", "Processing", "Duplicates", "Issues"]
    private func matches(_ item: InboxItem, _ choice: String) -> Bool {
        guard item.status != "aside" else { return false }
        switch choice {
        case "Ready": return inboxDisplayStatus(item) == "Ready"
        case "Processing": return inboxDisplayStatus(item) == "Processing"
        case "Duplicates": return item.review?.duplicate != nil
        case "Issues": return inboxDisplayStatus(item) == "Issue"
        default: return true
        }
    }
    private var visibleItems: [InboxItem] { model.items.filter { matches($0, filter) || ($0.status != "aside" && $0.id == pinnedReviewID) } }
    private func syncSelection() {
        if !visibleItems.contains(where: { $0.id == model.selectedItemID }) { model.selectedItemID = visibleItems.first?.id }
        pinnedReviewID = model.items.first(where: { $0.id == model.selectedItemID && $0.status == "ready" })?.id
    }
    private func filterColor(_ value: String) -> Color {
        switch value { case "Ready": return .green; case "Processing": return .blue; case "Duplicates", "Issues": return .orange; default: return .accentColor }
    }
    var body: some View {
        if model.libraryURL == nil {
            VStack(spacing: 18) {
                Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 48)).foregroundStyle(Color.accentColor).accessibilityHidden(true)
                Text("From loose receipts to an organized folder").font(.title2.weight(.medium))
                Text("Choose where your receipts belong. Paperloft reads them on your Mac, then helps you check, name and file them.")
                    .foregroundStyle(.primary).multilineTextAlignment(.center).frame(maxWidth: 450)
                Button("Choose Library Folder…") { Task { await model.chooseLibrary() } }
                    .buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("onboarding.chooseFolder")
                Text("No account or API key. Your documents stay on your Mac.").font(.caption).foregroundStyle(.primary)
            }.padding(36).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.inboxCount == 0 {
            VStack(spacing: 16) {
                Image(systemName: "tray").font(.system(size: 44)).foregroundStyle(.primary).accessibilityHidden(true)
                Text("Drop receipts here").font(.title2.weight(.medium))
                Text("PDF, PNG, JPEG, HEIC and EML email files. Copies are filed by default, so your originals stay where they are.")
                    .foregroundStyle(.primary).multilineTextAlignment(.center).frame(maxWidth: 420)
                HStack {
                    Button("Import Receipts…") { Task { await model.importFiles() } }.accessibilityIdentifier("inbox.import")
                }
                Button("Paste image") { Task { await model.pasteImage() } }.accessibilityIdentifier("inbox.paste")
            }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(filters, id: \.self) { value in
                            Button { removalSelection.removeAll(); pinnedReviewID = nil; model.selectedItemID = nil; filter = value; syncSelection() } label: {
                                HStack(spacing: 5) {
                                    if filter == value { Image(systemName: "checkmark") }
                                    Text(value)
                                    Text(model.items.filter { matches($0, value) }.count.formatted()).monospacedDigit()
                                }.font(.callout.weight(.medium)).padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(filterColor(value).opacity(filter == value ? 0.22 : 0.08), in: Capsule())
                                    .overlay(Capsule().strokeBorder(filter == value ? filterColor(value) : .clear))
                            }.buttonStyle(.plain).accessibilityIdentifier("inbox.filter." + value)
                                .accessibilityAddTraits(filter == value ? [.isSelected] : [])
                        }
                    }.padding(.horizontal, 20).padding(.vertical, 12)
                }
                HStack(spacing: 12) {
                    Button("Paste image", systemImage: "doc.on.clipboard") { Task { await model.pasteImage() } }
                        .accessibilityIdentifier("inbox.paste")
                        .help("Paste a copied image into the Inbox (Shift-Command-V)")
                    Button("Select all") { removalSelection = Set(visibleItems.map(\.id)) }.disabled(visibleItems.isEmpty)
                        .accessibilityIdentifier("inbox.selectAll")
                    if !removalSelection.isEmpty {
                        Text("\(removalSelection.count) selected").font(.caption)
                        Button("Clear selection") { removalSelection.removeAll() }.accessibilityIdentifier("inbox.clearSelection")
                        Button {
                            let ids = removalSelection
                            removalSelection.removeAll()
                            for id in ids { model.setAside(id) }
                        } label: { Text("Remove selected").foregroundStyle(.red) }
                            .disabled(model.busy).accessibilityIdentifier("inbox.removeSelected")
                            .help("Remove selected Inbox entries. Original files stay in place.")
                    }
                    Spacer()
                }.padding(.horizontal, 20).padding(.bottom, 10)
                Divider()
            HSplitView {
                List(selection: $model.selectedItemID) {
                    ForEach(visibleItems) { item in
                        HStack(spacing: 8) {
                            Toggle("Select receipt", isOn: Binding(get: { removalSelection.contains(item.id) }, set: { selected in
                                if selected { removalSelection.insert(item.id) } else { removalSelection.remove(item.id) }
                            })).toggleStyle(.checkbox).labelsHidden()
                                .accessibilityLabel("Select " + item.name)
                                .accessibilityIdentifier("inbox.select." + item.id.uuidString)
                            InboxRow(id: item.id, name: item.name, status: inboxDisplayStatus(item), duplicate: item.review?.duplicate != nil).equatable()
                        }.tag(item.id)
                    }
                    Button { Task { await model.importFiles() } } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill").font(.title3)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Add more receipts…").font(.callout.weight(.semibold))
                                Text("PDF, images or email").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4])))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).foregroundStyle(Color.accentColor)
                    .listRowSeparator(.hidden)
                    .accessibilityIdentifier("inbox.addMore")
                    .accessibilityLabel("Add more receipts")
                    .help("Import more receipts while reviewing your inbox")
                }.frame(minWidth: 175, idealWidth: 200, maxWidth: 250).accessibilityIdentifier("inbox.list").accessibilityLabel("Documents awaiting review")
                    .background(WindowAccessibility(label: "Documents awaiting review", target: .splitPane))
                if let item = visibleItems.first(where: { $0.id == model.selectedItemID }) {
                    if item.status == "ready" { ReviewView(model: model, item: item).id(item.id) }
                    else {
                        VStack(spacing: 14) {
                            if item.status == "failed" {
                                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange).accessibilityHidden(true)
                                Text("This document needs attention").font(.headline)
                                Text(item.issue ?? "Import the document again.").foregroundStyle(.primary).multilineTextAlignment(.center)
                                Button { model.setAside(item.id) } label: { Text("Remove").foregroundStyle(.red) }.help("Remove from Inbox. The original file stays in place.").accessibilityIdentifier("inbox.setAsideError")
                            } else { ProgressView("Reading your document…").accessibilityIdentifier("inbox.reading") }
                        }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    PaperloftEmptyState(title: "No receipts in this view", symbol: "tray", detail: "Choose another status above to see the rest of your inbox.")
                }
            }
            }.onAppear { syncSelection() }
                .onChange(of: filter) { syncSelection() }
                .onChange(of: model.selectedItemID) { syncSelection() }
                .onChange(of: visibleItems.map(\.id)) {
                    removalSelection.formIntersection(Set(visibleItems.map(\.id)))
                    syncSelection()
                }
        }
    }
}

/// Each row depends only on its visible values. Unrelated documents finishing
/// extraction need not rebuild this row's content and automatic-height layout.
struct InboxRow: View, Equatable {
    let id: UUID
    let name: String
    let status: String
    let duplicate: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name).lineLimit(2).font(.callout.weight(.medium))
            ReceiptStatusPill(title: statusLabel, symbol: status == "Issue" ? "exclamationmark.triangle.fill" : status == "Ready" ? "checkmark.circle.fill" : duplicate ? "doc.on.doc.fill" : "clock.fill", color: duplicate || status == "Issue" ? .orange : status == "Ready" ? .green : .blue)
        }.padding(.vertical, 8).accessibilityIdentifier("inbox.item." + id.uuidString)
    }
    private var statusLabel: String {
        if duplicate { return "Duplicate" }
        return status
    }
}

struct ReceiptStatusPill: View {
    let title: String
    let symbol: String
    let color: Color
    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(color.opacity(0.18), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.55), lineWidth: 1))
    }
}

struct ReviewView: View {
    @Bindable var model: AppModel
    let item: InboxItem
    private var sourceCheck: ExtractedFields { item.review?.sourceCheck ?? ParserBackend.parse("") }
    @State private var draft: ReceiptDraft
    @State private var showDatePicker = false
    @State private var showImportDetails = false
    @State private var calendarDate = Date()
    private enum Field: Hashable { case vendor, date, total, tax, currency }
    @FocusState private var focusedField: Field?
    init(model: AppModel, item: InboxItem) { self.model = model; self.item = item; _draft = State(initialValue: item.draft) }
    private func verificationMessage(_ field: String) -> String? {
        guard let review = item.review else { return nil }
        let reasons = review.assessment.reasons
        let crossCheck = reasons.contains(.parserUnavailable) || reasons.contains(.parserDisagreement)
        switch field {
        case "date" where draft.date == review.fields.date:
            if crossCheck && sourceCheck.date == nil { return "Verify date and year against receipt." }
            if crossCheck && sourceCheck.date != review.fields.date { return "Verify date against receipt." }
        case "total" where draft.total == review.fields.total:
            let currency = draft.currency.uppercased()
            let checked = sourceCheck.total.flatMap { try? Money(decimal: $0, currency: currency) }
            let suggested = try? Money(decimal: draft.total, currency: currency)
            if crossCheck && checked == nil { return "Verify total against receipt." }
            if crossCheck && checked != suggested { return "Verify total against receipt." }
            if reasons.contains(.lowConfidence) { return "Verify total and receipt details." }
            if reasons.contains(.parserUnavailable) && review.fields.backend != "system" { return "Verify total against receipt." }
        case "kind":
            if reasons.contains(.classificationUnavailable) || reasons.contains(.notReceipt) || reasons.contains(.invalidKind) { return "Choose the document type shown on the receipt." }
        default: break
        }
        return nil
    }
    private func fieldMessage(_ field: String) -> String? {
        let currency = draft.currency.uppercased().trimmingCharacters(in: .whitespaces)
        let validCurrency = (try? Money(minorUnits: 0, currency: currency)) != nil
        let total = try? Money(decimal: draft.total, currency: validCurrency ? currency : "USD")
        switch field {
        case "vendor":
            return draft.vendor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter the merchant name." : nil
        case "date":
            return (try? ReceiptDate(iso8601: draft.date)) == nil ? "Choose a valid receipt date." : verificationMessage("date")
        case "total":
            return total == nil ? "Enter the total shown on the receipt." : verificationMessage("total")
        case "currency":
            return validCurrency ? nil : "Enter a supported currency code, such as USD."
        case "tax":
            if draft.tax.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
            guard let tax = try? Money(decimal: draft.tax, currency: validCurrency ? currency : "USD") else { return "Enter a valid tax amount, or leave it empty." }
            if let total, tax.minorUnits > total.minorUnits { return "Tax cannot exceed the total." }
            if item.review?.fields.taxNeedsReview == true && draft.tax == item.review?.fields.tax { return "Verify tax against receipt." }
            return nil
        case "category":
            if draft.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Choose a category." }
            if item.review?.assessment.reasons.contains(.missingCategory) == true && draft.category == (item.review?.fields.category ?? "Other expenses") { return "Choose a category." }
            return nil
        default: return verificationMessage(field)
        }
    }
    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Receipt preview").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Expand preview", systemImage: "arrow.up.left.and.arrow.down.right") { model.quickLookURL = item.source }
                        .accessibilityIdentifier("review.expandPreview")
                }.padding(10)
                DocumentPreview(url: item.source)
                    .overlay {
                        Button { model.quickLookURL = item.source } label: { Color.clear.contentShape(Rectangle()) }
                            .buttonStyle(.plain).accessibilityLabel("Open full-size receipt preview")
                            .accessibilityIdentifier("review.openPreview")
                    }
                    .accessibilityElement(children: .contain).accessibilityLabel("Document preview").accessibilityIdentifier("review.preview")
            }.frame(minWidth: 240, idealWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                .background(WindowAccessibility(label: "Document preview", target: .splitPane))
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Review document").font(.title3.weight(.semibold))
                    if let duplicate = item.review?.duplicate {
                        Label("Already filed: \(duplicate)", systemImage: "doc.on.doc").font(.callout).foregroundStyle(.orange).accessibilityIdentifier("review.duplicate")
                    }
                }
                Form {
                    TextField("Vendor", text: $draft.vendor).focused($focusedField, equals: .vendor).accessibilityIdentifier("review.vendor").modifier(ReviewHighlight(message: fieldMessage("vendor")))
                    HStack {
                        TextField("Date", text: $draft.date, prompt: Text("YYYY-MM-DD")).focused($focusedField, equals: .date).accessibilityIdentifier("review.date")
                        Button {
                            let formatter = DateFormatter()
                            formatter.locale = Locale(identifier: "en_US_POSIX")
                            formatter.dateFormat = "yyyy-MM-dd"
                            formatter.isLenient = false
                            calendarDate = formatter.date(from: draft.date) ?? Date()
                            showDatePicker = true
                        } label: { Image(systemName: "calendar") }
                        .accessibilityLabel("Choose receipt date").accessibilityIdentifier("review.chooseDate")
                        .popover(isPresented: $showDatePicker, arrowEdge: .leading) {
                            VStack(alignment: .leading, spacing: 12) {
                                DatePicker("Receipt date", selection: $calendarDate, displayedComponents: .date)
                                    .datePickerStyle(.graphical).labelsHidden().fixedSize()
                                HStack {
                                    Button("Cancel") { showDatePicker = false }
                                    Spacer()
                                    Button("Use date") {
                                    let formatter = DateFormatter()
                                    formatter.locale = Locale(identifier: "en_US_POSIX")
                                    formatter.dateFormat = "yyyy-MM-dd"
                                    draft.date = formatter.string(from: calendarDate)
                                    showDatePicker = false
                                    }.buttonStyle(.borderedProminent).accessibilityIdentifier("review.useDate")
                                }
                            }.padding(12).fixedSize()
                        }
                    }.modifier(ReviewHighlight(message: fieldMessage("date")))
                    TextField("Total", text: $draft.total).monospacedDigit().focused($focusedField, equals: .total).accessibilityIdentifier("review.total").modifier(ReviewHighlight(message: fieldMessage("total")))
                    TextField("Tax (optional)", text: $draft.tax).monospacedDigit().focused($focusedField, equals: .tax).accessibilityIdentifier("review.tax").modifier(ReviewHighlight(message: fieldMessage("tax")))
                    TextField("Currency", text: $draft.currency).focused($focusedField, equals: .currency).accessibilityIdentifier("review.currency").modifier(ReviewHighlight(message: fieldMessage("currency")))
                    AccessiblePicker(label: "Category", identifier: "review.category", choices: Array(Set(model.categories + [draft.category])).sorted(), selection: $draft.category)
                        .modifier(ReviewHighlight(message: fieldMessage("category")))
                    AccessiblePicker(label: "Document type", identifier: "review.kind", choices: ["Receipt", "Invoice", "Bill"], selection: Binding(get: { draft.kind.rawValue.capitalized }, set: { draft.kind = DocumentKind(rawValue: $0.lowercased()) ?? .receipt }))
                        .modifier(ReviewHighlight(message: fieldMessage("kind")))
                }
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await model.fileSelected() } }
                if let error = model.templateError {
                    Text(error).font(.caption).foregroundStyle(.orange).accessibilityIdentifier("review.validation")
                }
                Spacer(minLength: 0)
                Text("Files into \(String(draft.date.prefix(4)))/\(draft.category)/")
                    .font(.caption).foregroundStyle(.primary).lineLimit(2).accessibilityIdentifier("review.destination")
                Text(model.mode == .copy ? "Saves a copy to your library. Your original stays in place." : "Moves the original to your library. You can undo this in History.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button { model.setAside(item.id) } label: { Text("Remove").foregroundStyle(.red) }.help("Remove from Inbox. The original file stays in place.").accessibilityIdentifier("review.setAside")
                    Spacer()
                    Button("Confirm") { Task { await model.fileSelected() } }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                        .disabled(!model.canFile).accessibilityIdentifier("review.file")
                }
                if let reason = model.filingUnavailableReason, ["vendor", "date", "total", "tax", "currency", "category"].allSatisfy({ fieldMessage($0) == nil }) {
                    Text(reason).font(.caption).foregroundStyle(.primary)
                        .accessibilityIdentifier("review.filingUnavailableReason")
                }
                Text("Return to confirm · Tab to move between fields").font(.caption).foregroundStyle(.primary)
                if let notices = item.importNotices, !notices.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Button("Import details", systemImage: showImportDetails ? "chevron.down" : "chevron.right") { showImportDetails.toggle() }
                            .buttonStyle(.plain).accessibilityIdentifier("review.importDetailsButton")
                        if showImportDetails { Text(notices.joined(separator: "\n")).font(.caption).textSelection(.enabled) }
                    }.font(.caption).accessibilityElement(children: .contain).accessibilityIdentifier("review.importNotices")
                }
            }.padding(22).frame(minWidth: 290, idealWidth: 340, maxWidth: 400)
                .background(WindowAccessibility(label: "Receipt fields and filing actions", target: .splitPane))
        }
        .background(WindowAccessibility(label: "Receipt review", target: .splitPane))
        .onAppear { focusedField = .vendor }
        .onChange(of: draft.vendor) { save() }.onChange(of: draft.date) { save() }
        .onChange(of: draft.total) { save() }.onChange(of: draft.tax) { save() }
        .onChange(of: draft.currency) { save() }.onChange(of: draft.category) { save() }
        .onChange(of: draft.kind) { save() }
    }
    private func save() { model.edit(draft, id: item.id) }

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
    func makeNSView(context: Context) -> AccessiblePDFView { let view = AccessiblePDFView(); view.autoScales = true; view.displayMode = .singlePageContinuous; return view }
    func updateNSView(_ view: AccessiblePDFView, context: Context) {
        if view.document?.documentURL != url { view.document = PDFDocument(url: url) }
        view.setAccessibilityLabel("Document preview")
        view.documentView?.setAccessibilityLabel("PDF document pages")
        view.labelDocumentContent()
    }
}

final class AccessiblePDFView: PDFView {
    override func layout() { super.layout(); labelDocumentContent() }
    func labelDocumentContent() {
        var seen = Set<ObjectIdentifier>()
        func visit(_ object: Any) {
            guard let element = object as? any NSAccessibilityProtocol,
                  seen.insert(ObjectIdentifier(element)).inserted else { return }
            if element.accessibilityRole() == .pageRole {
                if (element.accessibilityLabel() ?? "").isEmpty {
                    // The page role is announced separately; retain all native text descendants.
                    element.setAccessibilityLabel("Receipt document content")
                }
                return
            }
            for child in element.accessibilityChildren() ?? [] { visit(child) }
        }
        visit(self)
    }
}

struct BrowseView: View {
    @Bindable var model: AppModel
    @State private var selected: UUID?
    @State private var pendingDelete: FiledDocument?
    @State private var showDeleted = false
    @Environment(\.colorScheme) private var scheme
    private var canvas: Color { scheme == .dark ? Color(red: 0.12, green: 0.135, blue: 0.13) : Color(red: 0.985, green: 0.98, blue: 0.965) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search your receipts", text: $model.search)
                    .textFieldStyle(.plain).font(.body)
                    .accessibilityIdentifier("library.search").accessibilityLabel("Search library")
                if !model.search.isEmpty {
                    Button { model.search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("Clear search")
                }
            }.padding(16).background(scheme == .dark ? Color.white.opacity(0.04) : .white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.2)))
            HStack(spacing: 10) {
                LibraryFilterChip(title: "Type", identifier: "library.kind", choices: ["All types", "Receipt", "Invoice", "Bill"], selection: Binding(get: { model.kindFilter == "All types" ? model.kindFilter : model.kindFilter.capitalized }, set: { model.kindFilter = $0 == "All types" ? $0 : $0.lowercased() }))
                LibraryFilterChip(title: "Category", identifier: "library.category", choices: ["All categories"] + Array(Set(model.categories + model.allDocuments.map { $0.receipt.category })).sorted(), selection: $model.categoryFilter)
                LibraryFilterChip(title: "Year", identifier: "library.year", choices: ["All years"] + Array(Set(model.allDocuments.map { String($0.receipt.date.year) })).sorted().reversed(), selection: $model.yearFilter)
                Spacer(minLength: 8)
                Button("Tax & Accountant Export…", systemImage: "square.and.arrow.up") { model.beginExport() }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                    .disabled(model.libraryURL == nil || model.busy).accessibilityIdentifier("library.export")
            }
            HStack(spacing: 16) {
                Text("Filed receipts").font(.headline)
                Spacer()
                Button("Open Receipt") { open(selectedDocument) }.disabled(selectedDocument == nil).accessibilityIdentifier("library.quickLook")
                Button("Reveal in Finder") { model.reveal(selectedDocument) }.disabled(selectedDocument == nil).accessibilityIdentifier("library.reveal")
                Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = selectedDocument }
                    .disabled(selectedDocument == nil || model.busy).accessibilityIdentifier("library.delete")
                Button("Recently Deleted") { showDeleted = true }.accessibilityIdentifier("library.deleted")
            }.buttonStyle(.borderless).font(.callout).padding(.top, 8)
            VStack(spacing: 4) {
                HStack(spacing: 12) {
                    Text("Receipt").frame(width: 42, alignment: .leading)
                    Text("Date").frame(width: 86, alignment: .leading)
                    Text("Merchant").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Category").frame(width: 110, alignment: .leading)
                    Text("Total").frame(width: 108, alignment: .trailing)
                    Text("Action").frame(width: 70)
                }.font(.caption.weight(.medium)).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.bottom, 6)
                List(selection: $selected) {
                    ForEach(model.documents) { document in
                        HStack(spacing: 12) {
                            LibraryReceiptIcon(category: document.receipt.category).frame(width: 42)
                            Text(document.receipt.date.formatted).font(.callout).monospacedDigit().frame(width: 86, alignment: .leading)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(document.receipt.vendor).font(.body.weight(.medium)).lineLimit(2)
                                Text(document.receipt.kind.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Text(document.receipt.category).font(.callout).lineLimit(2).frame(width: 110, alignment: .leading)
                            Text(amount(document.receipt)).font(.body.weight(.medium)).monospacedDigit().frame(width: 108, alignment: .trailing)
                            Button("View") { open(document) }.buttonStyle(.bordered).buttonBorderShape(.capsule)
                                .frame(width: 70).accessibilityLabel("View receipt from " + document.receipt.vendor)
                                .accessibilityIdentifier("library.view." + document.id.uuidString)
                        }.padding(.horizontal, 16).padding(.vertical, 16)
                            .frame(minHeight: 76)
                            .background(scheme == .dark ? Color.white.opacity(0.055) : Color(red: 0.952, green: 0.938, blue: 0.916), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected == document.id ? Color.accentColor.opacity(0.65) : .clear))
                            .background(LibrarySelectionStyle())
                            .contentShape(Rectangle()).tag(document.id)
                            .listRowSeparator(.hidden).listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }
                }.listStyle(.plain).scrollContentBackground(.hidden)
            .contextMenu(forSelectionType: UUID.self) { ids in
                if let id = ids.first, let document = model.documents.first(where: { $0.id == id }) {
                    Button("Open Receipt") { open(document) }
                    Button("Reveal in Finder") { model.reveal(document) }
                    Divider()
                    Button("Delete", role: .destructive) { pendingDelete = document }.disabled(model.busy)
                }
            } primaryAction: { ids in
                if let id = ids.first { open(model.documents.first { $0.id == id }) }
            }
            .onDeleteCommand { if !model.busy { pendingDelete = selectedDocument } }
            .accessibilityIdentifier("library.table").accessibilityLabel("Filed documents")
                .overlay { if model.documents.isEmpty { PaperloftEmptyState(title: "No matching documents", symbol: "doc.text.magnifyingglass", detail: "File a receipt from the Inbox, or adjust your search and filters.") } }
            }
            Text("\(model.documents.count) documents").font(.caption).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("library.count")
            Text("Double-click a receipt to open it. Deleted receipts can be restored from Recently Deleted.")
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(24).background(canvas)
        .confirmationDialog("Delete this receipt?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Delete Receipt", role: .destructive) {
                if let document = pendingDelete { Task { await model.deleteDocument(document) } }
                pendingDelete = nil
            }.accessibilityIdentifier("library.confirmDelete")
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { Text("It will leave your library and future exports. You can restore it from Recently Deleted; external originals are preserved.") }
        .sheet(isPresented: $showDeleted) { RecentlyDeletedView(model: model) }
        .onChange(of: model.search) { model.scheduleSearch() }.onChange(of: model.yearFilter) { model.scheduleSearch() }
        .onChange(of: model.categoryFilter) { model.scheduleSearch() }.onChange(of: model.kindFilter) { model.scheduleSearch() }
    }
    private func open(_ document: FiledDocument?) {
        guard let document, let root = model.libraryURL else { return }
        model.quickLookURL = root.appendingPathComponent(document.relativePath)
    }
    private var selectedDocument: FiledDocument? { model.documents.first { $0.id == selected } }
    private func amount(_ receipt: Receipt) -> String { receipt.currency + " " + ((try? Money(minorUnits: receipt.totalMinorUnits, currency: receipt.currency).decimal) ?? "—") }
}

struct LibraryFilterChip: View {
    let title: String
    let identifier: String
    let choices: [String]
    @Binding var selection: String
    var body: some View {
        Menu {
            Picker(title, selection: $selection) { ForEach(choices, id: \.self) { Text($0).tag($0) } }.pickerStyle(.inline)
        } label: {
            Text(selection.hasPrefix("All ") ? title + ": All" : selection).font(.callout.weight(.medium)).lineLimit(1).truncationMode(.tail)
        }
        .menuStyle(.borderlessButton).frame(maxWidth: title == "Category" ? 150 : 105).padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.secondary.opacity(0.12), in: Capsule())
        .accessibilityLabel(title).accessibilityValue(selection).accessibilityIdentifier(identifier)
    }
}

struct LibraryReceiptIcon: View {
    let category: String
    private var color: Color {
        switch category.lowercased() {
        case "meals": return .orange
        case "travel": return .blue
        case "software": return .purple
        case "utilities": return .teal
        default: return Color.accentColor
        }
    }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(color).frame(width: 34, height: 42)
            Image(systemName: "doc.text.fill").font(.system(size: 29)).foregroundStyle(.white).offset(x: 5, y: 3)
        }.accessibilityHidden(true)
    }
}

struct RecentlyDeletedView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recently Deleted").font(.title2.weight(.semibold))
            Text("These receipts are excluded from your library and exports. Restore them whenever you need them.")
                .foregroundStyle(.secondary)
            if model.deletedDocuments.isEmpty {
                ContentUnavailableView("No deleted receipts", systemImage: "trash")
            } else {
                List(model.deletedDocuments) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.document.receipt.vendor).font(.headline)
                            Text("Deleted " + item.deletedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                        }
                        Spacer()
                        Button("Restore") { Task { await model.restoreDocument(item) } }
                            .disabled(model.busy).accessibilityIdentifier("deleted.restore." + item.id.uuidString)
                    }.padding(.vertical, 6)
                }.accessibilityIdentifier("deleted.list")
            }
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction).accessibilityIdentifier("deleted.done") }
        }.padding(24).frame(width: 560, height: 380)
    }
}

struct HistoryView: View {
    @Bindable var model: AppModel
    var body: some View {
        if model.batches.isEmpty {
            PaperloftEmptyState(title: "Your filing history will appear here", symbol: "clock.arrow.circlepath", detail: "Every filing can be undone. Your original documents are preserved.")
        } else {
            List(model.batches) { batch in
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: batch.state == .undone ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                        .foregroundStyle(batch.state == .undone ? Color.secondary : Color.accentColor).font(.title2).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(batch.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                        ForEach(batch.documents) { Text($0.relativePath).font(.callout).foregroundStyle(.primary) }
                        Text(batch.state == .undone ? "Undone" : batch.state == .complete ? "Filed" : "Recovery needs attention").font(.caption).accessibilityIdentifier("history.state." + batch.id.uuidString)
                    }
                    Spacer()
                    Button("Undo") { Task { await model.undo(batch) } }
                        .disabled(model.busy || batch.state == .undone)
                        .accessibilityIdentifier("history.undo." + batch.id.uuidString)
                }.padding(.vertical, 10)
            }.accessibilityIdentifier("history.list").accessibilityLabel("Filing history")
        }
    }
}

struct PaperloftSettings: View {
    @Bindable var model: AppModel
    var embedded = false
    @State private var newCategory = ""
    @AppStorage("appearance") private var appearance = "System"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !embedded { Text("Paperloft Settings").font(.title2.weight(.semibold)) }
                GroupBox("Appearance") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Theme", selection: $appearance) {
                            Text("System").tag("System")
                            Text("Light").tag("Light")
                            Text("Dark").tag("Dark")
                        }.pickerStyle(.segmented).accessibilityIdentifier("settings.appearance")
                        Text("System follows your Mac’s appearance. Light and Dark apply only to Paperloft.").font(.caption)
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Library") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(model.libraryURL?.path ?? "No library folder chosen").font(.callout).textSelection(.enabled)
                        HStack {
                            Button("Choose Folder…") { Task { await model.chooseLibrary() } }.disabled(model.busy).accessibilityIdentifier("settings.chooseFolder")
                            Button("Reveal Folder") { model.reveal() }.disabled(model.libraryURL == nil).accessibilityIdentifier("settings.reveal")
                            Button("Rebuild Index") { Task { await model.rebuildIndex() } }.disabled(model.busy || model.libraryURL == nil).accessibilityIdentifier("settings.rebuild")
                        }
                        #if DEBUG
                        Button("Start Fresh Sample Library") {
                            Task { do { try await model.newSampleLibrary(discardInbox: true) } catch { model.message = error.localizedDescription } }
                        }.disabled(model.busy).accessibilityIdentifier("settings.newSampleLibrary")
                        #endif
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Watched folder · Pro") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(model.watchedFolderURL?.path ?? "No watched folder chosen").font(.callout).textSelection(.enabled)
                        Text(model.watchedStatus).accessibilityIdentifier("settings.watchedStatus")
                        HStack {
                            Button("Choose Watched Folder…") { Task { await model.chooseWatchedFolder() } }
                                .disabled(model.busy || !model.isPro).accessibilityIdentifier("settings.chooseWatchedFolder")
                            if model.watchedEnabled {
                                Button("Turn Off") { Task { await model.disableWatchedFolder() } }.accessibilityIdentifier("settings.disableWatchedFolder")
                            } else {
                                Button("Turn On") { Task { await model.restoreWatchedFolder() } }
                                    .disabled(!model.isPro).accessibilityIdentifier("settings.enableWatchedFolder")
                            }
                        }
                        Text("PDFs and images are copied to the inbox for review. Originals are never moved. Mail files remain pending until watched Mail import is available.").font(.caption)
                        ForEach(Array(model.watchedIssues.enumerated()), id: \.offset) { _, issue in Text(issue).font(.caption).foregroundStyle(.orange) }
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Filing") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Original documents", selection: $model.mode) {
                            Text("Copy — keep the original in place").tag(FilingMode.copy)
                            Text("Move — allow restoring the original with Undo").tag(FilingMode.move)
                        }.pickerStyle(.radioGroup).accessibilityIdentifier("settings.filingMode")
                        TextField("Filename template", text: $model.filenameTemplate).accessibilityIdentifier("settings.filenameTemplate")
                        Text("Keep {date}, {vendor} and {total}; optionally add {currency}, {category} or {kind}.").font(.caption).foregroundStyle(.primary)
                        if let error = model.templateError { Text(error).font(.caption).foregroundStyle(.orange).accessibilityIdentifier("settings.templateError") }
                        Text("Moving requires access to the original folder. Recovery copies are kept so Undo can restore your files.").font(.caption).foregroundStyle(.primary)
                        Button("Renew Original Folder Access…") { Task { _ = await model.grantMoveFolder() } }.accessibilityIdentifier("settings.moveAccess")
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Categories") {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Organizational categories, not tax advice. Changes affect future filing; existing documents stay in their folders.").font(.caption).foregroundStyle(.primary)
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
                    Text("On-device processing. No analytics or tracking.").foregroundStyle(.primary)
                    Text("© 2026 EvidencePair LLC").font(.caption).foregroundStyle(.primary)
                }
            }.padding(24)
        }.frame(width: embedded ? nil : 610, height: embedded ? nil : 660)
            .frame(maxWidth: embedded ? .infinity : nil, maxHeight: embedded ? .infinity : nil)
            .accessibilityIdentifier("settings.root")
    }
}

private struct ReviewHighlight: ViewModifier {
    let message: String?
    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content.padding(3)
                .background {
                    if message != nil { RoundedRectangle(cornerRadius: 5).fill(Color.orange.opacity(0.09)) }
                }
                .overlay {
                    if message != nil { RoundedRectangle(cornerRadius: 5).stroke(Color.orange, lineWidth: 1) }
                }
            if let message {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct PaperloftEmptyState: View {
    let title: String
    let symbol: String
    let detail: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 36)).foregroundStyle(Color.accentColor).accessibilityHidden(true)
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(.primary)
            Text(detail).font(.body).foregroundStyle(.primary)
        }.multilineTextAlignment(.center).padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}

// Keep native list selection and keyboard behavior, but draw our border only.
private struct LibrarySelectionStyle: NSViewRepresentable {
    final class Marker: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                var ancestor = self?.superview
                while let view = ancestor {
                    if let table = view as? NSTableView { table.selectionHighlightStyle = .none; break }
                    ancestor = view.superview
                }
            }
        }
    }
    func makeNSView(context: Context) -> Marker { Marker() }
    func updateNSView(_ nsView: Marker, context: Context) {}
}
