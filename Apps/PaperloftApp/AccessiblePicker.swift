import AppKit
import SwiftUI

/// Uses the standard AppKit popup menu and explicitly exposes its press action.
struct AccessiblePicker: View {
    let label: String
    let identifier: String
    let choices: [String]
    @Binding var selection: String
    var body: some View {
        HStack {
            Text(label).fixedSize()
            NativePopup(label: label, identifier: identifier, choices: choices, selection: $selection)
                .frame(minWidth: 90, minHeight: 24)
        }
    }
}

private struct NativePopup: NSViewRepresentable {
    let label: String
    let identifier: String
    let choices: [String]
    @Binding var selection: String
    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }
    func makeNSView(context: Context) -> PressablePopup {
        let button = PressablePopup(frame: .zero, pullsDown: false)
        button.target = context.coordinator
        button.action = #selector(Coordinator.changed(_:))
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return button
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: PressablePopup, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? nsView.intrinsicContentSize.width, height: 24)
    }
    func updateNSView(_ button: PressablePopup, context: Context) {
        context.coordinator.selection = $selection
        if button.itemTitles != choices { button.removeAllItems(); button.addItems(withTitles: choices) }
        button.selectItem(withTitle: selection)
        button.setAccessibilityLabel(label)
        button.setAccessibilityIdentifier(identifier)
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
    }
    @MainActor final class Coordinator: NSObject {
        var selection: Binding<String>
        init(selection: Binding<String>) { self.selection = selection }
        @objc func changed(_ sender: NSPopUpButton) {
            if let value = sender.titleOfSelectedItem { selection.wrappedValue = value }
        }
    }
}

private final class PressablePopup: NSPopUpButton {
    override func accessibilityPerformPress() -> Bool { performClick(nil); return true }
}
