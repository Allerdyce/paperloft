import AppKit
import SwiftUI
import UniformTypeIdentifiers
import PaperloftHandoff

@MainActor
final class ShareViewController: NSViewController {
    private var model: ShareSheetModel?
    override func loadView() {
        let model = ShareSheetModel(context: extensionContext)
        self.model = model
        let size = NSSize(width: 430, height: 390)
        // Hand the host a sized view: with a zero-frame hosting view the share window rendered blank.
        let hosting = NSHostingView(rootView: ShareSheet(model: model))
        hosting.frame = NSRect(origin: .zero, size: size)
        view = hosting
        preferredContentSize = size
    }
}

@MainActor
final class ShareSheetModel: ObservableObject {
    struct Candidate: Identifiable {
        let id = UUID()
        let name: String
        let provider: NSItemProvider
        let type: HandoffFileType
    }
    @Published private(set) var candidates: [Candidate] = []
    @Published private(set) var skipped: [String] = []
    @Published private(set) var isAdding = false
    @Published private(set) var message: String?
    @Published private(set) var complete = false
    private let context: NSExtensionContext?
    private var committed = Set<UUID>()
    private static let types: [HandoffFileType] = [.pdf, .jpeg, .png, .heic, .tiff, .email, .appleEmail]

    init(context: NSExtensionContext?, providers suppliedProviders: [NSItemProvider]? = nil) {
        self.context = context
        let providers = suppliedProviders ?? (context?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        for (index, provider) in providers.enumerated() {
            let name = provider.suggestedName ?? "Document \(index + 1)"
            guard let type = Self.types.first(where: { provider.hasItemConformingToTypeIdentifier($0.rawValue) }) else {
                skipped.append("\(name): unsupported file type")
                continue
            }
            guard candidates.count < HandoffStore.maximumFiles else {
                skipped.append("\(name): only 20 files can be added at once")
                continue
            }
            candidates.append(Candidate(name: name, provider: provider, type: type))
        }
    }

    func cancel() {
        guard !isAdding else { return }
        context?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }

    func add() {
        guard !isAdding, !complete, !candidates.isEmpty else { return }
        isAdding = true
        message = nil
        Task {
            defer { isAdding = false }
            do {
                guard Bundle.main.object(forInfoDictionaryKey: "PaperloftAppGroupEnabled") as? String == "YES",
                      let identifier = Bundle.main.object(forInfoDictionaryKey: "PaperloftAppGroupIdentifier") as? String,
                      identifier.range(of: "^[A-Z0-9]{10}\\.app\\.paperloft\\.receipts$", options: .regularExpression) != nil,
                      !identifier.hasPrefix("ABCDE12345."),
                      let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
                    message = "Sharing needs a signed Paperloft build. You can still import these files in the app."
                    return
                }
                let store = try HandoffStore(containerURL: container)
                for candidate in candidates where !committed.contains(candidate.id) {
                    do {
                        let staged = try await copyProviderFile(candidate)
                        defer { try? FileManager.default.removeItem(at: staged.deletingLastPathComponent()) }
                        _ = try await store.publish([HandoffInput(id: candidate.id, fileURL: staged, type: candidate.type)])
                        committed.insert(candidate.id)
                    } catch {
                        skipped.append("\(candidate.name): \(Self.reason(error))")
                    }
                }
                guard !committed.isEmpty else {
                    message = "No documents were added. Check the skipped items and try again."
                    return
                }
                complete = true
                message = "Added \(committed.count) \(committed.count == 1 ? "document" : "documents"). They're waiting in your Review inbox."
                // Give the result time to be read before closing the system share sheet.
                try? await Task.sleep(for: .seconds(1.8))
                context?.completeRequest(returningItems: [], completionHandler: nil)
            } catch {
                message = "The documents couldn't be added. Please try again."
            }
        }
    }

    func copyProviderFile(_ candidate: Candidate) async throws -> URL {
        let type = candidate.type
        let name = candidate.name
        return try await withCheckedThrowingContinuation { continuation in
            candidate.provider.loadFileRepresentation(forTypeIdentifier: type.rawValue) { url, error in
                do {
                    if let error { throw error }
                    guard let url else { throw HandoffError.invalidItem }
                    // Provider-owned file expires when this callback returns. Make a
                    // bounded streaming copy synchronously inside the callback.
                    let copy = try Self.stageProviderFile(url, name: name, type: type)
                    continuation.resume(returning: copy)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    nonisolated static func stageProviderFile(_ source: URL, name: String, type: HandoffFileType) throws -> URL {
        let fm = FileManager.default
        let staging = fm.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        var succeeded = false
        defer { if !succeeded { try? fm.removeItem(at: staging) } }
        let safeName = (name as NSString).lastPathComponent.replacingOccurrences(of: "\\", with: "-")
        let filename = type.accepts(filename: safeName) ? safeName : safeName + "." + type.fileExtension
        let target = staging.appendingPathComponent(filename)
        try HandoffFileCopy.copy(source: source, destination: target)
        succeeded = true
        return target
    }

    nonisolated private static func reason(_ error: Error) -> String {
        switch error as? HandoffError {
        case .fileTooLarge: "larger than 200 MB"
        case .unsupportedType: "unsupported file type"
        case .unsafePath: "not a regular file"
        default: "could not read or copy this file"
        }
    }
}

private struct ShareSheet: View {
    @ObservedObject var model: ShareSheetModel
    private var appIcon: NSImage {
        var app = Bundle.main.bundleURL
        for _ in 0..<3 { app.deleteLastPathComponent() }
        return NSWorkspace.shared.icon(forFile: app.path)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: appIcon).resizable().frame(width: 48, height: 48).accessibilityHidden(true)
                Text("Add \(model.candidates.count) \(model.candidates.count == 1 ? "document" : "documents") to Paperloft")
                    .font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.candidates.prefix(5)) { candidate in
                        Label(candidate.name, systemImage: "doc").lineLimit(2)
                    }
                    if model.candidates.count > 5 { Text("and \(model.candidates.count - 5) more").foregroundStyle(.secondary) }
                    if !model.skipped.isEmpty {
                        Text("Skipped").font(.headline).padding(.top, 8)
                        ForEach(Array(model.skipped.enumerated()), id: \.offset) { _, reason in
                            Text(reason).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if let message = model.message {
                Text(message).font(.callout).accessibilityIdentifier("share-status")
            }
            HStack {
                if model.isAdding && !model.complete { ProgressView().controlSize(.small); Text("Adding documents…").font(.callout) }
                Spacer()
                Button("Cancel", action: model.cancel).keyboardShortcut(.cancelAction).disabled(model.isAdding)
                Button("Add", action: model.add).keyboardShortcut(.defaultAction)
                    .disabled(model.candidates.isEmpty || model.isAdding || model.complete)
                    .accessibilityIdentifier("share-add")
            }
        }.padding(24).frame(width: 430, height: 390)
    }
}
