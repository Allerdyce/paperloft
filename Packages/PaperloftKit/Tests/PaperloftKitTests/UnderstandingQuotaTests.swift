import XCTest
@testable import PaperloftKit

final class UnderstandingQuotaTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(secondsFromGMT: 0)!; return value
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    func testTwentySixthBlockedSamplesExemptAndRetryIdempotent() {
        var quota = UnderstandingQuota()
        let now = date("2026-09-30T23:59:00Z")
        for _ in 0..<30 { quota.recordUnderstanding(id: UUID(), sample: true, at: now, calendar: calendar) }
        XCTAssertEqual(quota.count(at: now, calendar: calendar), 0)
        let ids = (0..<25).map { _ in UUID() }
        for id in ids {
            XCTAssertTrue(quota.canUnderstand(id: id, sample: false, isPro: false, at: now, calendar: calendar))
            quota.recordUnderstanding(id: id, sample: false, at: now, calendar: calendar)
            quota.recordUnderstanding(id: id, sample: false, at: now, calendar: calendar)
        }
        XCTAssertEqual(quota.count(at: now, calendar: calendar), 25)
        XCTAssertFalse(quota.canUnderstand(id: UUID(), sample: false, isPro: false, at: now, calendar: calendar))
        XCTAssertTrue(quota.canUnderstand(id: ids[0], sample: false, isPro: false, at: now, calendar: calendar))
        XCTAssertTrue(quota.canUnderstand(id: UUID(), sample: true, isPro: false, at: now, calendar: calendar))
        XCTAssertTrue(quota.canUnderstand(id: UUID(), sample: false, isPro: true, at: now, calendar: calendar))
        XCTAssertEqual(quota.count(at: date("2026-10-01T00:00:00Z"), calendar: calendar), 0)
    }
    func testPersistenceAndCalendarYearBoundary() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("usage.json")
        var quota = try UnderstandingQuota.load(from: file)
        let now = date("2026-12-31T23:59:00Z")
        quota.recordUnderstanding(id: UUID(), sample: false, at: now, calendar: calendar)
        try quota.save(to: file)
        quota = try UnderstandingQuota.load(from: file)
        XCTAssertEqual(quota.count(at: now, calendar: calendar), 1)
        XCTAssertEqual(quota.count(at: date("2027-01-01T00:00:00Z"), calendar: calendar), 0)
        try Data("broken".utf8).write(to: file)
        XCTAssertThrowsError(try UnderstandingQuota.load(from: file))
    }
}
