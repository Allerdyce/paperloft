import AppIntents
import SwiftUI
import UniformTypeIdentifiers

@main @MainActor
struct PaperloftApp: App {
    @State private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        PaperloftIntentRuntime.service = model
    }
    var body: some Scene {
        Window("Paperloft Receipts", id: "main") {
            LibraryView(model: model)
                .background(WindowAccessibility(label: "Paperloft workspace"))
                .task {
                    model.openInboxWindow = { openWindow(id: "main") }
                    await model.start()
                }
                .onOpenURL { url in Task { await model.intake([url]) } }
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            // AppKit's automatic Services scanner blocks accessibility inspection on macOS 27.
            // Keep standard editing commands; receipt actions are explicit commands below.
            CommandGroup(replacing: .systemServices) {}
            CommandGroup(after: .newItem) {
                Button("Import Receipts…") { Task { await model.importFiles() } }
                    .keyboardShortcut("i", modifiers: [.command])
                    .accessibilityIdentifier("command.import")
                Button("Try with Samples") { Task { await model.trySamples() } }
                    .accessibilityIdentifier("command.samples")
            }
            CommandGroup(after: .pasteboard) {
                Button("Paste Image") { Task { await model.pasteImage() } }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                    .accessibilityIdentifier("command.pasteImage")
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
        Settings { PaperloftSettings(model: model).background(WindowAccessibility(label: "Paperloft settings")) }
        MenuBarExtra {
            MenuBarInbox(model: model)
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
            if let url = item as? URL { Task { @MainActor in await model.intake([url]) } }
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
            Text("Drop PDF or image receipts here").padding(20)
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
