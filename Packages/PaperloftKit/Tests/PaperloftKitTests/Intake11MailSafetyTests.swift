import Foundation
import Testing
import PDFKit
import Darwin
@testable import PaperloftKit

struct Intake11MailSafetyTests {
    private func workspace() throws -> URL {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/Intake11MailSafety/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test func forwardedMessagesPreserveBodiesAndPDFBytesAcrossEncodings() throws {
        let attachment = Data("%PDF-1.7\nSynthetic attachment".utf8)
        let nested = "Content-Type: multipart/mixed; boundary=inner\r\n\r\n--inner\r\nContent-Type: text/plain\r\n\r\nSynthetic receipt Total 25.00\r\n--inner\r\nContent-Type: application/pdf\r\nContent-Transfer-Encoding: base64\r\n\r\n\(attachment.base64EncodedString())\r\n--inner--\r\n"
        for encoding in ["7bit", "8bit", "base64"] {
            let body = encoding == "base64" ? Data(nested.utf8).base64EncodedString() : nested
            let message = "Subject: Forwarded receipt\nContent-Type: message/rfc822\nContent-Transfer-Encoding: \(encoding)\n\n" + body
            let result = try MailDocument.parse(Data(message.utf8))
            #expect(result.body.contains("Synthetic receipt Total 25.00"))
            #expect(result.pdfs.map(\.data) == [attachment])
            #expect(result.envelope?.subject == "Forwarded receipt")
        }
        var message = "Content-Type: text/plain\n\nTotal 25.00"
        for _ in 0...MailDocument.maximumDepth { message = "Content-Type: message/rfc822\n\n" + message }
        #expect(throws: MailDocument.Failure.self) { try MailDocument.parse(Data(message.utf8)) }
    }

    @Test func envelopeEncodedWordsAreDisplayMetadataWithoutReplacingBody() throws {
        for subject in ["=?UTF-8?B?Q2Fmw6k=?=", "=?UTF-8?Q?Caf=C3=A9?=", "=?ISO-8859-1?Q?Caf=E9?="] {
            let message = "From: Synthetic Shop <receipts@example.invalid>\nTo: Customer <customer@example.invalid>\nDate: Sun, 27 Sep 2026 12:00:00 +0000\nSubject: \(subject)\nMessage-ID: <synthetic@example.invalid>\nContent-Type: text/plain\n\nTotal 25.00"
            let result = try MailDocument.parse(Data(message.utf8))
            #expect(result.envelope?.subject == "Café")
            #expect(result.envelope?.messageID == "<synthetic@example.invalid>")
            #expect(result.envelope?.from?.contains("Synthetic Shop") == true)
            #expect(result.body == "Total 25.00")
        }
        let folded = "Subject: =?UTF-8?Q?One?=\n =?UTF-8?Q?_Receipt?=\n\nTotal 1.00"
        #expect(try MailDocument.parse(Data(folded.utf8)).envelope?.subject == "One Receipt")
    }

    @Test func fiftyMiBMessageReadBoundaryAndRemoteHTMLRemainLocal() throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("sparse.eml")
        #expect(FileManager.default.createFile(atPath: source.path, contents: nil))
        let writer = try FileHandle(forWritingTo: source)
        try writer.truncate(atOffset: UInt64(50 * 1024 * 1024))
        #expect(try MailImport.readBounded(source).count == 50 * 1024 * 1024)
        try writer.truncate(atOffset: UInt64(50 * 1024 * 1024 + 1)); try writer.close()
        #expect(throws: MailDocument.Failure.self) { try MailImport.readBounded(source) }
        let html = "Subject: Synthetic Receipt\nContent-Type: text/html\n\n<head><link rel='stylesheet' href='https://example.invalid/style'><style>@import url(https://example.invalid/css)</style></head><script src='https://example.invalid/script'></script><img src='https://example.invalid/pixel'><iframe src='https://example.invalid/frame'></iframe><p>Total 25.00</p>"
        let email = root.appendingPathComponent("remote.eml"); try Data(html.utf8).write(to: email)
        let result = try MailImport.materialize(source: email, destination: root)
        let document = try #require(result.documents.first)
        let text = try #require(PDFDocument(url: document)?.string)
        #expect(text.contains("Total 25.00"))
        #expect(!text.contains("https://"))
        #expect(result.envelope?.subject == "Synthetic Receipt")
        // This verifies discarded remote references and selectable text. The
        // tokenizer/CoreText implementation has no resource-loading API; it does
        // not claim WebKit request-counter coverage required by the full 1.1 gate.
    }

    @Test func tenThousandBoundedMIMEMutationsFinishWithoutCrash() throws {
        let seed = Array("Subject: Synthetic\nContent-Type: multipart/mixed; boundary=x\n\n--x\nContent-Type: text/plain\n\nTotal 25.00\n--x--\n".utf8)
        let start = ContinuousClock.now
        for index in 0..<10_000 {
            var bytes = seed
            bytes[index % bytes.count] = UInt8(truncatingIfNeeded: index &* 37)
            if index % 3 == 0 { bytes.removeLast(index % 20) }
            _ = try? MailDocument.parse(Data(bytes))
        }
        #expect(start.duration(to: .now) < .seconds(120))
    }
}

struct Intake11WatchedSafetyTests {
    @Test func renamedIdentityUsesLatestHashInsteadOfHistoricalFilenameHash() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/Intake11Watch/" + UUID().uuidString)
        let watched = root.appendingPathComponent("watch")
        try FileManager.default.createDirectory(at: watched, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = watched.appendingPathComponent("a.pdf"), second = watched.appendingPathComponent("b.pdf")
        let scanner = try WatchedFolderScanner(root: watched, stateURL: root.appendingPathComponent("state.json"), minimumStableInterval: .milliseconds(10))
        func writeInPlace(_ data: Data, to url: URL) throws {
            if !FileManager.default.fileExists(atPath: url.path) { _ = FileManager.default.createFile(atPath: url.path, contents: nil) }
            let writer = try FileHandle(forWritingTo: url)
            defer { try? writer.close() }
            try writer.truncate(atOffset: 0); try writer.write(contentsOf: data); try writer.synchronize()
        }
        func candidate() async throws -> WatchedFolderScanner.Candidate {
            _ = try await scanner.scan()
            try await Task.sleep(for: .milliseconds(30))
            return try #require(try await scanner.scan().candidates.first)
        }
        try writeInPlace(Data("A".utf8), to: first)
        let a = try await candidate(); try await scanner.acknowledge(a)
        try FileManager.default.moveItem(at: first, to: second)
        try writeInPlace(Data("B".utf8), to: second)
        let b = try await candidate(); try await scanner.acknowledge(b)
        #expect(a.fileIdentity == b.fileIdentity)
        try FileManager.default.moveItem(at: second, to: first)
        try writeInPlace(Data("A".utf8), to: first)
        let returned = try await candidate()
        #expect(returned.fileIdentity == a.fileIdentity)
        #expect(returned.contentHash == a.contentHash)
        #expect(returned.contentHash != b.contentHash)
        try await scanner.acknowledge(returned)
        #expect(try await scanner.scan().candidates.isEmpty)
    }

    @Test func legacyFilenameHistoryStillSkipsUnchangedFileWithoutIdentity() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/Intake11Watch/" + UUID().uuidString)
        let watched = root.appendingPathComponent("watch"), state = root.appendingPathComponent("state.json")
        try FileManager.default.createDirectory(at: watched, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("legacy receipt".utf8).write(to: watched.appendingPathComponent("receipt.pdf"))
        var scanner: WatchedFolderScanner? = try WatchedFolderScanner(root: watched, stateURL: state, minimumStableInterval: .milliseconds(10))
        _ = try await scanner!.scan(); try await Task.sleep(for: .milliseconds(30))
        let scan = try await scanner!.scan()
        try await scanner!.acknowledge(try #require(scan.candidates.first))
        scanner = nil
        var history = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: state)) as? [String: Any])
        history.removeValue(forKey: "identities")
        try JSONSerialization.data(withJSONObject: history).write(to: state)
        scanner = try WatchedFolderScanner(root: watched, stateURL: state, minimumStableInterval: .milliseconds(10))
        _ = try await scanner!.scan(); try await Task.sleep(for: .milliseconds(30))
        #expect(try await scanner!.scan().candidates.isEmpty)
    }

    @Test func fiftyBurstFilesWaitForCompletionAndAcknowledgedRenameStaysConsumed() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/Intake11Watch/" + UUID().uuidString)
        let watched = root.appendingPathComponent("watch")
        try FileManager.default.createDirectory(at: watched, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var scanner: WatchedFolderScanner? = try WatchedFolderScanner(root: watched, stateURL: root.appendingPathComponent("state.json"))
        for burst in 0..<5 {
            for index in (burst * 10)..<(burst * 10 + 10) {
                try Data("partial".utf8).write(to: watched.appendingPathComponent("receipt-\(index).pdf"))
            }
            #expect(try await scanner!.scan().candidates.isEmpty)
        }
        for index in 0..<50 { try Data("complete receipt \(index)".utf8).write(to: watched.appendingPathComponent("receipt-\(index).pdf")) }
        #expect(try await scanner!.scan().candidates.isEmpty)
        let locked = open(watched.appendingPathComponent("receipt-49.pdf").path, O_WRONLY)
        #expect(locked >= 0); defer { close(locked) }
        #expect(flock(locked, LOCK_EX | LOCK_NB) == 0)
        try await Task.sleep(for: .milliseconds(2100))
        let first = try await scanner!.scan()
        #expect(first.candidates.count == 49)
        for candidate in first.candidates {
            #expect(String(data: candidate.data, encoding: .utf8)?.hasPrefix("complete receipt") == true)
            try await scanner!.acknowledge(candidate)
        }
        #expect(flock(locked, LOCK_UN) == 0)
        #expect(try await scanner!.scan().candidates.isEmpty)
        try await Task.sleep(for: .milliseconds(2100))
        let final = try await scanner!.scan()
        #expect(final.candidates.count == 1)
        try await scanner!.acknowledge(try #require(final.candidates.first))
        try FileManager.default.moveItem(at: watched.appendingPathComponent("receipt-0.pdf"), to: watched.appendingPathComponent("renamed.pdf"))
        scanner = nil
        scanner = try WatchedFolderScanner(root: watched, stateURL: root.appendingPathComponent("state.json"))
        #expect(try await scanner!.scan().candidates.isEmpty)
        try await Task.sleep(for: .milliseconds(2100))
        #expect(try await scanner!.scan().candidates.isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: watched.path).count == 50)
    }
}
