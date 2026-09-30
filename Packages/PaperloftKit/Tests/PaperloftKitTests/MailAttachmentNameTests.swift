import Foundation
import Testing
@testable import PaperloftKit

/// QA-05: an email attachment shows in the Inbox under the sender's filename, sanitized, while
/// its staged path stays an unguessable UUID.
struct MailAttachmentNameTests {
    @Test func attachmentsCarrySanitizedDisplayNamesButUUIDPaths() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/MailAttachmentNameTests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let pdf = try MailImport.bodyPDF("Invoice 42\nTotal: 99.00")
        func part(_ disposition: String) -> String {
            "--m\r\nContent-Type: application/pdf\r\nContent-Disposition: attachment; \(disposition)\r\nContent-Transfer-Encoding: base64\r\n\r\n" + pdf.base64EncodedString() + "\r\n"
        }
        let email = Data(("Content-Type: multipart/mixed; boundary=m\r\n\r\n"
            + part("filename=\"Invoice 42 (Sept).pdf\"") + part("filename=../../etc/passwd.pdf") + "--m--\r\n").utf8)
        let source = root.appendingPathComponent("invoice.eml"); try email.write(to: source)
        let result = try MailImport.materialize(source: source, destination: root)
        #expect(result.attachments.count == 2)
        let names = result.attachments.compactMap { result.attachmentNames[$0] }
        #expect(names.count == 2)
        #expect(names.first == "Invoice 42 _Sept_.pdf", "readable name kept, punctuation made safe: \(names)")
        #expect(names.last?.hasSuffix("etc_passwd.pdf") == true && names.last?.contains("/") == false && names.last?.contains("..") == false,
                "path traversal is neutralised in the display name: \(names)")
        for url in result.attachments {
            #expect(url.lastPathComponent.hasPrefix("Attachment-"), "the path never uses the sender's name")
            #expect(url.deletingLastPathComponent().deletingLastPathComponent().path == root.path)
        }
    }
}
