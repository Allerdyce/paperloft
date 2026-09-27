import Foundation
import Testing
import PDFKit
@testable import PaperloftKit

struct MailImportTests {
    private func workspace() throws -> URL {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/MailImportTests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    @Test func materializedBodyAndAttachmentsAreExactUniqueAndLeaveEmailUntouched() throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        let pdf = try MailImport.bodyPDF("Receipt attachment\nTotal: 14.50")
        let email = Data(("Content-Type: multipart/mixed; boundary=m\r\n\r\n--m\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: 8bit\r\n\r\nCafé 東京\r\nTotal: 14.50\r\n--m\r\nContent-Type: application/pdf\r\nContent-Disposition: attachment; filename=../../overwrite.pdf\r\nContent-Transfer-Encoding: base64\r\n\r\n" + pdf.base64EncodedString() + "\r\n--m\r\nContent-Type: image/png\r\n\r\nignored\r\n--m--\r\n").utf8)
        let source = root.appendingPathComponent("receipt.eml"); try email.write(to: source)
        let first = try MailImport.materialize(source: source, destination: root)
        let second = try MailImport.materialize(source: source, destination: root)
        #expect(first.documents.count == 2)
        #expect(Set(first.documents).isDisjoint(with: Set(second.documents)))
        #expect(try Data(contentsOf: first.documents[1]) == pdf)
        #expect(try Data(contentsOf: second.documents[1]) == pdf)
        let text = try #require(PDFDocument(url: first.documents[0])?.string)
        #expect(text.contains("Café 東京")); #expect(text.contains("Total: 14.50"))
        #expect(first.notices.contains { $0.contains("original email is unchanged") })
        #expect(first.notices.contains { $0.contains("image/png") })
        #expect(try Data(contentsOf: source) == email)
        #expect(!FileManager.default.fileExists(atPath: root.deletingLastPathComponent().appendingPathComponent("overwrite.pdf").path))
    }
    @Test func bodyPDFPaginatesWithoutDroppingLastLine() throws {
        let body = (0..<180).map { "Receipt line \($0): Coffee & supplies 12.50" }.joined(separator: "\n")
        let pdf = try #require(PDFDocument(data: MailImport.bodyPDF(body)))
        #expect(pdf.pageCount > 1)
        let text = try #require(pdf.string)
        for i in 0..<180 { #expect(text.contains("Receipt line \(i): Coffee & supplies 12.50")) }
    }
    @Test func promisedSnapshotRejectsEscapesSymlinksAndWrongTypes() throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("received")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let original = root.appendingPathComponent("outside.eml"), data = Data("Subject: Receipt\n\nTotal: 5".utf8)
        try data.write(to: original)
        #expect(throws: MailDocument.Failure.self) { try MailImport.snapshotPromisedEmail(original, in: folder) }
        let alias = folder.appendingPathComponent("link.eml")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: original)
        #expect(throws: MailDocument.Failure.self) { try MailImport.snapshotPromisedEmail(alias, in: folder) }
        let wrong = folder.appendingPathComponent("image.png"); try data.write(to: wrong)
        #expect(throws: MailDocument.Failure.self) { try MailImport.snapshotPromisedEmail(wrong, in: folder) }
        let email = folder.appendingPathComponent("receipt.eml"); try data.write(to: email)
        let first = try MailImport.snapshotPromisedEmail(email, in: folder)
        let second = try MailImport.snapshotPromisedEmail(email, in: folder)
        #expect(first != second)
        #expect(try Data(contentsOf: first) == data)
        #expect(try Data(contentsOf: email) == data)
    }

    @Test func boundedReadRejectsSparseOversizeSymlinkAndMalformedEmailWithoutOutput() throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("large.eml")
        #expect(FileManager.default.createFile(atPath: source.path, contents: nil))
        let file = try FileHandle(forWritingTo: source)
        try file.truncate(atOffset: UInt64(MailDocument.maximumBytes + 1)); try file.close()
        #expect(throws: MailDocument.Failure.self) { try MailImport.readBounded(source) }
        let alias = root.appendingPathComponent("alias.eml")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: source)
        #expect(throws: MailDocument.Failure.self) { try MailImport.readBounded(alias) }
        for (i, value) in ["malformed", "Content-Type: image/png\n\nnone", "Content-Type: application/pdf\n\n%PDF-corrupt"].enumerated() {
            let url = root.appendingPathComponent("bad\(i).eml"), data = Data(value.utf8)
            try data.write(to: url)
            let before = try FileManager.default.contentsOfDirectory(atPath: root.path)
            #expect(throws: MailDocument.Failure.self) { try MailImport.materialize(source: url, destination: root) }
            #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == before)
            #expect(try Data(contentsOf: url) == data)
        }
    }
}
