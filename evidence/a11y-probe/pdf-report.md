# Native PDF page label diagnostic

Result: a public AppKit accessibility-label setter removes the synthetic PDF page's missing-description finding while preserving native PDFKit text descendants. This is a scoped workaround finding, not a passing full audit: unnamed host Group and TouchBar failures remain in both cases.

## Evidence

- macOS 27.0 / Xcode 27.0, standalone Apple-only probe, synthetic PDF drawn from local literal text (no user documents).
- Baseline: Other/page missing description, host Group missing description, TouchBar missing description.
- Initial label `Synthetic receipt page`: page missing-description changed to duplicate-role-description. Do not repeat role word in label.
- Refined label `Synthetic receipt, 1 of 1`: page issue disappears; only Group and TouchBar remain. Both XCTest cases still fail honestly; handler always returns false and audit uses default .all.
- Page proxy conforms to public `NSAccessibilityProtocol`. Runtime diagnostic class name is recorded only as evidence; code does not match it, subclass it, or invoke private selectors.
- Native page has one immediate child before and after setting the label. Its nested native StaticText remains in the XCUI tree; value begins `Synthetic receipt` before and after.
- Fresh inspection after another UI button click retains the new label in the XCUI tree and audit. Curiously, the object's direct accessibilityLabel getter still returns nil, so getter round-trip is not a reliable persistence assertion for this node.
- Not tested: persistence across zoom, scrolling into newly-created pages, document replacement or re-created accessibility nodes. Product integration should reapply for newly generated page nodes and validate multiple pages/text navigation.

Result bundles: evidence/a11y-probe/PDFProbe.xcresult (initial) and evidence/a11y-probe/PDFRefinedProbe.xcresult (refined).
Logs: pdf-build.log, pdf-test.log, pdf-refined-build.log, pdf-refined-test.log.
Exported refined attachments: pdf-attachments/manifest.json and listed image/text/video files.
Exact test source: Tools/AccessibilityProbe/Tests/PDFProbeTests.swift.

## Public APIs and implementation guidance

The local SDK declares writable label, children and role on NSAccessibility (Swift name NSAccessibilityProtocol), in AppKit NSAccessibilityProtocols.h lines 410, 386 and 314. NSAccessibilityPageRole is public at NSAccessibilityConstants.h line 552; Swift imports it as `.pageRole`.

Traverse only the owned PDFView subtree, using typed protocol casts, identity cycle protection and `.pageRole`. Set a descriptive document name plus accurate page position if known; do not infer PDF indices from an arbitrary traversal counter. Keep children, role, value, text and actions intact. No need to hide or replace nodes. Apply after PDFKit has constructed the page accessibility tree; a call too early cannot label absent nodes.

PDFPage itself is not the rendered accessibility page proxy. Its readonly label/pageClass APIs are therefore not needed for this proven approach. Only one genuine setter approach was tried, with a label-text refinement; no private APIs or suppression were used.

## Exact standalone source

```swift
import SwiftUI
import PDFKit

@MainActor final class PDFProbeController: ObservableObject {
    let view = PDFView()
    @Published var report = "Not inspected"
    init() {
        let page = SyntheticPage(frame: NSRect(x: 0, y: 0, width: 500, height: 600))
        view.document = PDFDocument(data: page.dataWithPDF(inside: page.bounds))
        view.autoScales = true
        view.setAccessibilityLabel("Synthetic document preview")
    }
    func inspect(label: Bool) {
        var seen = Set<ObjectIdentifier>()
        var rows: [String] = []
        func visit(_ object: Any) {
            guard let element = object as? any NSAccessibilityProtocol else {
                rows.append("nonconforming \(type(of: object))")
                return
            }
            guard seen.insert(ObjectIdentifier(element)).inserted else { return }
            let role = element.accessibilityRole()?.rawValue ?? "nil"
            if element.accessibilityRole() == .pageRole {
                let before = element.accessibilityLabel() ?? "nil"
                let childrenBefore = element.accessibilityChildren()?.count ?? 0
                if label && (element.accessibilityLabel() ?? "").isEmpty {
                    element.setAccessibilityLabel("Synthetic receipt, 1 of 1")
                }
                rows.append("PAGE \(type(of: element)) before=\(before) after=\(element.accessibilityLabel() ?? "nil") children=\(childrenBefore)/\(element.accessibilityChildren()?.count ?? 0)")
            } else { rows.append("\(type(of: element)) \(role)") }
            for child in element.accessibilityChildren() ?? [] { visit(child) }
        }
        visit(view)
        report = rows.joined(separator: "\n")
    }
}

@MainActor final class SyntheticPage: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill(); bounds.fill()
        ("Synthetic receipt\nExample Store\nTotal USD 12.34" as NSString).draw(in: NSRect(x: 40, y: 300, width: 400, height: 200), withAttributes: [.font: NSFont.systemFont(ofSize: 20), .foregroundColor: NSColor.black])
    }
}
struct PDFProbePanel: View {
    @StateObject private var controller = PDFProbeController()
    var body: some View {
        VStack {
            HStack {
                Button("Inspect pages") { controller.inspect(label: false) }
                Button("Label pages") { controller.inspect(label: true) }
            }
            PDFProbeRepresentable(view: controller.view)
            Text(controller.report).font(.system(size: 10)).accessibilityIdentifier("pdf.report")
        }.frame(width: 700, height: 750)
    }
}
struct PDFProbeRepresentable: NSViewRepresentable {
    let view: PDFView
    func makeNSView(context: Context) -> PDFView { view }
    func updateNSView(_ nsView: PDFView, context: Context) {}
}

```
