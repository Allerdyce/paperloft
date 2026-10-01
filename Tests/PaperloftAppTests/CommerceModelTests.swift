import XCTest
import AppKit
import PaperloftKit

/// SPEC 6.3 Free/Pro rules in the model: export is Pro; the 26th automatic read of a month pauses
/// with the paywall; manual entry and samples never count; a purchase resumes paused documents.
@MainActor final class CommerceModelTests: XCTestCase {
    private func workspace() throws -> (root: URL, defaults: UserDefaults) {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = repo.appendingPathComponent("build/CommerceModelTests/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "app.paperloft.commerce-model." + UUID().uuidString
        addTeardownBlock { try? FileManager.default.removeItem(at: root); UserDefaults.standard.removePersistentDomain(forName: suite) }
        return (root, UserDefaults(suiteName: suite)!)
    }
    private func receiptPDF(_ index: Int, in folder: URL) throws -> URL {
        let pdf = NSMutableData()
        var page = CGRect(x: 0, y: 0, width: 400, height: 400)
        let context = try XCTUnwrap(CGContext(consumer: XCTUnwrap(CGDataConsumer(data: pdf)), mediaBox: &page, nil))
        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        ("Quota Test Store \(index)\n2026-09-\(10 + index % 18)\nTotal USD \(index).50" as NSString)
            .draw(at: NSPoint(x: 30, y: 300), withAttributes: [.font: NSFont.systemFont(ofSize: 18)])
        NSGraphicsContext.restoreGraphicsState(); context.endPDFPage(); context.closePDF()
        let url = folder.appendingPathComponent("quota-\(index).pdf")
        try (pdf as Data).write(to: url); return url
    }
    private func waitForIdle(_ model: AppModel) async throws {
        for _ in 0..<1200 where !model.items.filter({ $0.status != "aside" }).allSatisfy({ !["waiting", "processing"].contains($0.status) }) {
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    func testExportIsProAndFreeSeesThePaywall() async throws {
        let (root, defaults) = try workspace()
        let store = StoreController(mock: true, startPro: false); await store.start()
        let model = AppModel(support: root.appendingPathComponent("support"), preferences: defaults, store: store, extractionBackend: StubBackend())
        await model.start(); try await model.newSampleLibrary()
        model.beginExport()
        XCTAssertTrue(model.showPaywall, "Free sees the paywall at the first export")
        XCTAssertFalse(model.showExport)
        model.showPaywall = false
        await store.purchase(productID: StoreController.lifetimeID)
        XCTAssertTrue(model.isPro)
        model.beginExport()
        XCTAssertTrue(model.showExport, "Pro opens the export sheet")
    }

    func testTwentySixthReadPausesManualEntryIsFreeAndPurchaseResumes() async throws {
        let (root, defaults) = try workspace()
        let store = StoreController(mock: true, startPro: false); await store.start()
        let model = AppModel(support: root.appendingPathComponent("support"), preferences: defaults, store: store, extractionBackend: StubBackend())
        await model.start(); try await model.newSampleLibrary()
        let folder = root.appendingPathComponent("inputs"); try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let urls = try (1...27).map { try receiptPDF($0, in: folder) }
        await model.intake(urls)
        try await waitForIdle(model)
        let statuses = model.items.map(\.status)
        XCTAssertEqual(statuses.filter { $0 == "ready" }.count, 25, "\(statuses)")
        XCTAssertEqual(statuses.filter { $0 == "quota" }.count, 2, "the 26th and 27th wait for Pro or manual entry")
        XCTAssertTrue(model.showPaywall, "the paywall appears at the 26th document")
        XCTAssertEqual(model.quotaUsedThisMonth, 25)
        // Manual entry is unlimited and doesn't count.
        let paused = try XCTUnwrap(model.items.first { $0.status == "quota" })
        await model.enterManually(paused.id)
        XCTAssertEqual(model.items.first { $0.id == paused.id }?.status, "ready")
        XCTAssertEqual(model.quotaUsedThisMonth, 25, "manual entry is free")
        // Buying Pro resumes the rest automatically (the app does this when the entitlement changes).
        await store.purchase(productID: StoreController.yearlyID)
        XCTAssertTrue(model.isPro)
        model.resumeQuotaPaused()
        try await waitForIdle(model)
        XCTAssertFalse(model.items.contains { $0.status == "quota" })
        XCTAssertEqual(model.items.filter { $0.status == "ready" }.count, 27)
        // The ledger survives a relaunch: a new Free model still counts this month's reads.
        let relaunched = AppModel(support: root.appendingPathComponent("support"), preferences: defaults, store: StoreController(mock: true, startPro: false), extractionBackend: StubBackend())
        XCTAssertEqual(relaunched.quotaUsedThisMonth, 26, "25 Free reads plus the Pro read of the 27th; manual entry isn't counted")
    }
}
