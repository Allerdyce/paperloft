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
        // Entitlements come from StoreKit's signed transaction cache; no paywall at launch.
        Task { await sharedModel.store.start() }
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
                    Task { await model.followMovedLibrary(); await model.store.refreshEntitlements() }
                }
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            ImportFromDevicesCommands()
            // View › Show/Hide Sidebar (⌃⌘S), with the three sections above it.
            SidebarCommands()
            CommandGroup(before: .sidebar) {
                ForEach(Array(["Inbox", "Library", "History"].enumerated()), id: \.offset) { index, section in
                    Button(section) { openWindow(id: "main"); model.selection = section }
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                        .accessibilityIdentifier("command.section." + section.lowercased())
                }
                Divider()
            }
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
                // Always enabled: a menu item's disabled state can go stale after launch, which made
                // ⇧⌘E do nothing. The model explains or waits instead.
                Button("Tax & Accountant Export…") { openWindow(id: "main"); model.requestExport() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
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
            #if DEBUG || QA
            // Debug and QA builds only: test controls that would otherwise need extra launch arguments
            // (SPEC 6.7 lists the only launch hooks). Never compiled into Release.
            CommandMenu("Debug") {
                if model.store.isMock {
                    Menu("Mock Store") {
                        Button("Make Pro (Lifetime)") { model.store.mockMakePro(); model.resumeQuotaPaused() }
                            .accessibilityIdentifier("debug.mockMakePro")
                        Button("Return to Free") { model.store.mockReturnToFree() }.accessibilityIdentifier("debug.mockReturnToFree")
                        Divider()
                        Button("Expire Purchase") { model.store.mockExpire() }.accessibilityIdentifier("debug.mockExpire")
                        Button("Clear Local Entitlement") { model.store.mockHideEntitlement() }.accessibilityIdentifier("debug.mockClear")
                        Button("Approve Pending Purchase") { model.store.mockApprovePending(); model.resumeQuotaPaused() }
                            .accessibilityIdentifier("debug.mockApprove")
                        Picker("Next Purchase", selection: Binding(get: { model.store.mockOutcome }, set: { model.store.mockOutcome = $0 })) {
                            ForEach(StoreController.MockOutcome.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                        }
                    }
                }
                Button("Size Window for App Store Screenshots") {
                    // 1440 x 900 points is 2880 x 1800 pixels at 2x, the App Store's Mac size.
                    guard let window = NSApp.mainWindow ?? NSApp.keyWindow else { return }
                    let top = (window.screen ?? NSScreen.main)?.visibleFrame.maxY ?? 1000
                    window.setFrame(NSRect(x: 80, y: top - 60 - 900, width: 1440, height: 900), display: true)
                }.accessibilityIdentifier("debug.screenshotSize")
                if model.testMode {
                    Button("Use This Month's Automatic Reads") { model.debugUseAllAutomaticReads() }
                        .accessibilityIdentifier("debug.useAllReads")
                    Button("Reset to First Launch and Quit") { model.debugResetToFirstLaunch() }
                        .accessibilityIdentifier("debug.resetFirstLaunch")
                }
            }
            #endif
            CommandGroup(replacing: .help) {
                Button("Paperloft Help") { openWindow(id: "help") }
                    .accessibilityIdentifier("command.help")
            }
        }
        Window("Paperloft Help", id: "help") { HelpView().modifier(AppAppearance()) }
            .defaultSize(width: 640, height: 720)
            .restorationBehavior(.disabled) // like Help Viewer: a relaunch opens the library, not last session's help
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
            Text(model.inboxCount == 0 ? "Your Inbox is empty"
                 : "\(model.inboxCount) \(model.inboxCount == 1 ? "receipt" : "receipts") waiting in your Inbox")
                .foregroundStyle(.primary).accessibilityIdentifier("menubar.count")
            VStack(spacing: 6) {
                Image(systemName: "arrow.down.doc").font(.title2).foregroundStyle(Color.accentColor).accessibilityHidden(true)
                Text("Drop receipts here").font(.callout.weight(.medium))
                Text("PDF, image or saved email").font(.caption).foregroundStyle(.primary)
            }
            .padding(.vertical, 16).frame(maxWidth: .infinity)
            .background(targeted ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(targeted ? Color.accentColor : .clear, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])))
            .onDrop(of: [.fileURL], isTargeted: $targeted) { acceptDrop($0, model: model) }
            .accessibilityElement(children: .combine).accessibilityIdentifier("menubar.drop")
            HStack {
                Button("Import Receipts…") { openWindow(id: "main"); NSApplication.shared.activate(); Task { await model.importFiles() } }
                    .accessibilityIdentifier("menubar.import")
                Spacer()
                Button("Open Inbox") { model.selection = "Inbox"; openWindow(id: "main"); NSApplication.shared.activate() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).accessibilityIdentifier("menubar.open")
            }
        }
        .padding(20).frame(width: 300)
        // An opaque panel, so text contrast is measured against what's actually behind it.
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain).accessibilityLabel("Paperloft Inbox")
        .background(WindowAccessibility(label: "Paperloft Inbox", target: .panel))
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
