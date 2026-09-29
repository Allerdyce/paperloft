import Foundation
import Testing
@testable import PaperloftKit

struct MailDeliveryLedgerTests {
    private func folder() throws -> URL {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/MailDeliveryTests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test func committedMessageIDSurvivesRelaunchEvenWhenMessageBytesDiffer() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let first = try MailDocument.parse(Data("Message-ID: <same@example.invalid>\r\nContent-Type: text/plain\r\n\r\nReceipt first representation".utf8))
        let second = try MailDocument.parse(Data("Message-ID: <same@example.invalid>\r\nContent-Type: text/plain\r\n\r\nReceipt different representation".utf8))
        #expect(first.body != second.body)
        let ledger = try MailDeliveryLedger(directory: root)
        let proof = try #require(MailDeliveryLedger.proof(messageID: first.envelope?.messageID))
        #expect(try await ledger.committedDelivery(messageID: first.envelope?.messageID) == nil)
        try await ledger.commit(proof)
        let reopened = try MailDeliveryLedger(directory: root)
        #expect(try await reopened.committedDelivery(messageID: second.envelope?.messageID) == proof.deliveryID)
        #expect(try await reopened.committedDelivery(messageID: "<other@example.invalid>") == nil)
        let stored = try String(contentsOf: root.appendingPathComponent("mail-deliveries.json"), encoding: .utf8)
        #expect(!stored.contains("example.invalid"))
    }

    @Test func failedAndCancelledAttemptsRemainRetryableAcrossRelaunch() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        // Producing a proof is an attempt, not an acknowledgment. Extraction, rendering,
        // cancellation or inbox persistence failure must never commit it.
        let attempt = try #require(MailDeliveryLedger.proof(messageID: "<retry@example.invalid>"))
        let ledger = try MailDeliveryLedger(directory: root)
        #expect(try await ledger.committedDelivery(messageID: "<retry@example.invalid>") == nil)
        let reopened = try MailDeliveryLedger(directory: root)
        #expect(try await reopened.committedDelivery(messageID: "<retry@example.invalid>") == nil)
        let successful = try #require(MailDeliveryLedger.proof(messageID: "<retry@example.invalid>"))
        #expect(successful.deliveryID != attempt.deliveryID)
        try await reopened.commit(successful)
        #expect(try await ledger.committedDelivery(messageID: "<retry@example.invalid>") == successful.deliveryID)
    }

    @Test func durableInboxProofCanBeReplayedAfterCrashBeforeLedgerCommit() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let proof = try #require(MailDeliveryLedger.proof(messageID: "<crash@example.invalid>"))
        let snapshot = root.appendingPathComponent("synthetic-inbox-proof.json")
        try JSONEncoder().encode(proof).write(to: snapshot, options: .atomic)
        // Simulate relaunch after durable inbox write, before ledger write.
        let reopened = try MailDeliveryLedger(directory: root)
        let restored = try JSONDecoder().decode(MailDeliveryLedger.Proof.self, from: Data(contentsOf: snapshot))
        #expect(try await reopened.commit(restored) == proof.deliveryID)
        #expect(try await reopened.commit(restored) == proof.deliveryID)
        let competing = try #require(MailDeliveryLedger.proof(messageID: "<crash@example.invalid>"))
        #expect(try await reopened.commit(competing) == proof.deliveryID)
    }

    @Test func independentInstancesDoNotOverwriteEachOthersDeliveries() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let first = try MailDeliveryLedger(directory: root), second = try MailDeliveryLedger(directory: root)
        let a = try #require(MailDeliveryLedger.proof(messageID: "<a@example.invalid>"))
        let b = try #require(MailDeliveryLedger.proof(messageID: "<b@example.invalid>"))
        async let savedA = first.commit(a)
        async let savedB = second.commit(b)
        _ = try await (savedA, savedB)
        #expect(try await first.committedDelivery(messageID: "<b@example.invalid>") == b.deliveryID)
        #expect(try await second.committedDelivery(messageID: "<a@example.invalid>") == a.deliveryID)
    }

    @Test func corruptLedgerFailsClosedAndCanRetryAfterRestoration() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("mail-deliveries.json")
        let corrupt = Data("not a ledger".utf8); try corrupt.write(to: url)
        let ledger = try MailDeliveryLedger(directory: root)
        let proof = try #require(MailDeliveryLedger.proof(messageID: "<retry@example.invalid>"))
        await #expect(throws: MailDeliveryLedger.Failure.self) { try await ledger.commit(proof) }
        #expect(try Data(contentsOf: url) == corrupt)
        try FileManager.default.removeItem(at: url)
        #expect(try await ledger.committedDelivery(messageID: "<retry@example.invalid>") == nil)
        #expect(try await ledger.commit(proof) == proof.deliveryID)
    }

    @Test func unsafeOrOversizedLedgerIsNeverAcknowledged() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let outside = root.appendingPathComponent("preserved.json"), ledgerURL = root.appendingPathComponent("mail-deliveries.json")
        let original = Data("preserve me".utf8); try original.write(to: outside)
        try FileManager.default.createSymbolicLink(at: ledgerURL, withDestinationURL: outside)
        let ledger = try MailDeliveryLedger(directory: root)
        let proof = try #require(MailDeliveryLedger.proof(messageID: "<unsafe@example.invalid>"))
        await #expect(throws: MailDeliveryLedger.Failure.self) { try await ledger.commit(proof) }
        #expect(try Data(contentsOf: outside) == original)
        try FileManager.default.removeItem(at: ledgerURL)
        try Data(repeating: 32, count: 4 * 1024 * 1024 + 1).write(to: ledgerURL)
        await #expect(throws: MailDeliveryLedger.Failure.self) { try await ledger.committedDelivery(messageID: "<unsafe@example.invalid>") }
        await #expect(throws: MailDeliveryLedger.Failure.self) { try await ledger.commit(proof) }
    }

    @Test func malformedIDsNeverCollapseIntoOneDuplicateKey() {
        for invalid in [nil, "", "<>", "missing@example.invalid", "<with space@example.invalid>", "<a@example.invalid> <b@example.invalid>", "<no-domain>", "<@>", "<a@>", "<@b>"] as [String?] {
            #expect(MailDeliveryLedger.proof(messageID: invalid) == nil)
        }
        #expect(MailDeliveryLedger.proof(messageID: " <Same@example.invalid> \r\n")?.messageKey == MailDeliveryLedger.proof(messageID: "<Same@example.invalid>")?.messageKey)
        #expect(MailDeliveryLedger.proof(messageID: "<Same@example.invalid>")?.messageKey != MailDeliveryLedger.proof(messageID: "<same@example.invalid>")?.messageKey)
    }
}
