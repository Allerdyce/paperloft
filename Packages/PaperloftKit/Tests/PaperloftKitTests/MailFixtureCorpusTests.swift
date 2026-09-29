import Foundation
import PDFKit
import Testing
@testable import PaperloftKit

struct MailFixtureCorpusTests {
    struct Label: Decodable {
        struct ReceiptLabel: Decodable { let vendor: String; let date: String; let total: String; let kind: String }
        let id: String
        let group: String
        let expectedPDFParts: Int
        let bodyContains: String
        let receipt: ReceiptLabel?
    }
    @Test func corpusMixPartsSelectableTextAndSourcePreservation() throws {
        var repo = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { repo.deleteLastPathComponent() }
        let fixtures = repo.appendingPathComponent("Tests/MailFixtures")
        let lines = try String(contentsOf: fixtures.appendingPathComponent("labels.jsonl"), encoding: .utf8).split(separator: "\n")
        let labels = try lines.map { try JSONDecoder().decode(Label.self, from: Data($0.utf8)) }
        #expect(labels.count == 80)
        #expect(Dictionary(grouping: labels, by: \.group).mapValues(\.count) == ["pdf": 28, "body": 24, "mixed": 12, "not_receipt": 16])
        let destination = repo.appendingPathComponent("build/MailCorpus/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: destination) }
        for label in labels {
            let source = fixtures.appendingPathComponent(label.id + ".eml")
            let original = try Data(contentsOf: source)
            let mail = try MailDocument.parse(original)
            #expect(mail.pdfs.count == label.expectedPDFParts)
            #expect(mail.body.contains(label.bodyContains))
            #expect(mail.envelope?.messageID == "<\(label.id)@paperloft.example.invalid>")
            let imported = try MailImport.materialize(source: source, destination: destination)
            #expect(imported.attachments.count == label.expectedPDFParts)
            #expect(imported.bodyDocument != nil)
            for (index, attachment) in imported.attachments.enumerated() {
                #expect(try Data(contentsOf: attachment) == mail.pdfs[index].data)
                let pdf = try #require(PDFDocument(url: attachment))
                #expect(pdf.pageCount == 1)
                let text = try #require(pdf.string)
                if index == 0, let receipt = label.receipt {
                    #expect(text.contains(receipt.vendor))
                    #expect(text.contains(receipt.date))
                    #expect(text.contains(receipt.total))
                }
            }
            #expect(try Data(contentsOf: source) == original)
        }
    }
}
