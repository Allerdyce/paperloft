import Foundation

/// One durable ledger per app installation, independent of the selected library.
/// Record only successful automatic understanding. Retrying an inbox UUID is idempotent.
public struct UnderstandingQuota: Codable, Sendable {
    public static let monthlyLimit = 25
    private var understood: [String: Set<UUID>] = [:]
    public init() {}
    private func month(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.era, .year, .month], from: date)
        return "\(parts.era ?? 1)-\(parts.year ?? 0)-\(parts.month ?? 0)"
    }
    public func count(at date: Date = .now, calendar: Calendar = .current) -> Int {
        understood[month(date, calendar: calendar), default: []].count
    }
    public func canUnderstand(id: UUID, sample: Bool, isPro: Bool, at date: Date = .now, calendar: Calendar = .current) -> Bool {
        sample || isPro || understood[month(date, calendar: calendar), default: []].contains(id) || count(at: date, calendar: calendar) < Self.monthlyLimit
    }
    public mutating func recordUnderstanding(id: UUID, sample: Bool, at date: Date = .now, calendar: Calendar = .current) {
        guard !sample else { return }
        understood[month(date, calendar: calendar), default: []].insert(id)
    }
    public static func load(from url: URL) throws -> Self {
        guard FileManager.default.fileExists(atPath: url.path) else { return Self() }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
    public func save(to url: URL) throws {
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
