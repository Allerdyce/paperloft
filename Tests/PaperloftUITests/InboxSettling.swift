import XCTest

extension XCUIApplication {
    /// Waits until Load Development Receipts has finished: no row says Processing and the Inbox count
    /// has stopped changing. The UI-test Inbox persists across tests, so the samples may already be
    /// there or may still be arriving one by one.
    @MainActor func waitForInboxToSettle(timeout: TimeInterval = 120, file: StaticString = #filePath, line: UInt = #line) {
        let processing = buttons["inbox.filter.Processing"], all = buttons["inbox.filter.All"]
        func count(_ chip: XCUIElement) -> String {
            guard chip.exists else { return "" }
            return (chip.label.isEmpty ? (chip.value as? String ?? "") : chip.label).filter(\.isNumber)
        }
        let deadline = Date().addingTimeInterval(timeout)
        var last = "", stableSince = Date()
        while Date() < deadline {
            let current = count(all)
            if current != last { last = current; stableSince = Date() }
            if count(processing) == "0", !current.isEmpty, Date().timeIntervalSince(stableSince) >= 2 { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTFail("the Inbox didn't settle: \(processing.label), \(all.label)", file: file, line: line)
    }
}
