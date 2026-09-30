import AppKit
import Foundation
import PaperloftHandoff

@main struct ShareSmoke {
    @MainActor static func main() async throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: cwd.appendingPathComponent("Configuration/Share-Info.plist")), format: nil) as! [String: Any]
        let ext = plist["NSExtension"] as! [String: Any], attrs = ext["NSExtensionAttributes"] as! [String: Any]
        let rule = NSPredicate(format: attrs["NSExtensionActivationRule"] as! String)
        let supported = ["com.adobe.pdf", "public.jpeg", "public.png", "public.heic", "public.tiff", "public.email-message", "com.apple.mail.email"]
        for type in supported {
            precondition(rule.evaluate(with: ["extensionItems": [["attachments": [["registeredTypeIdentifiers": [type]]]]]]))
        }
        for type in ["public.plain-text", "public.url", "public.html"] {
            precondition(!rule.evaluate(with: ["extensionItems": [["attachments": [["registeredTypeIdentifiers": [type]]]]]]))
        }
        precondition(rule.evaluate(with: ["extensionItems": [["attachments": [["registeredTypeIdentifiers": ["public.plain-text"]], ["registeredTypeIdentifiers": ["com.adobe.pdf"]]]]]]))
        let workspace = cwd.appendingPathComponent("build/share-smoke/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspace) }
        let original = workspace.appendingPathComponent("source.pdf"), bytes = Data("synthetic receipt".utf8)
        try bytes.write(to: original)
        let provider = NSItemProvider()
        provider.suggestedName = "source.pdf"
        provider.registerFileRepresentation(forTypeIdentifier: "com.adobe.pdf", fileOptions: [], visibility: .all) { completion in
            completion(original, false, nil)
            return nil
        }
        let rejected = NSItemProvider(object: "plain text" as NSString)
        let model = ShareSheetModel(context: nil, providers: [rejected] + Array(repeating: provider, count: 21))
        precondition(model.candidates.count == 20)
        precondition(model.skipped.count == 2)
        let copy = try await model.copyProviderFile(model.candidates[0])
        defer { try? FileManager.default.removeItem(at: copy.deletingLastPathComponent()) }
        let copiedBytes = try Data(contentsOf: copy), originalBytes = try Data(contentsOf: original)
        precondition(copiedBytes == bytes)
        precondition(originalBytes == bytes)
        let unsafe = workspace.appendingPathComponent("linked.pdf")
        try FileManager.default.createSymbolicLink(at: unsafe, withDestinationURL: original)
        do {
            _ = try ShareSheetModel.stageProviderFile(unsafe, name: "linked.pdf", type: .pdf)
            preconditionFailure("Provider symlink must be rejected")
        } catch { precondition(error as? HandoffError == .unsafePath) }
        model.add()
        for _ in 0..<200 where model.isAdding { try await Task.sleep(for: .milliseconds(10)) }
        precondition(!model.isAdding && model.message?.contains("signed Paperloft build") == true)
        // Finder providers have no suggestedName: stage under the provider file's own name and
        // show that name once resolved, instead of the positional "Document N" fallback.
        let unnamedSource = workspace.appendingPathComponent("Acorn Receipt.pdf")
        try bytes.write(to: unnamedSource)
        let unnamed = NSItemProvider()
        unnamed.registerFileRepresentation(forTypeIdentifier: "com.adobe.pdf", fileOptions: [], visibility: .all) { completion in
            completion(unnamedSource, false, nil)
            return nil
        }
        unnamed.registerObject(unnamedSource as NSURL, visibility: .all)
        let unnamedModel = ShareSheetModel(context: nil, providers: [unnamed])
        precondition(unnamedModel.candidates.first?.name == "Document 1" && unnamedModel.candidates.first?.nameIsKnown == false)
        let unnamedCopy = try await unnamedModel.copyProviderFile(unnamedModel.candidates[0])
        defer { try? FileManager.default.removeItem(at: unnamedCopy.deletingLastPathComponent()) }
        precondition(unnamedCopy.lastPathComponent == "Acorn Receipt.pdf", unnamedCopy.lastPathComponent)
        await unnamedModel.resolveNames()
        precondition(unnamedModel.candidates.first?.name == "Acorn Receipt.pdf", unnamedModel.candidates.first?.name ?? "nil")
        precondition(ShareSheetModel.fileName(from: URL(fileURLWithPath: "/")) == nil)
        // Guard against regressing to a zero-frame view, which rendered a blank share window live.
        let controller = ShareViewController()
        precondition(controller.view.frame.size == NSSize(width: 430, height: 390))
        precondition(controller.preferredContentSize == NSSize(width: 430, height: 390))
        print("PASS: provider file names for unnamed shares; sized share view (430x390); provider symlink rejection; unsigned fallback; seven activation types; rejects text/URL/HTML; mixed share; 20-file cap and skipped reasons; provider callback copy survives and original unchanged")
    }
}
