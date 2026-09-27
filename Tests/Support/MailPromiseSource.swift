// Standalone diagnostic source for a real NSFilePromiseProvider drag. Not linked into the app or test runner.
import AppKit

@MainActor final class Source: NSView, NSDraggingSource, NSFilePromiseProviderDelegate {
    nonisolated let bytes: Data
    private var events: [String] = []
    private func record(_ event: String) {
        events.append(event)
        window?.title = events.joined(separator: " | ")
        FileHandle.standardOutput.write(Data((event + "\n").utf8))
    }
    init(bytes: Data) {
        self.bytes = bytes
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 150))
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityIdentifier("synthetic.promise.dragSource")
        setAccessibilityLabel("Synthetic email drag source")
    }
    required init?(coder: NSCoder) { nil }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemGreen.withAlphaComponent(0.2).setFill(); bounds.fill()
        ("Drag synthetic email to Paperloft" as NSString).draw(at: NSPoint(x: 20, y: 65), withAttributes: [.font: NSFont.systemFont(ofSize: 16)])
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { record("MOUSE_DOWN") }
    override func mouseDragged(with event: NSEvent) {
        record("DRAG_STARTED")
        let provider = NSFilePromiseProvider(fileType: "com.apple.mail.email", delegate: self)
        let item = NSDraggingItem(pasteboardWriter: provider)
        let image = NSImage(size: NSSize(width: 160, height: 40), flipped: false) { rect in
            NSColor.systemGreen.setFill(); rect.fill(); return true
        }
        item.setDraggingFrame(NSRect(x: 50, y: 55, width: 160, height: 40), contents: image)
        beginDraggingSession(with: [item], event: event, source: self)
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        record("DRAG_ENDED at \(Int(screenPoint.x)),\(Int(screenPoint.y)) operation \(operation.rawValue)")
    }
    func filePromiseProvider(_ provider: NSFilePromiseProvider, fileNameForType type: String) -> String { "synthetic-receipt.eml" }
    nonisolated func filePromiseProvider(_ provider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping ((any Error)?) -> Void) {
        do { try bytes.write(to: url, options: .withoutOverwriting); Task { @MainActor in self.record("PROMISE_DELIVERED") }; completionHandler(nil) }
        catch { Task { @MainActor in self.record("PROMISE_FAILED: \(error)") }; completionHandler(error) }
    }
}
let application = NSApplication.shared
application.setActivationPolicy(.regular)
let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let window = NSWindow(contentRect: NSRect(x: 30, y: 120, width: 300, height: 150), styleMask: [.titled, .closable], backing: .buffered, defer: false)
window.title = "Synthetic email promise"
window.contentView = Source(bytes: data)
window.makeKeyAndOrderFront(nil)
application.activate()
application.run()
