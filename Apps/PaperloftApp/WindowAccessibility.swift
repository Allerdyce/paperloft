import AppKit
import SwiftUI

/// SwiftUI supplies labels for its own elements, but its AppKit hosting content
/// group also needs a name when VoiceOver enters a window.
struct WindowAccessibility: NSViewRepresentable {
    /// `.window` labels the window's content; `.panel` also labels the window itself (a menu bar
    /// extra's panel has no title for VoiceOver otherwise).
    enum Target { case window, panel, splitPane }
    let label: String
    var target: Target = .window
    func makeNSView(context: Context) -> WindowLabelView { WindowLabelView(label: label, target: target) }
    func updateNSView(_ view: WindowLabelView, context: Context) {
        view.label = label; view.target = target
        view.applyLabel()
    }
}

final class WindowLabelView: NSView {
    var label: String
    var target: WindowAccessibility.Target
    init(label: String, target: WindowAccessibility.Target) {
        self.label = label; self.target = target
        super.init(frame: .zero)
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { nil }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyLabel()
    }
    override func viewDidMoveToSuperview() { super.viewDidMoveToSuperview(); applyLabel() }
    func applyLabel() {
        if target == .panel { window?.setAccessibilityLabel(label) }
        if target == .window || target == .panel { window?.contentView?.setAccessibilityLabel(label); return }
        var child: NSView = self
        while let parent = child.superview {
            if parent is NSSplitView { return }
            parent.setAccessibilityLabel(label)
            child = parent
        }
    }
}
