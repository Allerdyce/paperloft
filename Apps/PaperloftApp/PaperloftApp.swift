import AppIntents
import SwiftUI
import UniformTypeIdentifiers

@main @MainActor
struct PaperloftApp: App {
    @State private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage("appearance") private var appearance = "System"
    init() {
        let sharedModel = AppModel()
        _model = State(initialValue: sharedModel)
        PaperloftIntentRuntime.service = sharedModel
        // Menu-only launches must restore the watched folder even when no main
        // window is visible. Window tasks share this same coalesced startup.
        Task { await sharedModel.start() }
    }
    var body: some Scene {
        Window("Paperloft Receipts", id: "main") {
            LibraryView(model: model)
                .modifier(AppAppearance())
                .background(WindowAccessibility(label: "Paperloft workspace"))
                .task {
                    model.openInboxWindow = { openWindow(id: "main") }
                    await model.start()
                }
                .onOpenURL { url in Task { await model.intake([url]) } }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    Task { await model.followMovedLibrary() }
                }
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            ImportFromDevicesCommands()
            // View › Show/Hide Sidebar (⌃⌘S).
            SidebarCommands()
            // AppKit's automatic Services scanner blocks accessibility inspection on macOS 27.
            // Keep standard editing commands; receipt actions are explicit commands below.
            CommandGroup(replacing: .systemServices) {}
            CommandGroup(after: .newItem) {
                Button("Import Receipts…") { Task { await model.importFiles() } }
                    .keyboardShortcut("i", modifiers: [.command])
                    .accessibilityIdentifier("command.import")
                Button("Choose Library Folder…") { Task { await model.chooseLibrary() } }
                    .disabled(model.busy)
                    .accessibilityIdentifier("command.chooseLibrary")
                Divider()
                // The export sheet belongs to the main window, so bring it back first if it was closed.
                Button("Export for Accountant…") { openWindow(id: "main"); model.beginExport() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(model.libraryURL == nil || model.busy)
                    .accessibilityIdentifier("command.export")
                #if DEBUG
                Button("Load Development Receipts") { Task { await model.trySamples() } }
                    .accessibilityIdentifier("command.samples")
                #endif
            }
            CommandGroup(after: .textEditing) {
                Button("Find…") { openWindow(id: "main"); model.selection = "Library"; model.findRequested = true }
                    .keyboardShortcut("f", modifiers: .command)
                    .accessibilityIdentifier("command.find")
            }
            CommandGroup(after: .pasteboard) {
                Button("Paste Image") { Task { await model.pasteImage() } }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                    .accessibilityIdentifier("command.pasteImage")
            }
            // Receipt actions as menu commands. Remove has no shortcut and navigation avoids ⌘↑/⌘↓,
            // because those keys edit text while a review field is focused.
            CommandMenu("Receipt") {
                Button("Confirm and File") { Task { await model.fileSelected() } }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!model.canFile || model.selectedItem == nil)
                    .accessibilityIdentifier("command.confirm")
                Button("Remove from Inbox") { if let id = model.selectedItem?.id { model.setAside(id) } }
                    .disabled(model.selectedItem == nil)
                    .accessibilityIdentifier("command.remove")
                Divider()
                Button("Next Document") { model.selectAdjacentItem(1) }
                    .keyboardShortcut("]", modifiers: .command)
                    .disabled(model.inboxCount < 2)
                    .accessibilityIdentifier("command.nextDocument")
                Button("Previous Document") { model.selectAdjacentItem(-1) }
                    .keyboardShortcut("[", modifiers: .command)
                    .disabled(model.inboxCount < 2)
                    .accessibilityIdentifier("command.previousDocument")
            }
            CommandGroup(replacing: .help) {
                Button("Paperloft Help") { openWindow(id: "help") }
                    .accessibilityIdentifier("command.help")
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo Last Filing") {
                    if let batch = model.batches.first(where: { $0.state == .complete }) { Task { await model.undo(batch) } }
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(model.busy || !model.batches.contains(where: { $0.state == .complete }))
                .accessibilityIdentifier("command.undo")
            }
        }
        Window("Paperloft Help", id: "help") { HelpView().modifier(AppAppearance()) }
            .defaultSize(width: 640, height: 720)
        Settings { PaperloftSettings(model: model).modifier(AppAppearance()).background(WindowAccessibility(label: "Paperloft settings")) }
        MenuBarExtra {
            MenuBarInbox(model: model).modifier(AppAppearance())
        } label: {
            Label("Paperloft · \(model.inboxCount) in inbox", systemImage: "tray")
                .accessibilityIdentifier("menubar.status")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor func acceptDrop(_ providers: [NSItemProvider], model: AppModel) -> Bool {
    var accepted = false
    for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
        accepted = true
        _ = provider.loadObject(ofClass: NSURL.self) { item, _ in
            if let url = item as? URL { Task { @MainActor in await model.intake([url], origin: .drop) } }
        }
    }
    return accepted
}

struct MenuBarInbox: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var targeted = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Paperloft", systemImage: "tray.fill").font(.headline)
            Text("\(model.inboxCount) documents in your inbox").foregroundStyle(.secondary)
            Text("Drop PDF, image or EML email receipts here").padding(20)
                .frame(maxWidth: .infinity)
                .background(targeted ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .onDrop(of: [.fileURL], isTargeted: $targeted) { acceptDrop($0, model: model) }
                .accessibilityIdentifier("menubar.drop")
            Button("Open Inbox") { model.selection = "Inbox"; openWindow(id: "main"); NSApplication.shared.activate() }
                .accessibilityIdentifier("menubar.open")
            Button("Import Receipts…") { openWindow(id: "main"); NSApplication.shared.activate(); Task { await model.importFiles() } }
                .accessibilityIdentifier("menubar.import")
        }
        .padding(20).frame(width: 300)
    }
}

/// Applies Settings › Appearance app-wide through AppKit. `preferredColorScheme(nil)` doesn't reliably clear a
/// window's forced appearance on macOS, so switching Dark back to System left windows unreadable until reopened.
struct AppAppearance: ViewModifier {
    @AppStorage("appearance") private var appearance = "System"
    func body(content: Content) -> some View {
        content
            .onAppear { apply() }
            .onChange(of: appearance) { apply() }
    }
    private func apply() {
        let named: NSAppearance.Name? = appearance == "Dark" ? .darkAqua : appearance == "Light" ? .aqua : nil
        NSApplication.shared.appearance = named.flatMap { NSAppearance(named: $0) }
        for window in NSApplication.shared.windows {
            window.appearance = nil
            window.contentView?.needsDisplay = true
            window.invalidateShadow()
        }
    }
}
