import AppKit
import CryptoKit
import Darwin
import ImageIO
import PaperloftKit
import SwiftUI
import UniformTypeIdentifiers
import XCTest
@testable import Paperloft_Receipts

/// Hosted in the actual application, with its real SwiftUI review screen rendered.
/// These tests measure AppModel intake, OCR, model/parser, duplicate checks, review
/// updates and inbox persistence together. They do not time ReceiptEngine alone.
final class PipelinePerformanceTests: XCTestCase {
    @MainActor func testSamplerDetectsBlockedMainThread() {
        let sampler = PipelineSampler(); sampler.start()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        Thread.sleep(forTimeInterval: 0.30)
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        sampler.stop()
        let sample = sampler.snapshot()
        XCTAssertGreaterThanOrEqual(sample.maxDelay, 0.30)
        XCTAssertGreaterThan(sample.peakBytes, 0)
        XCTAssertEqual(sample.memoryFailures, 0)
        XCTAssertGreaterThan(sample.heartbeats, 0)
    }

    @MainActor func test100MixedDocuments() throws {
        continueAfterFailure = false // Native XCTest fail-fast: do not repeat an already-failed warmup.
        let name = try XCTUnwrap(AppModel.argument("-PaperloftModel"))
        XCTAssertTrue(["parser", "system"].contains(name), "Use the parser or system performance scheme")
        XCTAssertEqual(AppModel.argument("-PaperloftUITestMode"), "YES")
        try runPipeline(name: name, limit: name == "parser" ? 30 : 240)
    }

    @MainActor private func runPipeline(name: String, limit: TimeInterval) throws {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Paperloft-Performance/" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let inputs = try PerformanceInputs.make(bundle: Bundle(for: Self.self), destination: root.appendingPathComponent("Inputs"))
        XCTAssertEqual(inputs.urls.count, 100)
        let manifest = XCTAttachment(data: try JSONEncoder().encode(inputs.manifest), uniformTypeIdentifier: UTType.json.identifier)
        manifest.name = "100-document-manifest.json"; manifest.lifetime = .keepAlways; add(manifest)
        let options = XCTMeasureOptions()
        options.iterationCount = 1 // XCTest also runs one warmup; assertions below apply to BOTH.
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        var iteration = 0
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(),
                          XCTOSSignpostMetric(subsystem: "app.paperloft.receipts", category: "Pipeline", name: "UnderstandInboxBatch")], options: options) {
            iteration += 1
            let ordinal = iteration
            let finished = expectation(description: "100 documents complete: \(name), iteration \(ordinal)")
            Task { @MainActor in
                // The singleton installed by the real App initializer is the model
                // bound to the actual main window, not an engine-only surrogate.
                guard let model = PaperloftIntentRuntime.service as? AppModel, model.testMode else {
                    XCTFail("The actual app model is unavailable"); finished.fulfill(); return
                }
                // Hosted XCTest does not reliably materialize SwiftUI's Scene window.
                // Render the shipping LibraryView against the actual App singleton,
                // so layout, previews and observation run in the measured app process.
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.title = "Paperloft performance workload"
                window.contentView = NSHostingView(rootView: LibraryView(model: model))
                window.makeKeyAndOrderFront(nil)
                var measuring = false
                let sampler = PipelineSampler()
                defer {
                    if measuring { self.stopMeasuring() }
                    sampler.stop()
                    window.close()
                    finished.fulfill()
                }
                do {
                    await model.start()
                    try await model.newSampleLibrary(discardInbox: true)
                    // Only the documented temporary UI-test workspace is cleared.
                    // All original inputs stay untouched; no production hook is added.
                    print("PERFORMANCE_SETUP clearing temporary inbox records: \(model.items.count)")
                    model.items.removeAll(); model.selectedItemID = nil
                    XCTAssertTrue(window.isVisible && window.contentView != nil, "The production LibraryView must be visible during measurement")
                    // Allow the ordinary view's first layout before timing document intake.
                    try await Task.sleep(for: .milliseconds(100))
                    self.startMeasuring(); measuring = true
                    sampler.start()
                    let started = ProcessInfo.processInfo.systemUptime
                    let priorInboxCount = model.items.count
                    model.intake(inputs.urls)
                    let cohort = Set(model.items.filter { $0.status != "aside" }.map(\.id))
                    while model.processing || model.items.contains(where: { $0.status == "waiting" || $0.status == "processing" }) {
                        if ProcessInfo.processInfo.systemUptime - started > limit + 120 { break }
                        try await Task.sleep(for: .milliseconds(10))
                    }
                    NSApplication.shared.windows.forEach { $0.contentView?.layoutSubtreeIfNeeded(); $0.contentView?.displayIfNeeded() }
                    let elapsed = ProcessInfo.processInfo.systemUptime - started
                    sampler.stop()
                    self.stopMeasuring(); measuring = false
                    let sample = sampler.snapshot()
                    let complete = model.items.filter { cohort.contains($0.id) && $0.status == "ready" && $0.review != nil }.count
                    let failures = model.items.filter { cohort.contains($0.id) && $0.status == "failed" }.map { $0.issue ?? "Unknown processing failure" }
                    let persisted = try JSONDecoder().decode([InboxItem].self, from: Data(contentsOf: model.support.appendingPathComponent("inbox.json")))
                    let backends = Dictionary(grouping: model.items.filter { cohort.contains($0.id) }.compactMap { $0.review?.fields.backend }, by: { $0 }).mapValues(\.count)
                    let report = PipelineReport(backend: name, iteration: ordinal, inputCount: inputs.urls.count, priorInboxCount: priorInboxCount, recordedBackends: backends,
                        completed: complete, persistedCompleted: persisted.filter { cohort.contains($0.id) && $0.status == "ready" && $0.review != nil }.count,
                        seconds: elapsed, maximumMainHeartbeatGapSeconds: sample.maxDelay,
                        lifetimePeakPhysicalBytes: sample.peakBytes, memoryReadFailures: sample.memoryFailures,
                        heartbeatCount: sample.heartbeats, failures: failures)
                    let attachment = XCTAttachment(data: try JSONEncoder().encode(report), uniformTypeIdentifier: UTType.json.identifier)
                    attachment.name = "pipeline-\(name)-iteration-\(ordinal).json"; attachment.lifetime = .keepAlways; self.add(attachment)
                    print("PAPERLOFT_PERFORMANCE " + String(decoding: try JSONEncoder().encode(report), as: UTF8.self))
                    // Cancel any unfinished work before XCTest fail-fast can abort this test.
                    try await model.newSampleLibrary(discardInbox: true)
                    XCTAssertEqual(cohort.count, 100)
                    XCTAssertEqual(complete, 100, "Every document must finish understanding; failures cannot count as completion")
                    XCTAssertEqual(report.persistedCompleted, 100)
                    XCTAssertEqual(backends, [name: 100], "System-mode parser fallbacks cannot satisfy the system measurement")
                    XCTAssertTrue(failures.isEmpty)
                    XCTAssertLessThanOrEqual(elapsed, limit)
                    XCTAssertGreaterThan(sample.heartbeats, 0, "Main-queue sampling must actually execute")
                    XCTAssertEqual(sample.memoryFailures, 0, "Unmeasured memory cannot be a pass")
                    XCTAssertGreaterThan(sample.peakBytes, 0)
                    XCTAssertLessThanOrEqual(sample.maxDelay, 0.250)
                    XCTAssertLessThan(sample.peakBytes, 600_000_000, "AC-10 uses a strict 600 MB upper bound")
                } catch { XCTFail("Pipeline harness failed: \(error)") }
            }
            wait(for: [finished], timeout: limit + 180)
        }
        // Keep test-created documents inside the app-owned run directory for diagnosis.
        // The report is exported through XCTest attachments, never shell container access.
    }
}

struct PipelineReport: Codable {
    let backend: String
    let iteration: Int
    let inputCount: Int
    let priorInboxCount: Int
    let recordedBackends: [String: Int]
    let completed: Int
    let persistedCompleted: Int
    let seconds: Double
    let maximumMainHeartbeatGapSeconds: Double
    let lifetimePeakPhysicalBytes: UInt64
    let memoryReadFailures: Int
    let heartbeatCount: Int
    let failures: [String]
}

/// A background timer maintains at most one outstanding main-queue heartbeat.
/// Gaps between completed heartbeats (including normal 10ms cadence) conservatively
/// bound main-thread stalls even if the sampler itself is starved of CPU.
/// task_vm_info reports the kernel's lifetime physical-footprint peak, so a short
/// memory spike between polls cannot escape the 600 MB assertion.
final class PipelineSampler: @unchecked Sendable {
    struct Snapshot { var maxDelay = 0.0; var peakBytes: UInt64 = 0; var memoryFailures = 0; var heartbeats = 0 }
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "app.paperloft.performance.sampler", qos: .userInitiated)
    private var timer: DispatchSourceTimer?
    private var pending: TimeInterval?
    private var lastHeartbeat = 0.0
    private var active = false
    private var sample = Snapshot()
    func start() {
        lock.lock(); active = true; lastHeartbeat = ProcessInfo.processInfo.systemUptime; lock.unlock()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(10), leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in self?.tick() }
        self.timer = timer; timer.resume()
    }
    func stop() {
        timer?.cancel(); timer = nil
        lock.lock()
        guard active else { lock.unlock(); return }
        sample.maxDelay = max(sample.maxDelay, ProcessInfo.processInfo.systemUptime - lastHeartbeat)
        active = false
        lock.unlock()
        recordMemory()
    }
    func snapshot() -> Snapshot { lock.lock(); defer { lock.unlock() }; return sample }
    private func tick() {
        recordMemory()
        lock.lock()
        guard active else { lock.unlock(); return }
        let now = ProcessInfo.processInfo.systemUptime
        sample.maxDelay = max(sample.maxDelay, now - lastHeartbeat)
        if pending != nil { lock.unlock(); return }
        pending = now; lock.unlock()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock(); defer { self.lock.unlock() }
            if self.active, self.pending != nil {
                let completed = ProcessInfo.processInfo.systemUptime
                self.sample.maxDelay = max(self.sample.maxDelay, completed - self.lastHeartbeat)
                self.lastHeartbeat = completed
                self.sample.heartbeats += 1
            }
            self.pending = nil
        }
    }
    private func recordMemory() {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let capacity = Int(count)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        lock.lock(); defer { lock.unlock() }
        if result == KERN_SUCCESS, info.ledger_phys_footprint_peak > 0 {
            sample.peakBytes = max(sample.peakBytes, UInt64(info.ledger_phys_footprint_peak), info.phys_footprint)
        } else { sample.memoryFailures += 1 }
    }
}

struct PerformanceInputs {
    struct Entry: Codable { let id: String; let sourceType: String; let measuredType: String; let sha256: String }
    let urls: [URL]
    let manifest: [Entry]
    static func make(bundle: Bundle, destination: URL) throws -> Self {
        let fixtures = try XCTUnwrap(bundle.resourceURL?.appendingPathComponent("PerformanceFixtures"))
        let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: fixtures.appendingPathComponent("manifest.json")))
        XCTAssertEqual(entries.count, 100)
        XCTAssertEqual(Set(entries.map(\.id)).count, 100)
        XCTAssertEqual(Set(entries.map(\.sha256)).count, 100)
        for (type, count) in [("jpg", 30), ("png", 30), ("pdf", 20), ("heic", 20)] {
            XCTAssertEqual(entries.filter { $0.measuredType == type }.count, count)
        }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let urls = try entries.map { entry in
            let name = entry.id + "." + entry.measuredType
            let source = fixtures.appendingPathComponent(name), target = destination.appendingPathComponent(name)
            let digest = SHA256.hash(data: try Data(contentsOf: source, options: .mappedIfSafe)).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(digest, entry.sha256, "Fixture content must match the recorded run manifest")
            try FileManager.default.copyItem(at: source, to: target)
            return target
        }
        return Self(urls: urls, manifest: entries)
    }
}
