import XCTest
import AppIntents
import PaperloftKit

@MainActor final class IntentLogicTests: XCTestCase {
    final class Service: PaperloftIntentService {
        var isPro = false
        var queued: [(Data, String)] = []
        var exports = 0
        var inboxOpens = 0
        var receipts: [Receipt] = []
        func queueDocumentForReview(data: Data, filename: String) async throws { queued.append((data, filename)) }
        func exportAccountantPack(range: ExportDateRange) async throws -> URL { exports += 1; return URL(fileURLWithPath: "/tmp/pack.zip") }
        func intentReceipts() async throws -> [Receipt] { receipts }
        func openIntentInbox() async throws { inboxOpens += 1 }
    }
    func receipt(_ currency: String, _ amount: Int64, date: String = "2026-09-01", category: String = "Meals") throws -> Receipt {
        try Receipt(vendor: "Example", date: ReceiptDate(iso8601: date), totalMinorUnits: amount, currency: currency, category: category)
    }
    func testTotalsKeepCurrenciesSeparateAndFilter() throws {
        let receipts = try [receipt("USD", 123), receipt("EUR", 234), receipt("USD", 77), receipt("JPY", 500), receipt("USD", 900, date: "2025-12-31"), receipt("USD", 99, category: "Travel")]
        XCTAssertEqual(try IntentSpending.summary(receipts: receipts, category: " meals ", range: .year(2026)), "EUR 2.34; JPY 500; USD 2.00")
        XCTAssertEqual(try IntentSpending.summary(receipts: receipts, category: "Missing", range: .year(2026)), "No filed documents match this category and period.")
    }
    func testTotalsRejectOverflow() throws {
        let receipts = try [receipt("USD", Int64.max), receipt("USD", 1)]
        XCTAssertThrowsError(try IntentSpending.summary(receipts: receipts, category: nil, range: .year(2026)))
    }
    func testPeriodBoundariesAndLeapYear() throws {
        let now = ISO8601DateFormatter().date(from: "2024-03-01T12:00:00Z")!
        let range = try SpendingPeriod.lastMonth.range(now: now, timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertEqual(range.start.formatted, "2024-02-01")
        XCTAssertEqual(range.end.formatted, "2024-02-29")
        let prior = try SpendingPeriod.lastYear.range(now: now)
        XCTAssertEqual(prior.start.formatted, "2023-01-01")
        XCTAssertEqual(prior.end.formatted, "2023-12-31")
    }
    func testFileQueuesReviewWithoutClaimingFiled() async throws {
        let service = Service(); PaperloftIntentRuntime.service = service
        defer { PaperloftIntentRuntime.service = nil }
        let intent = FileDocumentIntent(); intent.document = IntentFile(data: Data([1, 2]), filename: "../../receipt.pdf", type: .pdf)
        let result = try await intent.perform()
        XCTAssertEqual(result.value, "Queued for review")
        XCTAssertEqual(service.queued.count, 1)
        XCTAssertEqual(service.queued.first?.1, "receipt.pdf")
        XCTAssertEqual(service.inboxOpens, 1)
    }
    func testFileRejectsEmptyAndUnsupportedInputs() async throws {
        let service = Service(); PaperloftIntentRuntime.service = service
        defer { PaperloftIntentRuntime.service = nil }
        for (data, filename) in [(Data(), "empty.pdf"), (Data([1]), "script.sh")] {
            let intent = FileDocumentIntent(); intent.document = IntentFile(data: data, filename: filename)
            do { _ = try await intent.perform(); XCTFail("Unsafe input was accepted") } catch { }
        }
        XCTAssertTrue(service.queued.isEmpty)
    }
    func testExportEnforcesProAndValidDates() async throws {
        let service = Service(); PaperloftIntentRuntime.service = service
        defer { PaperloftIntentRuntime.service = nil }
        let intent = ExportAccountantPackIntent(); intent.startDate = "2026-01-01"; intent.endDate = "2026-12-31"
        do { _ = try await intent.perform(); XCTFail("Free export accepted") } catch { XCTAssertTrue(error is PaperloftIntentError) }
        XCTAssertEqual(service.exports, 0)
        service.isPro = true
        _ = try await intent.perform()
        XCTAssertEqual(service.exports, 1)
        intent.startDate = "2027-01-01"
        do { _ = try await intent.perform(); XCTFail("Reversed range accepted") } catch { }
        XCTAssertEqual(service.exports, 1)
    }
    func testOpenInboxAndTotalUseInjectedService() async throws {
        let service = Service(); service.receipts = try [receipt("USD", 123)]
        PaperloftIntentRuntime.service = service
        defer { PaperloftIntentRuntime.service = nil }
        _ = try await OpenInboxIntent().perform()
        XCTAssertEqual(service.inboxOpens, 1)
        let total = TotalSpentIntent(); total.period = .allTime
        let result = try await total.perform()
        XCTAssertEqual(result.value, "USD 1.23")
    }
    func testURLDocumentReadIsBoundedAndPreservesInput() async throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("build/IntentTransferTests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("receipt.pdf")
        try Data([1, 2, 3]).write(to: url)
        let loaded = try await IntentDocumentInput.load(IntentFile(fileURL: url, type: .pdf))
        XCTAssertEqual(loaded, Data([1, 2, 3]))
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(IntentDocumentInput.maximumBytes + 1))
        try handle.close()
        do {
            _ = try await IntentDocumentInput.load(IntentFile(fileURL: url, type: .pdf))
            XCTFail("Oversized URL accepted")
        } catch { XCTAssertTrue(error is PaperloftIntentError) }
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int, IntentDocumentInput.maximumBytes + 1)
    }
    func testMissingServiceFailsClearly() async {
        PaperloftIntentRuntime.service = nil
        do { _ = try await OpenInboxIntent().perform(); XCTFail("Missing service accepted") } catch { XCTAssertTrue(error is PaperloftIntentError) }
    }
}
