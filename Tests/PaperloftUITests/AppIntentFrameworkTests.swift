import XCTest
import AppIntents
import AppIntentsTesting

/// AC-15: these run through the system's out-of-process intent infrastructure.
/// Requires an installed app and test runner signed by the same development team.
/// Uses only SPEC 6.7 launch hooks for the isolated sample library/model/mock store.
/// No service substitutions or direct perform() calls.
final class AppIntentFrameworkTests: XCTestCase {
    var definitions: IntentDefinitions {
        get throws {
            let identifier = try XCTUnwrap(Bundle(for: Self.self).object(forInfoDictionaryKey: "PaperloftIntentAppBundleIdentifier") as? String)
            XCTAssertFalse(identifier.isEmpty)
            return IntentDefinitions(bundleIdentifier: identifier)
        }
    }

    @MainActor func launchApp(pro: Bool = false) {
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        if pro { app.launchArguments += ["-PaperloftStoreMock", "YES"] }
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        // macOS restoration may leave no window after a terminated run; use the public Window command.
        if !app.buttons["sidebar.inbox"].waitForExistence(timeout: 5) {
            app.menuBars.menuBarItems["Window"].click()
            app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
        }
        if pro { app.makePro() }
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
    @MainActor func testFileDocumentQueuesForReviewAndSurvivesRelaunch() async throws {
        launchApp()
        let name = "Intent receipt " + UUID().uuidString + ".pdf"
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: repo.appendingPathComponent("Apps/PaperloftApp/Resources/Samples/01-office.pdf"))
        let result = try await definitions.intents["FileDocumentIntent"].makeIntent(document: IntentFile(data: data, filename: name, type: .pdf)).run()
        let value: String = try result.value
        XCTAssertEqual(value, "Queued for review")
        let app = XCUIApplication()
        XCTAssertTrue(app.staticTexts[name].firstMatch.waitForExistence(timeout: 10))
        app.terminate()
        launchApp()
        XCTAssertTrue(app.staticTexts[name].firstMatch.waitForExistence(timeout: 10))
    }
    @MainActor func testProExportReturnsReadableZip() async throws {
        launchApp(pro: true)
        let result = try await definitions.intents["ExportAccountantPackIntent"].makeIntent(startDate: "2000-01-01", endDate: "2099-12-31").run()
        let file: IntentFile = try result.value
        XCTAssertEqual(file.type, .zip)
        let bytes = file.data
        XCTAssertGreaterThan(bytes.count, 4)
        XCTAssertEqual(Array(bytes.prefix(2)), [0x50, 0x4b])
    }
    @MainActor func testFreeExportRequiresPro() async throws {
        launchApp()
        do {
            _ = try await definitions.intents["ExportAccountantPackIntent"].makeIntent(startDate: "2000-01-01", endDate: "2099-12-31").run()
            XCTFail("Free entitlement exported a pack")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("require Paperloft Pro"), error.localizedDescription)
        }
    }

}
