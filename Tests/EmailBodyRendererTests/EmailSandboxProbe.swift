import AppKit
import Foundation
import PDFKit

/// Synthetic, headless probe intended to be signed with app-sandbox only.
/// No network entitlement, loopback listener, user file, or visible window.
@main struct EmailSandboxProbe {
    @MainActor static func main() async {
        NSApplication.shared.setActivationPolicy(.prohibited)
        do {
            let policy: OfflineEmailBodyRenderer.Policy = CommandLine.arguments.contains("--webkit-only") ? .webKitOnly : (CommandLine.arguments.contains("--native-only") ? .nativeOnly : .automatic)
            let renderer = OfflineEmailBodyRenderer(limits: .init(timeout: .seconds(10)), policy: policy)
            let result = try await renderer.render(.init(body: .plainText("Synthetic Shop\nTotal $12.34"), envelope: .init(subject: "Synthetic sandbox probe")))
            guard let document = PDFDocument(data: result.data), document.string?.contains("Total $12.34") == true else {
                print("FAIL invalid selectable text"); exit(1)
            }
            let lines = (1...95).map { "Synthetic receipt line \($0) Total 12.34" }.joined(separator: "\n")
            let paged = try await renderer.render(.init(body: .plainText(lines), envelope: .init(from: "Synthetic Sender", subject: "Synthetic header only")))
            guard let pages = PDFDocument(data: paged.data), pages.pageCount == 3 else { print("FAIL pagination"); exit(1) }
            for index in 1...95 {
                guard pages.string?.components(separatedBy: "Synthetic receipt line \(index) Total 12.34").count == 2 else { print("FAIL clipped or duplicate line"); exit(1) }
            }
            guard !paged.bodyText.contains("Synthetic header only"), paged.bodyText == lines,
                  pages.page(at: 0)?.string?.contains("Subject: Synthetic header only") == true else { print("FAIL header separation"); exit(1) }
            for index in 0..<3 {
                guard let page = pages.page(at: index), page.bounds(for: .mediaBox).size == CGSize(width: 612, height: 792) else { print("FAIL page size"); exit(1) }
            }
            let html = try await renderer.render(.init(body: .html("<head><style>@import url('https://example.invalid/no');</style><script>fetch('https://example.invalid/no')</script></head><p>Synthetic HTML receipt</p><img src='https://example.invalid/no'><table><tr><td>Total</td><td>&pound;23.40</td></tr></table>")))
            guard let htmlPDF = PDFDocument(data: html.data), htmlPDF.string?.contains("£23.40") == true,
                  !html.bodyText.contains("fetch"), html.blockedNavigationCount == 0 else { print("FAIL malicious HTML native rendering"); exit(1) }
            print("PASS sandbox malicious HTML: selectable total, scripts discarded, no navigation")
            print("PASS sandbox renderer engine=\(result.engine.rawValue) diagnostic=\(result.fallbackDiagnosticCode ?? 0); selectable header/body; 3 letter pages, all95 lines exactly once; header excluded from bodyText")
        } catch {
            let error = error as NSError
            // Fixed framework/renderer diagnostic metadata only, never email content.
            print("FAIL sandbox renderer domain=\(error.domain) code=\(error.code)")
            exit(1)
        }
    }
}
