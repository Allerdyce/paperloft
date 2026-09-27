import AppKit
import SwiftUI

/// A native drag destination around the existing content; mouse/keyboard controls remain native.
struct MailDropContainer<Content: View>: NSViewRepresentable {
    let model: AppModel
    @ViewBuilder var content: () -> Content
    func makeNSView(context: Context) -> MailDropHostingView<Content> {
        let receiver = MailPromiseReceiver(destination: model.support, ready: { model.intake([$0]) }, failed: { model.message = $0 })
        return MailDropHostingView(rootView: content(), receiver: receiver)
    }
    func updateNSView(_ view: MailDropHostingView<Content>, context: Context) { view.rootView = content() }
}

final class MailDropHostingView<Content: View>: NSHostingView<Content> {
    let receiver: MailPromiseReceiver
    init(rootView: Content, receiver: MailPromiseReceiver) {
        self.receiver = receiver
        super.init(rootView: rootView)
        setAccessibilityLabel("Receipt workspace and email drop destination")
        registerForDraggedTypes(NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
    }
    @MainActor required init(rootView: Content) { fatalError("Use the receiver initializer") }
    @MainActor required dynamic init?(coder: NSCoder) { nil }
    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        receiver.accepts(sender.draggingPasteboard) ? .copy : []
    }
    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool { receiver.accepts(sender.draggingPasteboard) }
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool { receiver.receive(sender.draggingPasteboard) }
}
