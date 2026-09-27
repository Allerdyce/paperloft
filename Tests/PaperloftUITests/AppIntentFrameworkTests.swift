import XCTest
import AppIntents
import AppIntentsTesting

/// AC-15: these run through the system's out-of-process intent infrastructure.
/// Requires an installed app and test runner signed by the same development team.
/// No launch arguments, service substitutions, or direct perform() calls.
final class AppIntentFrameworkTests: XCTestCase {
    let definitions = IntentDefinitions(bundleIdentifier: "app.paperloft.receipts")

    @MainActor func launchApp() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    @MainActor func testOpenInbox() async throws {
        launchApp()
        _ = try await definitions.intents["OpenInboxIntent"].makeIntent().run()
    }
    @MainActor func testTotalSpent() async throws {
        launchApp()
        let result = try await definitions.intents["TotalSpentIntent"].makeIntent(period: "allTime").run()
        let value: String = try result.value
        XCTAssertFalse(value.isEmpty)
    }
    @MainActor func testFileDocumentRejectsEmptyInput() async throws {
        launchApp()
        let file = IntentFile(data: Data(), filename: "empty.pdf", type: .pdf)
        do {
            _ = try await definitions.intents["FileDocumentIntent"].makeIntent(document: file).run()
            XCTFail("An empty file must never be queued or filed")
        } catch {
            // Require the product's error, never accept infrastructure/signing failures.
            XCTAssertTrue(error.localizedDescription.contains("empty") || error.localizedDescription.contains("could not be read"), error.localizedDescription)
        }
    }
    @MainActor func testExportRejectsInvalidDates() async throws {
        launchApp()
        do {
            _ = try await definitions.intents["ExportAccountantPackIntent"].makeIntent(startDate: "invalid", endDate: "2026-12-31").run()
            XCTFail("Invalid export dates must be rejected")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Enter valid dates"), error.localizedDescription)
        }
    }
}
