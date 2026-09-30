import XCTest
import PaperloftKit

/// QA-01: "Try with Samples" works in every build: it sets up a practice library and queues the
/// five bundled synthetic receipts for review.
@MainActor final class SampleOnboardingTests: XCTestCase {
    func testTryWithSamplesCreatesPracticeLibraryAndQueuesFiveSamples() async throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/SampleOnboardingTests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "app.paperloft.sample-onboarding." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { try? FileManager.default.removeItem(at: root); UserDefaults.standard.removePersistentDomain(forName: suite) }
        let model = AppModel(support: root, preferences: defaults, extractionBackend: StubBackend())
        await model.start()
        XCTAssertNil(model.libraryURL, "fresh start has no library")
        // Unit tests aren't hosted in the app bundle, so point at the source samples the app bundles.
        await model.trySamples(resources: repo.appendingPathComponent("Apps/PaperloftApp"))
        XCTAssertNil(model.message, model.message ?? "")
        XCTAssertTrue(model.isSampleLibrary)
        XCTAssertNotNil(model.libraryURL)
        XCTAssertEqual(model.items.count, 5)
        let names = Set(model.items.map { $0.displayName ?? $0.source.lastPathComponent })
        XCTAssertEqual(names, ["01-office.pdf", "02-meal.pdf", "03-travel.pdf", "04-software.pdf", "05-utilities.pdf"])
    }
}
