import AppKit
import SwiftUI

/// Uses the standard AppKit popup menu and explicitly exposes its press action.
struct AccessiblePicker: View {
    let label: String
    let identifier: String
    let choices: [String]
    @Binding var selection: String
    /// Menu title for a stored value; values themselves are what the binding receives.
    var title: (String) -> String = { $0 }
    var body: some View {
        // LabeledContent puts the label in a Form's label column, like the text fields around it.
        LabeledContent(label) {
            AccessiblePopup(label: label, identifier: identifier, choices: choices, selection: $selection, title: title)
        }
    }
}

/// The pop-up alone, for rows that supply their own label (e.g. to outline just the control).
/// `label` is still its accessibility label.
struct AccessiblePopup: View {
    let label: String
    let identifier: String
    let choices: [String]
    @Binding var selection: String
    var title: (String) -> String = { $0 }
    var body: some View {
        NativePopup(label: label, identifier: identifier, choices: choices, selection: $selection, title: title)
            .popupTextBaselines()
            .frame(minWidth: 90, minHeight: 24)
    }
}

/// A compact filter using the same native menu/action as the form picker.
/// Keep the visible selection inside the control so keyboard and VoiceOver
/// users receive the same choices and selected value.
struct AccessibleFilterPicker: View {
    let label: String
    let identifier: String
    let choices: [String]
    @Binding var selection: String
    var body: some View {
        NativePopup(label: label, identifier: identifier, choices: choices, selection: $selection, isBordered: false)
            .popupTextBaselines()
            .frame(minWidth: 70, minHeight: 24)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }
}

private extension View {
    /// The pop-up's title baseline, 7 pt above its bottom edge (what AppKit reports for the
    /// 24 pt control). Stating it here keeps SwiftUI from asking the NSPopUpButton during
    /// every layout pass: each answer re-entered window layout, and the review form's three
    /// pop-ups held the main thread for over half a second when a document opened (AC-10).
    func popupTextBaselines() -> some View {
        alignmentGuide(.firstTextBaseline) { $0.height - 7 }
            .alignmentGuide(.lastTextBaseline) { $0.height - 7 }
    }
}

private struct NativePopup: NSViewRepresentable {
    let label: String
    let identifier: String
    let choices: [String]
    @Binding var selection: String
    var isBordered = true
    var title: (String) -> String = { $0 }
    @Environment(\.isEnabled) private var isEnabled
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
        let titles = choices.map(title)
        if button.itemTitles != titles || button.itemArray.map({ $0.representedObject as? String }) != choices {
            button.removeAllItems()
            for (value, text) in zip(choices, titles) {
                let item = NSMenuItem(title: text, action: nil, keyEquivalent: ""); item.representedObject = value
                button.menu?.addItem(item)
            }
            button.sizeInputsChanged()
        }
        if let index = choices.firstIndex(of: selection) { button.selectItem(at: index) } else { button.select(nil) }
        if button.isBordered != isBordered { button.isBordered = isBordered; button.sizeInputsChanged() }
        button.isEnabled = isEnabled && !choices.isEmpty
        button.setAccessibilityLabel(label)
        button.setAccessibilityIdentifier(identifier)
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
    }
    @MainActor final class Coordinator: NSObject {
        var selection: Binding<String>
        init(selection: Binding<String>) { self.selection = selection }
        @objc func changed(_ sender: NSPopUpButton) {
            if let value = sender.selectedItem?.representedObject as? String { selection.wrappedValue = value }
        }
    }
}

private final class PressablePopup: NSPopUpButton {
    /// Measuring means sizing every menu item (the currency menu has well over a hundred),
    /// and auto layout asks on every pass. The size changes only with the items or bezel.
    private var measuredSize: NSSize?
    func sizeInputsChanged() { measuredSize = nil; invalidateIntrinsicContentSize() }
    override var intrinsicContentSize: NSSize {
        if let measuredSize { return measuredSize }
        let size = super.intrinsicContentSize
        measuredSize = size
        return size
    }
    override func accessibilityPerformPress() -> Bool {
        guard isEnabled, numberOfItems > 0 else { return false }
        performClick(nil)
        return true
    }
}
