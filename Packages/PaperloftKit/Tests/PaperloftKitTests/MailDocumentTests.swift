import Foundation
import Testing
@testable import PaperloftKit

struct MailDocumentTests {
    private func parse(_ value: String) throws -> MailDocument { try MailDocument.parse(Data(value.utf8)) }
    private func mixed(_ children: [String], boundary: String = "BOUNDARY", type: String = "mixed") -> String {
        "Content-Type: multipart/\(type); boundary=\"\(boundary)\"\r\n\r\nPreamble\r\n" + children.map {
            "--\(boundary)\r\n\($0)\r\n"
        }.joined() + "--\(boundary)--\r\nEpilogue"
    }
    private var plain: String { "Content-Type: text/plain; charset=utf-8\r\n\r\nVendor: Café\r\nTotal: 12.50".replacingOccurrences(of: "\r\n\r\n", with: "\r\nContent-Transfer-Encoding: 8bit\r\n\r\n") }
    private var pdf: String {
        "Content-Type: application/pdf\r\nContent-Disposition: attachment; filename=\"../../secret.pdf\"\r\nContent-Transfer-Encoding: base64\r\n\r\n" + Data("%PDF-1.7\nsynthetic bytes\0\u{00ff}".utf8).base64EncodedString()
    }

    @Test func mailBodyAndPDFRemainExactAndSafe() throws {
        let result = try parse(mixed([plain, pdf]))
        #expect(result.body == "Vendor: Café\r\nTotal: 12.50")
        #expect(result.pdfs.count == 1)
        #expect(result.pdfs[0].data == Data("%PDF-1.7\nsynthetic bytes\0\u{00ff}".utf8))
        #expect(!result.pdfs[0].name.contains("/"))
        #expect(!result.pdfs[0].name.contains(".."))
        #expect(result.pdfs[0].name.hasSuffix(".pdf"))
    }

    @Test func alternativeDoesNotDuplicateBodyOrLoadHTML() throws {
        let html = "Content-Type: text/html\r\n\r\n<script>danger()</script><img src='https://invalid.test/tracker'>"
        let alternative = mixed([html, plain, plain], boundary: "ALT", type: "alternative")
        let result = try parse(mixed([alternative, pdf]))
        #expect(result.body == "Vendor: Café\r\nTotal: 12.50")
        #expect(result.pdfs.count == 1)
        #expect(result.notices.isEmpty)
        #expect(throws: MailDocument.Failure.self) { try parse(html) }
    }

    @Test func htmlBodyIsReadWithoutResourcesOrHiddenContent() throws {
        let html = "Content-Type: text/html; charset=utf-8\nContent-Transfer-Encoding: 8bit\n\n<head><title>Hidden</title><style>bad</style></head><body><script>evil()</script><!--ignore--><p>Caf&#xE9; &amp; Co</p><table><tr><td>Total</td><td>&euro;12.50</td></tr></table><img src='https://invalid.test/track?x=1>0'><div>Tax&nbsp;&#50;.00</div></body>"
        let result = try parse(html)
        #expect(result.body == "Café & Co\nTotal\n€12.50\nTax 2.00")
        #expect(!result.body.contains("invalid.test"))
        #expect(!result.body.contains("evil"))
        for hidden in ["<script>if (a < b) { run(); }</script>", "<template><template>ignore</template>Wrong Total: 999</template>", "<head><style>a > b { color: red }</style><script>if (x < y) run()</script></head>"] {
            let value = try parse("Content-Type: text/html\n\n" + hidden + "<p>Total: 12.50</p>")
            #expect(value.body == "Total: 12.50")
        }
        #expect(try parse("Content-Type: text/html\n\n<p>Caf&eacute; &mdash; &pound;5</p>").body == "Café — £5")
        #expect(throws: MailDocument.Failure.self) { try parse("Content-Type: text/html\n\n<p>&unknown;</p>") }
        for fragment in ["<!--", "<p title='unterminated", "<script>hidden"] {
            #expect(throws: MailDocument.Failure.self) { try parse("Content-Type: text/html\n\n" + fragment) }
        }
    }

    @Test func genericBinaryPDFAttachmentRequiresNameAndSignature() throws {
        let generic = pdf.replacingOccurrences(of: "application/pdf", with: "application/octet-stream")
        #expect(try parse(generic).pdfs.count == 1)
        let invalid = "Content-Type: application/octet-stream\nContent-Disposition: attachment; filename=test.pdf\n\nnot PDF"
        #expect(throws: MailDocument.Failure.self) { try parse(invalid) }
        let unnamed = "Content-Type: application/octet-stream\n\n%PDF-1.7"
        #expect(throws: MailDocument.Failure.self) { try parse(unnamed) }
    }

    @Test func transferEncodingsAndCharsets() throws {
        let qp = try parse("Content-Type: text/plain;\r\n charset=utf-8\r\nContent-Transfer-Encoding: quoted-printable\r\n\r\nCaf=C3=A9=20=\r\nTotal=3A 5")
        #expect(qp.body == "Café Total: 5")
        let latin = try parse("Content-Type: text/plain; charset=iso-8859-1\nContent-Transfer-Encoding: base64\n\nQ2Fm6Q==")
        #expect(latin.body == "Café")
        #expect(try parse("Subject: Receipt\n\nTotal: 5").body == "Total: 5")
        #expect(try parse("Content-Type: text/plain\nContent-Transfer-Encoding: base64\n\nVG90\r\nYWw6IDU=\t ").body == "Total: 5")
    }

    @Test func malformedEncodingAndHeadersAreRejected() {
        for value in [
            "no headers", "Bad Header\n\nbody", " folded\n\nbody",
            "Content-Type: text/plain\nContent-Type: text/html\n\nbody",
            "Content-Type: text/plain; charset=\"utf-8\n\nbody",
            "Content-Type: text/plain; charset=utf-8; charset=ascii\n\nbody",
            "Content-Transfer-Encoding: base64\n\nYWJj!",
            "Content-Transfer-Encoding: quoted-printable\n\nabc=QZ",
            "Content-Transfer-Encoding: quoted-printable\n\nabc=",
            "Content-Transfer-Encoding: rot13\n\nabc",
            "Content-Type: text/plain; charset=unknown\n\nabc",
            "Content-Type: application/pdf\n\nnot PDF",
            "Content-Type: multipart/mixed; boundary=x\n\n--x\n\nabc",
            "Content-Type: multipart/mixed; boundary=x\nContent-Transfer-Encoding: base64\n\nabc"
        ] { #expect(throws: MailDocument.Failure.self) { try parse(value) } }
    }

    @Test func boundariesMustBeWholeLinesAndBinaryIsPreserved() throws {
        let body = "Content-Type: text/plain\r\n\r\nText --BOUNDARY inside\r\n--BOUNDARYsuffix\r\nEnd"
        #expect(try parse(mixed([body])).body == "Text --BOUNDARY inside\r\n--BOUNDARYsuffix\r\nEnd")
        var message = Data("Content-Type: application/pdf\r\nContent-Transfer-Encoding: binary\r\n\r\n%PDF-1.7\r\n".utf8)
        message.append(contentsOf: [0, 255, 128, 10, 13])
        #expect(try MailDocument.parse(message).pdfs[0].data.suffix(5) == Data([0, 255, 128, 10, 13]))
    }

    @Test func allResourceBoundsAreEnforced() {
        #expect(throws: MailDocument.Failure.self) { try MailDocument.parse(Data(repeating: 65, count: MailDocument.maximumBytes + 1)) }
        #expect(throws: MailDocument.Failure.self) { try parse("Subject: " + String(repeating: "x", count: 65_536) + "\n\nbody") }
        #expect(throws: MailDocument.Failure.self) { try parse("Subject: text\n\n" + String(repeating: "x", count: MailDocument.maximumBodyBytes + 1)) }
        #expect(throws: MailDocument.Failure.self) { try parse("Content-Type: application/pdf\n\n%PDF-" + String(repeating: "x", count: MailDocument.maximumPDFBytes)) }
        #expect(throws: MailDocument.Failure.self) { try parse(mixed(Array(repeating: plain, count: 101))) }
        #expect(throws: MailDocument.Failure.self) { try parse(mixed(Array(repeating: pdf, count: 21))) }
        var nested = plain
        for index in 0...MailDocument.maximumDepth { nested = mixed([nested], boundary: "b\(index)") }
        #expect(throws: MailDocument.Failure.self) { try parse(nested) }
    }

    @Test func unsupportedAttachmentsNeverBecomeBody() throws {
        let text = "Content-Type: text/plain\nContent-Disposition: attachment; filename=invoice.txt\n\nWrong total 100"
        let result = try parse(mixed([plain, text, "Content-Type: image/png\n\nnot an image"]))
        #expect(result.body == "Vendor: Café\r\nTotal: 12.50")
        #expect(result.pdfs.isEmpty)
        #expect(result.notices.count == 2)
    }
}
