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
