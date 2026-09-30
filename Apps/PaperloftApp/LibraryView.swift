import AppKit
import ImageIO
import PDFKit
import QuickLook
import PaperloftKit
import SwiftUI
import UniformTypeIdentifiers

private func inboxDisplayStatus(_ item: InboxItem) -> String {
    if item.review?.duplicate != nil || item.duplicateMailDeliveryID != nil { return "Duplicate" }
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
                    if model.isSampleLibrary { Text("Choose your own folder in Settings before adding real receipts.").font(.caption).foregroundStyle(.white.opacity(0.8)) }
                }.foregroundStyle(.white).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color(red: 0.025, green: 0.15, blue: 0.12))
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
            .accessibilityElement(children: .contain).accessibilityLabel("Navigation and library location")
            .background(WindowAccessibility(label: "Navigation and library location", target: .splitPane))
            .receiptDeviceImport(model: model)
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
            .receiptDeviceImport(model: model)

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
        case "Duplicates": return item.review?.duplicate != nil || item.duplicateMailDeliveryID != nil
        case "Issues": return inboxDisplayStatus(item) == "Issue"
        default: return true
        }
    }
    private var visibleItems: [InboxItem] { model.items.filter { matches($0, filter) || ($0.status != "aside" && $0.id == pinnedReviewID) } }
    private func syncSelection() {
        if !visibleItems.contains(where: { $0.id == model.selectedItemID }) { model.selectedItemID = visibleItems.first?.id }
        pinnedReviewID = model.items.first(where: { $0.id == model.selectedItemID && $0.status == "ready" })?.id
    }
    private func intakeCard(title: String, symbol: String, detail: String, action: String, identifier: String, perform: @escaping () async -> Void) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: symbol).font(.system(size: 26, weight: .medium)).frame(height: 32)
                .foregroundStyle(Color.accentColor).accessibilityHidden(true)
            Text(title).font(.title2.weight(.semibold))
            Text(detail).font(.body).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 4)
            Button(action) { Task { await perform() } }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .accessibilityIdentifier(identifier)
        }.padding(24).frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            .background(Color.accentColor.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.accentColor.opacity(0.2)))
            .accessibilityElement(children: .contain)
    }
    private func revealPastedImage() {
        guard let id = model.pastedItemID, model.items.contains(where: { $0.id == id && $0.status != "aside" }) else { return }
        filter = "All"
        removalSelection.removeAll()
        pinnedReviewID = id
        model.selectedItemID = id
    }
    private func filterColor(_ value: String) -> Color {
        switch value { case "Ready": return .green; case "Processing": return .blue; case "Duplicates", "Issues": return .orange; default: return .accentColor }
    }
    var body: some View {
        if model.mailRecoveryNeeded {
            VStack(spacing: 16) {
                Label("Receipt intake needs recovery", systemImage: "exclamationmark.triangle").font(.title2)
                Text(model.message ?? "Your saved inbox and originals are preserved. Finish recovery before making further changes.").multilineTextAlignment(.center)
                Button("Retry recovery") { Task { await model.retryMailRecovery() } }
                    .buttonStyle(.borderedProminent).accessibilityIdentifier("mail.retryRecovery")
            }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.libraryURL == nil {
            VStack(spacing: 18) {
                Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 48)).foregroundStyle(Color.accentColor).accessibilityHidden(true)
                Text("From loose receipts to an organized folder").font(.title2.weight(.medium))
                Text("Choose where your receipts belong. Paperloft reads them on your Mac, then helps you check, name and file them.")
                    .foregroundStyle(.primary).multilineTextAlignment(.center).frame(maxWidth: 450)
                Button("Choose Library Folder…") { Task { await model.chooseLibrary() } }
                    .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("onboarding.chooseFolder")
                // SPEC 6.3: five bundled synthetic receipts, filed from a separate sample library.
                // Only before a first library: samples must never replace a saved but unavailable library.
                if !model.hasSavedLibrary {
                    Button("Try with Samples") { Task { await model.trySamples() } }
                        .controlSize(.large).disabled(model.busy).accessibilityIdentifier("onboarding.trySamples")
                    Text("Samples are made-up receipts in a practice library. Choose your own folder before adding real receipts.")
                        .font(.callout).foregroundStyle(.primary)
                }
                Text("No account needed. Your documents stay on your Mac.").font(.callout).foregroundStyle(.primary)
            }.padding(36).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.inboxCount == 0 {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bring your receipts together").font(.system(size: 25, weight: .semibold, design: .serif))
                        Text("Choose how to add your first receipt.").foregroundStyle(.primary)
                    }
                    HStack(alignment: .top, spacing: 20) {
                        intakeCard(title: "Import", symbol: "square.and.arrow.down", detail: "Add receipt files from your Mac. Choose PDFs, images or saved emails.", action: "Choose files…", identifier: "inbox.import") { await model.importFiles() }
                        intakeCard(title: "Paste", symbol: "doc.on.clipboard", detail: "Paste a copied receipt image or screenshot into your Inbox.", action: "Paste image", identifier: "inbox.paste") { await model.pasteImage() }
                    }
                    Label("You can also drag receipt files anywhere into this Inbox.", systemImage: "arrow.down.doc")
                        .font(.callout).foregroundStyle(.primary)
                    Text("PDF, PNG, JPEG, HEIC and EML · Originals stay in place when you confirm a copy.")
                        .font(.callout).foregroundStyle(.primary)
                }.frame(maxWidth: 720, alignment: .leading).padding(36)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } else {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(filters, id: \.self) { value in
                            Button { removalSelection.removeAll(); pinnedReviewID = nil; model.selectedItemID = nil; filter = value; syncSelection() } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark").opacity(filter == value ? 1 : 0).accessibilityHidden(true)
                                    Text(value)
                                    Text(model.items.filter { matches($0, value) }.count.formatted()).monospacedDigit()
                                }.font(.callout.weight(.medium)).padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(filterColor(value).opacity(filter == value ? 0.22 : 0.08), in: Capsule())
                                    .overlay(Capsule().strokeBorder(filter == value ? filterColor(value) : .clear))
                            }.buttonStyle(.plain).accessibilityIdentifier("inbox.filter." + value)
                                .accessibilityAddTraits(filter == value ? [.isSelected] : [])
                        }
                    }.padding(.vertical, 12)
                }.padding(.horizontal, 20)
                HStack(spacing: 12) {
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
                        if let pastedID = model.pastedItemID, model.selectedItemID == pastedID,
                           model.items.contains(where: { $0.id == pastedID && $0.status != "aside" }) {
                            Label("Image added", systemImage: "checkmark.circle.fill")
                                .font(.caption).foregroundStyle(Color.accentColor)
                                .accessibilityIdentifier("inbox.pasteFeedback")
                        }
                }.padding(.horizontal, 20).padding(.bottom, 10)
                Divider()
            HSplitView {
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        List(selection: $model.selectedItemID) {
                    ForEach(visibleItems) { item in
                        HStack(spacing: 8) {
                            Toggle("Select receipt", isOn: Binding(get: { removalSelection.contains(item.id) }, set: { selected in
                                if selected { removalSelection.insert(item.id) } else { removalSelection.remove(item.id) }
                            })).toggleStyle(.checkbox).labelsHidden()
                                .accessibilityLabel("Select " + item.name)
                                .accessibilityIdentifier("inbox.select." + item.id.uuidString)
                            InboxRow(id: item.id, name: item.name, sourceLabel: item.intakeSource, status: inboxDisplayStatus(item), duplicate: item.review?.duplicate != nil || item.duplicateMailDeliveryID != nil).equatable()
                        }.tag(item.id).id(item.id)
                    }
                        }.accessibilityIdentifier("inbox.list").accessibilityLabel("Documents awaiting review")
                            .onChange(of: model.selectedItemID) {
                                if let id = model.selectedItemID { proxy.scrollTo(id, anchor: .center) }
                            }
                            .onChange(of: model.pastedItemID) {
                                revealPastedImage()
                                if let id = model.pastedItemID {
                                    Task { @MainActor in
                                        await Task.yield()
                                        if model.selectedItemID == id { proxy.scrollTo(id, anchor: .center) }
                                    }
                                }
                            }
                            .onChange(of: visibleItems.map(\.id)) {
                                if let id = model.selectedItemID { proxy.scrollTo(id, anchor: .center) }
                            }
                            .onAppear {
                                if let id = model.selectedItemID { proxy.scrollTo(id, anchor: .center) }
                            }
                    }
                }.frame(minWidth: 175, idealWidth: 220, maxWidth: 270)
                    .background(WindowAccessibility(label: "Documents awaiting review", target: .splitPane))
                if let item = visibleItems.first(where: { $0.id == model.selectedItemID }) {
                    if item.status == "ready" { ReviewView(model: model, item: item).id(item.id) }
                    else {
                        VStack(spacing: 14) {
                            if item.status == "failed" || item.status == "duplicate" {
                                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange).accessibilityHidden(true)
                                Text(item.status == "duplicate" ? "Email already imported" : "This document needs attention").font(.headline)
                                Text(item.issue ?? "Import the document again.").foregroundStyle(.primary).multilineTextAlignment(.center)
                                if item.status == "failed" && item.source.pathExtension.lowercased() == "eml" {
                                    Button("Retry email") { model.retryMailItem(item.id) }.accessibilityIdentifier("mail.retryEmail")
                                }
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
                .onChange(of: visibleItems.map(\.id), initial: true) {
                    model.inboxListOrder = visibleItems.map(\.id)
                    removalSelection.formIntersection(Set(visibleItems.map(\.id)))
                    syncSelection()
                }
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("Import", systemImage: "square.and.arrow.down") { Task { await model.importFiles() } }
                            .help("Import receipt files (⌘I)").accessibilityIdentifier("inbox.addMore")
                        Button("Paste", systemImage: "doc.on.clipboard") { Task { await model.pasteImage() } }
                            .help("Paste a copied receipt image (⇧⌘V)").accessibilityIdentifier("inbox.paste")
                    }
                }
        }
    }
}

/// Each row depends only on its visible values. Unrelated documents finishing
/// extraction need not rebuild this row's content and automatic-height layout.
struct InboxRow: View, Equatable {
    let id: UUID
    let name: String
    var sourceLabel: String? = nil
    let status: String
    let duplicate: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name).lineLimit(2).font(.callout.weight(.medium))
            if let sourceLabel { Text(sourceLabel).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
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
            .font(.subheadline.weight(.semibold))
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
    /// QA-08: a total Paperloft couldn't verify, still as extracted. Return alone doesn't file it;
    /// clicking Confirm or ⌘Return (Receipt › Confirm and File) does.
    private var totalNeedsDeliberateConfirm: Bool { verificationMessage("total") != nil }
    private func submitFromKeyboard() {
        if totalNeedsDeliberateConfirm { focusedField = .total } else { Task { await model.fileSelected() } }
    }
    private func verificationMessage(_ field: String) -> String? {
        guard let review = item.review else { return nil }
        let reasons = review.assessment.reasons
        let crossCheck = reasons.contains(.parserUnavailable) || reasons.contains(.parserDisagreement)
        switch field {
        case "vendor" where draft.vendor == review.fields.vendor:
            if review.fields.emailVendorHint == true { return "From email sender. Verify merchant." }
        case "date" where draft.date == review.fields.date:
            if review.fields.emailDateHint == true { return "From email date. Verify receipt date." }
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
    /// QA-04: an Issue with no field message still says why it needs a look.
    private var unexplainedIssueSummary: String? {
        guard let reasons = item.review?.assessment.reasons, inboxDisplayStatus(item) == "Issue",
              !reasons.contains(.notReceipt),
              ["vendor", "date", "total", "tax", "currency", "category", "kind"].allSatisfy({ fieldMessage($0) == nil }) else { return nil }
        return ReviewExplanation.summary(for: reasons)
    }
    private func fieldMessage(_ field: String) -> String? {
        let currency = draft.currency.uppercased().trimmingCharacters(in: .whitespaces)
        let validCurrency = (try? Money(minorUnits: 0, currency: currency)) != nil
        let total = try? Money(decimal: draft.total, currency: validCurrency ? currency : "USD")
        switch field {
        case "vendor":
            return draft.vendor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter the merchant name." : verificationMessage("vendor")
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
                    Text("Receipt preview").font(.caption).foregroundStyle(.primary)
                    Spacer()
                    Button("Expand preview", systemImage: "arrow.up.left.and.arrow.down.right") { model.quickLookURL = item.documentURL }
                        .accessibilityIdentifier("review.expandPreview")
                }.padding(10)
                Group {
                    if let documentURL = item.documentURL { DocumentPreview(url: documentURL) }
                    else { Text("Saved receipt preview is unavailable. Reimport the original.") }
                }
                    .overlay {
                        Button { model.quickLookURL = item.documentURL } label: { Color.clear.contentShape(Rectangle()) }
                            .buttonStyle(.plain).accessibilityLabel("Open full-size receipt preview")
                            .accessibilityIdentifier("review.openPreview")
                    }
                    .accessibilityElement(children: .contain).accessibilityLabel("Document preview").accessibilityIdentifier("review.preview")
            }.frame(minWidth: 240, idealWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                .background(WindowAccessibility(label: "Document preview", target: .splitPane))
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Review document").font(.title3.weight(.semibold))
                    if item.review?.assessment.reasons.contains(.notReceipt) == true {
                        // QA-06: say plainly that the reader judged this not to be a financial document.
                        Label("This doesn't look like a receipt, invoice or bill. Remove it, or choose a document type and fill in the details if it is one.",
                              systemImage: "questionmark.folder").font(.callout).foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("review.notReceipt")
                    }
                    if let duplicate = item.review?.duplicate {
                        Label("Already filed: \(duplicate)", systemImage: "doc.on.doc").font(.callout).foregroundStyle(.orange).accessibilityIdentifier("review.duplicate")
                    }
                }
                // Every row is label + control, so labels share one trailing-aligned column and a
                // warning outlines only the control it's about.
                Form {
                    LabeledContent("Vendor") {
                        TextField("Vendor", text: $draft.vendor).labelsHidden().focused($focusedField, equals: .vendor).accessibilityIdentifier("review.vendor").modifier(ReviewHighlight(message: fieldMessage("vendor")))
                    }
                    LabeledContent("Date") {
                    HStack {
                        TextField("Date", text: $draft.date, prompt: Text("YYYY-MM-DD")).labelsHidden().focused($focusedField, equals: .date).accessibilityIdentifier("review.date")
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
                                ReceiptCalendar(selection: $calendarDate)
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
                            }.padding(18).frame(width: 320)
                        }
                    }.modifier(ReviewHighlight(message: fieldMessage("date")))
                    }
                    LabeledContent("Total") {
                        TextField("Total", text: $draft.total).labelsHidden().monospacedDigit().focused($focusedField, equals: .total).accessibilityIdentifier("review.total").modifier(ReviewHighlight(message: fieldMessage("total")))
                    }
                    LabeledContent("Tax") {
                        TextField("Tax (optional)", text: $draft.tax, prompt: Text("Optional")).labelsHidden().monospacedDigit().focused($focusedField, equals: .tax).accessibilityIdentifier("review.tax").modifier(ReviewHighlight(message: fieldMessage("tax")))
                    }
                    LabeledContent("Currency") {
                        AccessiblePopup(label: "Currency", identifier: "review.currency", choices: CurrencyChoices.list(including: draft.currency), selection: $draft.currency, title: CurrencyChoices.title)
                            .modifier(ReviewHighlight(message: fieldMessage("currency")))
                    }
                    LabeledContent("Category") {
                        AccessiblePopup(label: "Category", identifier: "review.category", choices: Array(Set(model.categories + [draft.category])).sorted(), selection: $draft.category)
                            .modifier(ReviewHighlight(message: fieldMessage("category")))
                    }
                    LabeledContent("Document type") {
                        AccessiblePopup(label: "Document type", identifier: "review.kind", choices: ["Receipt", "Invoice", "Bill"], selection: Binding(get: { draft.kind.rawValue.capitalized }, set: { draft.kind = DocumentKind(rawValue: $0.lowercased()) ?? .receipt }))
                            .modifier(ReviewHighlight(message: fieldMessage("kind")))
                    }
                }
                .textFieldStyle(.roundedBorder)
                .onSubmit { submitFromKeyboard() }
                if let error = model.templateError {
                    Text(error).font(.caption).foregroundStyle(.orange).accessibilityIdentifier("review.validation")
                }
                if let why = unexplainedIssueSummary {
                    Label(why, systemImage: "info.circle").font(.callout).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("review.why")
                }
                Spacer(minLength: 0)
                Text("Files into \(String(draft.date.prefix(4)))/\(draft.category)/")
                    .font(.caption).foregroundStyle(.primary).lineLimit(2).accessibilityIdentifier("review.destination")
                Text(model.mode == .copy ? "Saves a copy to your library. Your original stays in place." : "Moves the original to your library. You can undo this in History.")
                    .font(.caption).foregroundStyle(.primary)
                HStack {
                    Button { model.setAside(item.id) } label: { Text("Remove").foregroundStyle(.red) }.help("Remove from Inbox. The original file stays in place.").accessibilityIdentifier("review.setAside")
                    Spacer()
                    Button("Confirm") { Task { await model.fileSelected() } }
                        .buttonStyle(.borderedProminent).keyboardShortcut(totalNeedsDeliberateConfirm ? nil : .defaultAction)
                        .disabled(!model.canFile).accessibilityIdentifier("review.file")
                }
                if let reason = model.filingUnavailableReason, ["vendor", "date", "total", "tax", "currency", "category"].allSatisfy({ fieldMessage($0) == nil }) {
                    Text(reason).font(.caption).foregroundStyle(.primary)
                        .accessibilityIdentifier("review.filingUnavailableReason")
                }
                Text(totalNeedsDeliberateConfirm ? "Check the total, then click Confirm or press ⌘Return · Tab to move between fields"
                                                 : "Return to confirm · Tab to move between fields")
                    .font(.caption).foregroundStyle(.primary).accessibilityIdentifier("review.keyboardHint")
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
    // Scene storage keeps the sort order while switching sections, like a Finder window.
    @SceneStorage("library.sortColumn") private var sortColumn = LibrarySort.Column.date.rawValue
    @SceneStorage("library.sortAscending") private var sortAscending = false
    private var sort: LibrarySort {
        get { LibrarySort(column: LibrarySort.Column(rawValue: sortColumn) ?? .date, ascending: sortAscending) }
        nonmutating set { sortColumn = newValue.column.rawValue; sortAscending = newValue.ascending }
    }
    @FocusState private var searchFocused: Bool
    @Environment(\.colorScheme) private var scheme
    private var canvas: Color { scheme == .dark ? Color(red: 0.12, green: 0.135, blue: 0.13) : Color(red: 0.985, green: 0.98, blue: 0.965) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search your receipts", text: $model.search)
                    .textFieldStyle(.plain).font(.body).focused($searchFocused)
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
            Text("Filed receipts").font(.headline).padding(.top, 8)
            VStack(spacing: 4) {
                // Click a column to sort by it; click again to reverse. The header shares the rows' insets so labels sit over their values.
                HStack(spacing: 12) {
                    Color.clear.frame(width: 42, height: 1).accessibilityHidden(true)
                    sortHeader(.date, width: 100, alignment: .leading)
                    sortHeader(.merchant, width: nil, alignment: .leading)
                    sortHeader(.category, width: 110, alignment: .leading)
                    sortHeader(.total, width: 108, alignment: .trailing)
                    Color.clear.frame(width: 70, height: 1).accessibilityHidden(true)
                }.font(.caption.weight(.medium)).foregroundStyle(.primary).padding(.horizontal, 16 + Self.listRowInset).padding(.bottom, 6)
                List(selection: $selected) {
                    ForEach(sort.apply(to: model.documents)) { document in
                        HStack(spacing: 12) {
                            LibraryReceiptIcon(category: document.receipt.category).frame(width: 42)
                            Text(Self.displayDate(document.receipt.date)).font(.callout).monospacedDigit().frame(width: 100, alignment: .leading)
                                .accessibilityIdentifier("library.date")
                            VStack(alignment: .leading, spacing: 5) {
                                Text(document.receipt.vendor).font(.body.weight(.medium)).lineLimit(2).accessibilityIdentifier("library.merchant")
                                Text(document.receipt.kind.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Text(document.receipt.category).font(.callout).lineLimit(2).frame(width: 110, alignment: .leading)
                            Text(Self.amount(document.receipt)).font(.body.weight(.medium)).monospacedDigit().frame(width: 108, alignment: .trailing)
                                .accessibilityIdentifier("library.total")
                            Button("View") { open(document) }.buttonStyle(.bordered).buttonBorderShape(.capsule)
                                .frame(width: 70).accessibilityLabel("View receipt from " + document.receipt.vendor)
                                .accessibilityIdentifier("library.view." + document.id.uuidString)
                        }.padding(.horizontal, 16).padding(.vertical, 16)
                            .frame(minHeight: 76)
                            // The selected row gets an accent tint and a 2 pt accent border, so it reads at a glance.
                            .background {
                                RoundedRectangle(cornerRadius: 12).fill(scheme == .dark ? Color.white.opacity(0.055) : Color(red: 0.952, green: 0.938, blue: 0.916))
                                    .overlay(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(selected == document.id ? 0.16 : 0)))
                            }
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected == document.id ? Color.accentColor : .clear, lineWidth: 2))
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
            Text(model.documents.count == 1 ? "1 document" : "\(model.documents.count) documents").font(.caption).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("library.count")
            Text("Double-click a receipt to open it. Deleted receipts can be restored from Recently Deleted.")
                .font(.caption).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(24).background(canvas)
        .confirmationDialog("Delete this receipt?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Delete Receipt", role: .destructive) {
                if let document = pendingDelete { Task { await model.deleteDocument(document) } }
                pendingDelete = nil
            }.accessibilityIdentifier("library.confirmDelete")
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { Text("It will leave your library and future exports. You can restore it from Recently Deleted; external originals are preserved.") }
        .sheet(isPresented: $showDeleted) { RecentlyDeletedView(model: model) }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Open Receipt", systemImage: "eye") { open(selectedDocument) }
                    .disabled(selectedDocument == nil).help("Open the selected receipt").accessibilityIdentifier("library.quickLook")
                Button("Reveal in Finder", systemImage: "folder") { model.reveal(selectedDocument) }
                    .disabled(selectedDocument == nil).help("Show the selected receipt in Finder").accessibilityIdentifier("library.reveal")
                Button("Delete", systemImage: "trash") { pendingDelete = selectedDocument }
                    .disabled(selectedDocument == nil || model.busy).help("Move the selected receipt to Recently Deleted").accessibilityIdentifier("library.delete")
                Button("Recently Deleted", systemImage: "clock.arrow.circlepath") { showDeleted = true }
                    .help("Restore receipts you deleted").accessibilityIdentifier("library.deleted")
            }
        }
        .onChange(of: model.findRequested, initial: true) {
            guard model.findRequested else { return }
            model.findRequested = false
            Task { @MainActor in searchFocused = true }
        }
        .onChange(of: model.search) { model.scheduleSearch() }.onChange(of: model.yearFilter) { model.scheduleSearch() }
        .onChange(of: model.categoryFilter) { model.scheduleSearch() }.onChange(of: model.kindFilter) { model.scheduleSearch() }
    }
    private func open(_ document: FiledDocument?) {
        guard let document, let root = model.libraryURL else { return }
        model.quickLookURL = root.appendingPathComponent(document.relativePath)
    }
    private var selectedDocument: FiledDocument? { model.documents.first { $0.id == selected } }
    /// The plain List's own horizontal row inset on macOS, measured by LibraryAlignmentTests.
    static let listRowInset: CGFloat = 8
    private func sortHeader(_ column: LibrarySort.Column, width: CGFloat?, alignment: Alignment) -> some View {
        Button { sort.toggle(column) } label: {
            // The indicator sits on the inner side, so the label's outer edge lines up with the values.
            HStack(spacing: 3) {
                if alignment == .trailing { indicator(for: column) }
                Text(column.rawValue)
                if alignment != .trailing { indicator(for: column) }
            }
        }.buttonStyle(.plain)
            .frame(maxWidth: width ?? .infinity, alignment: alignment).frame(width: width)
            .accessibilityLabel("Sort by " + column.rawValue)
            .accessibilityValue(sort.column == column ? (sort.ascending ? "Ascending" : "Descending") : "")
            .accessibilityIdentifier("library.sort." + column.rawValue)
    }
    private func indicator(for column: LibrarySort.Column) -> some View {
        Image(systemName: sort.ascending ? "chevron.up" : "chevron.down").font(.caption2.weight(.bold))
            .opacity(sort.column == column ? 1 : 0).accessibilityHidden(true)
    }
    /// Localized amount, e.g. "$42.35", from the stored minor units.
    static func amount(_ receipt: Receipt) -> String {
        guard let money = try? Money(minorUnits: receipt.totalMinorUnits, currency: receipt.currency),
              let value = Decimal(string: money.decimal) else { return "—" }
        return value.formatted(.currency(code: receipt.currency))
    }
    /// Localized medium date, e.g. "Sep 18, 2026". Filenames keep the ISO form.
    static func displayDate(_ date: ReceiptDate) -> String {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current
        guard let value = calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day)) else { return date.formatted }
        return value.formatted(date: .abbreviated, time: .omitted)
    }
}

/// Library sort order: Date and Total start newest/largest first, text columns A to Z.
struct LibrarySort: Equatable {
    enum Column: String { case date = "Date", merchant = "Merchant", category = "Category", total = "Total" }
    var column = Column.date
    var ascending = false
    mutating func toggle(_ tapped: Column) {
        if column == tapped { ascending.toggle() } else { column = tapped; ascending = tapped == .merchant || tapped == .category }
    }
    func apply(to documents: [FiledDocument]) -> [FiledDocument] {
        documents.sorted { first, second in
            let a = first.receipt, b = second.receipt
            let order: ComparisonResult
            switch column {
            case .date: order = a.date.formatted.compare(b.date.formatted)
            case .merchant: order = a.vendor.localizedStandardCompare(b.vendor)
            case .category: order = a.category.localizedStandardCompare(b.category)
            case .total:
                let x = Decimal(string: (try? Money(minorUnits: a.totalMinorUnits, currency: a.currency).decimal) ?? "") ?? 0
                let y = Decimal(string: (try? Money(minorUnits: b.totalMinorUnits, currency: b.currency).decimal) ?? "") ?? 0
                order = x == y ? a.currency.compare(b.currency) : (x < y ? .orderedAscending : .orderedDescending)
            }
            // Ties keep a stable, newest-first order.
            if order == .orderedSame { return first.filedAt > second.filedAt }
            return ascending ? order == .orderedAscending : order == .orderedDescending
        }
    }
}

struct LibraryFilterChip: View {
    let title: String
    let identifier: String
    let choices: [String]
    @Binding var selection: String
    var body: some View {
        AccessibleFilterPicker(label: title, identifier: identifier, choices: choices, selection: $selection)
            .frame(maxWidth: title == "Category" ? 174 : 129)
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
    @State private var selectedCategory: Int?
    @FocusState private var editingCategory: Int?
    @AppStorage("appearance") private var appearance = "System"
    private enum Tab: Hashable { case general, filing, categories }
    @State private var tab = Tab.general
    var body: some View {
        if embedded {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) { generalSections; filingSections; categorySections; aboutSection }.padding(24)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityIdentifier("settings.root")
        } else {
            // Standard Settings tabs keep every control inside the visible window; one long
            // scrolling pane left filing controls below the window edge.
            // Settings always opens on General rather than the last pane shown.
            TabView(selection: $tab) {
                pane { generalSections; aboutSection }.tabItem { Label("General", systemImage: "gearshape") }.tag(Tab.general)
                pane { filingSections }.tabItem { Label("Filing", systemImage: "folder") }.tag(Tab.filing)
                pane { categorySections }.tabItem { Label("Categories", systemImage: "tag") }.tag(Tab.categories)
            }.frame(width: 610).accessibilityIdentifier("settings.root")
                .onDisappear { tab = .general }
        }
    }

    /// Each pane is only as tall as its content, so the window fits the chosen tab.
    private func pane<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 24) { content() }.padding(24).fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var generalSections: some View {
        GroupBox("Appearance") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Theme", selection: $appearance) {
                    Text("System").tag("System")
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                }.pickerStyle(.segmented).accessibilityIdentifier("settings.appearance")
                Text("System follows your Mac’s appearance. Light and Dark apply only to Paperloft.").font(.callout)
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        }
        GroupBox("Library") {
            VStack(alignment: .leading, spacing: 12) {
                FolderSummary(url: model.libraryURL, placeholder: "No library folder chosen",
                              identifier: "settings.libraryFolder",
                              name: model.isSampleLibrary ? "Practice library" : nil,
                              detail: model.isSampleLibrary ? "Kept inside Paperloft. Choose your own folder before adding real receipts." : nil)
                HStack {
                    Button("Choose Folder…") { Task { await model.chooseLibrary() } }.disabled(model.busy).accessibilityIdentifier("settings.chooseFolder")
                    Button("Show in Finder") { model.reveal() }.disabled(model.libraryURL == nil).accessibilityIdentifier("settings.reveal")
                    Button("Rebuild Search Index") { Task { await model.rebuildIndex() } }.disabled(model.busy || model.libraryURL == nil).accessibilityIdentifier("settings.rebuild")
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
                FolderSummary(url: model.watchedFolderURL, placeholder: "No watched folder chosen", identifier: "settings.watchedFolder")
                Text(model.watchedStatus).accessibilityIdentifier("settings.watchedStatus")
                HStack {
                    Button("Choose Watched Folder…") { Task { await model.chooseWatchedFolder() } }
                        .disabled(model.busy || !model.isPro).accessibilityIdentifier("settings.chooseWatchedFolder")
                    if model.watchedEnabled {
                        Button("Turn Off") { Task { await model.disableWatchedFolder() } }.accessibilityIdentifier("settings.disableWatchedFolder")
                    } else {
                        Button("Turn On") { Task { await model.restoreWatchedFolder() } }
                            .disabled(!model.isPro || model.watchedFolderURL == nil).accessibilityIdentifier("settings.enableWatchedFolder")
                    }
                }
                Text("PDFs, images (including TIFF), and saved email (.eml) are copied to the Inbox for review. Originals stay in place.").font(.caption)
                ForEach(Array(model.watchedIssues.enumerated()), id: \.offset) { _, issue in Text(issue).font(.caption).foregroundStyle(.orange) }
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Paperloft Receipts").font(.headline)
            Text("On-device processing. No analytics or tracking.").foregroundStyle(.primary)
            Text("© 2026 EvidencePair LLC").font(.caption).foregroundStyle(.primary)
        }
    }

    @ViewBuilder private var filingSections: some View {
        GroupBox("Scanned pages") {
            VStack(alignment: .leading, spacing: 8) {
                AccessiblePicker(label: "When scanning multiple pages", identifier: "settings.scannedPages",
                    choices: ["Each page is a separate receipt", "All pages are one document"],
                    selection: Binding(get: {
                        model.scannedPages == .separate ? "Each page is a separate receipt" : "All pages are one document"
                    }, set: {
                        model.scannedPages = $0 == "Each page is a separate receipt" ? .separate : .combined
                    }))
                Text("Scan with File › Import From Device › Scan Documents, listed under your iPhone or iPad. Your devices need the same Apple Account.")
                    .font(.caption).foregroundStyle(.primary)
            }.padding(8)
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
    }

    @ViewBuilder private var categorySections: some View {
        GroupBox("Categories") {
            VStack(alignment: .leading, spacing: 9) {
                Text("Organizational categories, not tax advice. Changes affect future filing; existing documents stay in their folders.").font(.callout).foregroundStyle(.primary)
                List(selection: $selectedCategory) {
                    ForEach(model.categories.indices, id: \.self) { index in
                        TextField("Category", text: Binding(get: { model.categories.indices.contains(index) ? model.categories[index] : "" },
                                                            set: { if model.categories.indices.contains(index) { model.categories[index] = $0; model.saveCategories() } }))
                            .textFieldStyle(.plain).labelsHidden().focused($editingCategory, equals: index)
                            .accessibilityIdentifier("settings.category.\(index)").tag(index)
                    }
                }.listStyle(.bordered(alternatesRowBackgrounds: true)).frame(height: 300)
                    .onDeleteCommand { removeSelectedCategory() }
                    .accessibilityIdentifier("settings.categories")
                HStack(spacing: 0) {
                    Button { addCategory() } label: { Image(systemName: "plus").frame(width: 22, height: 18) }
                        .help("Add a category").accessibilityLabel("Add category").accessibilityIdentifier("settings.addCategory")
                    Button { removeSelectedCategory() } label: { Image(systemName: "minus").frame(width: 22, height: 18) }
                        .disabled(selectedCategory == nil).help("Remove the selected category")
                        .accessibilityLabel("Remove category").accessibilityIdentifier("settings.removeCategory")
                }.buttonStyle(.bordered).controlSize(.small)
            }.padding(8)
        }
    }

    /// Adds "New Category" (numbered if taken) and starts editing it.
    private func addCategory() {
        var name = "New Category", number = 2
        while model.categories.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) { name = "New Category \(number)"; number += 1 }
        model.categories.append(name); model.saveCategories()
        let index = model.categories.count - 1
        selectedCategory = index
        Task { @MainActor in editingCategory = index }
    }

    private func removeSelectedCategory() {
        guard let index = selectedCategory, model.categories.indices.contains(index) else { return }
        model.categories.remove(at: index); model.saveCategories()
        selectedCategory = model.categories.isEmpty ? nil : min(index, model.categories.count - 1)
    }
}

/// A folder as Finder shows it: its icon and display name, with the full path in the help tag
/// and as the accessibility value.
struct FolderSummary: View {
    let url: URL?
    let placeholder: String
    let identifier: String
    var name: String? = nil
    var detail: String? = nil
    var body: some View {
        if let url {
            let title = name ?? FileManager.default.displayName(atPath: url.path)
            let subtitle = detail ?? url.deletingLastPathComponent().path
            HStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.medium))
                    Text(subtitle).font(.callout).foregroundStyle(.primary).lineLimit(1).truncationMode(.middle)
                }
            }.help(url.path)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(detail == nil ? title : title + ", " + subtitle)
                .accessibilityValue(url.path).accessibilityIdentifier(identifier)
        } else {
            Text(placeholder).font(.callout).accessibilityIdentifier(identifier)
        }
    }
}

/// Currency choices for review: the document's own value first (even if unrecognised, so it can be
/// seen and fixed), then this Mac's currency and other common ones, then every ISO currency.
enum CurrencyChoices {
    static let common = ["USD", "EUR", "GBP", "CAD", "AUD", "NZD", "JPY", "CHF", "MXN", "INR"]
    static func list(including current: String) -> [String] {
        let local = Locale.current.currency?.identifier
        var result: [String] = []
        for code in [current] + [local].compactMap({ $0 }) + common + Locale.commonISOCurrencyCodes.sorted() where !result.contains(code) {
            result.append(code)
        }
        return result
    }
    static func title(_ code: String) -> String {
        guard !code.isEmpty else { return "Choose a currency" }
        guard let name = Locale.current.localizedString(forCurrencyCode: code) else { return code }
        return code + " – " + name
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
                // Callout, not caption: the accessibility audit flags this warning's contrast at 10 pt.
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.callout).foregroundStyle(.primary)
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

/// A readable calendar with direct month/year navigation for older receipts.
private struct ReceiptCalendar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selection: Date
    @State private var month: Date
    private var calendar: Calendar { Calendar(identifier: .gregorian) }
    init(selection: Binding<Date>) {
        _selection = selection
        _month = State(initialValue: selection.wrappedValue)
    }
    private var start: Date { calendar.date(from: calendar.dateComponents([.year, .month], from: month))! }
    private var days: Int { calendar.range(of: .day, in: .month, for: start)!.count }
    private var offset: Int { (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7 }
    private func moveMonth(_ amount: Int) { month = calendar.date(byAdding: .month, value: amount, to: start)! }
    private func setComponent(_ component: Calendar.Component, _ value: Int) {
        var parts = calendar.dateComponents([.year, .month], from: start)
        if component == .year { parts.year = value } else { parts.month = value }
        month = calendar.date(from: parts)!
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Receipt date").font(.headline)
            HStack(spacing: 8) {
                Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Previous month")
                Menu {
                    ForEach(1...12, id: \.self) { value in
                        Button(calendar.monthSymbols[value - 1]) { setComponent(.month, value) }
                    }
                } label: { Text(calendar.monthSymbols[calendar.component(.month, from: month) - 1]) }
                Menu {
                    ForEach(1900...max(2100, calendar.component(.year, from: month)), id: \.self) { value in
                        Button(String(value)) { setComponent(.year, value) }
                    }
                } label: { Text(String(calendar.component(.year, from: month))) }
                Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("Next month")
            }.buttonStyle(.borderless)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 5) {
                ForEach(0..<7, id: \.self) { index in
                    Text(calendar.shortStandaloneWeekdaySymbols[(index + calendar.firstWeekday - 1) % 7])
                        .font(.caption.weight(.medium)).foregroundStyle(.secondary).frame(height: 22)
                        .accessibilityHidden(true)
                }
                ForEach(0..<(offset + days), id: \.self) { index in
                    if index < offset { Color.clear.frame(height: 32).accessibilityHidden(true) }
                    else {
                        let date = calendar.date(byAdding: .day, value: index - offset, to: start)!
                        let chosen = calendar.isDate(date, inSameDayAs: selection)
                        Button { selection = date } label: {
                            Text(String(index - offset + 1)).font(.callout.weight(chosen ? .semibold : .regular))
                                .frame(maxWidth: .infinity).frame(height: 32)
                                .foregroundStyle(chosen ? (colorScheme == .dark ? Color.black : Color.white) : Color.primary)
                                .background(chosen ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(calendar.isDateInToday(date) ? Color.accentColor : Color.clear))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                            .accessibilityAddTraits(chosen ? [.isSelected] : [])
                    }
                }
            }
            HStack {
                Text(selection.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Today") { selection = Date(); month = selection }.buttonStyle(.borderless)
            }
            Divider()
        }
    }
}

