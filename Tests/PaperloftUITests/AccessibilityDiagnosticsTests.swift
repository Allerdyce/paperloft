import AppKit
import XCTest

/// Evidence-only diagnostic (not for merge): repeats the core audit sequence, but for every issue
/// records the element frame, the app's window frames, whether the element lies inside a window,
/// the app's foreground state, and a measured contrast estimate from a full-screen capture.
/// It handles every issue (returns true) so all screens are always captured; the unchanged
/// CoreFlowTests audit remains the acceptance check.
final class AccessibilityDiagnosticsTests: XCTestCase {
    private var report: [String] = []

    @MainActor
    func testAuditDiagnostics() throws {
        continueAfterFailure = true
        addTeardownBlock { @MainActor in
            let summary = XCTAttachment(string: self.report.joined(separator: "\n"))
            summary.name = "a11y-diagnostic-report"; summary.lifetime = .keepAlways
            self.add(summary)
        }
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub"]
        app.launch(); app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.buttons["sidebar.settings"].waitForExistence(timeout: 15))
        logWindows(app, "after launch")
        app.typeKey(",", modifierFlags: .command)
        let fresh = app.buttons["settings.newSampleLibrary"]
        XCTAssertTrue(fresh.waitForExistence(timeout: 10))
        logWindows(app, "settings open")
        fresh.click()
        logWindows(app, "after fresh sample library")
        app.typeKey("w", modifierFlags: .command)
        logWindows(app, "after cmd-w")
        app.activate()
        app.buttons["sidebar.inbox"].click()
        XCTAssertTrue(app.buttons["inbox.import"].waitForExistence(timeout: 10))
        defer { app.terminate() }

        try diagnose(app, "1-inbox-empty")
        for section in ["library", "history"] {
            app.activate()
            app.buttons["sidebar." + section].click()
            try diagnose(app, "2-" + section)
        }
        // Diagnostic: close the main window so Settings is audited as the only window.
        app.typeKey("w", modifierFlags: .command)
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["settings.newSampleLibrary"].waitForExistence(timeout: 10))
        try diagnose(app, "3-settings-general")
        for tab in ["Filing", "Categories"] where app.toolbars.buttons[tab].exists || app.buttons[tab].exists {
            (app.toolbars.buttons[tab].exists ? app.toolbars.buttons[tab] : app.buttons[tab]).click()
            try diagnose(app, "3-settings-" + tab.lowercased())
        }
        app.typeKey("w", modifierFlags: .command)
        app.menuBars.menuBarItems["Window"].click()
        let windowItems = app.menuBars.menuBarItems["Window"].menuItems.allElementsBoundByIndex.map(\.title)
        report.append("window menu: " + windowItems.joined(separator: " | "))
        let restore = app.menuBars.menuBarItems["Window"].menuItems.matching(NSPredicate(format: "title == 'Paperloft Receipts'")).firstMatch
        if restore.waitForExistence(timeout: 5) { restore.click() } else { app.typeKey(.escape, modifierFlags: []) }
        report.append("restored main window: \(app.buttons["sidebar.inbox"].waitForExistence(timeout: 5))")
        app.activate()
        app.buttons["sidebar.inbox"].click(); app.menuBars.menuBarItems["File"].click(); app.menuBars.menuItems["Load Development Receipts"].click()
        XCTAssertTrue(app.textFields["review.vendor"].waitForExistence(timeout: 60))
        try diagnose(app, "4-inbox-loaded")

    }

    @MainActor
    private func diagnose(_ app: XCUIApplication, _ label: String) throws {
        let windows = app.windows.allElementsBoundByIndex.map { ($0.title, $0.identifier, $0.frame) }
        report.append("== \(label) state=\(app.state.rawValue) windows=" + windows.map { "'\($0.0)'[\($0.1)] \(fmt($0.2))" }.joined(separator: "; "))
        let screen = XCUIScreen.main.screenshot()
        let shot = XCTAttachment(screenshot: screen); shot.name = "\(label)-screen"; shot.lifetime = .keepAlways
        add(shot)
        let frames = windows.map(\.2)
        try app.performAccessibilityAudit { issue in
            let frame = issue.element?.frame ?? .zero
            let inside = frames.contains { $0.insetBy(dx: -1, dy: -1).contains(frame) }
            let overlapping = frames.contains { $0.intersects(frame) }
            let measured = frame.isEmpty ? "n/a" : Self.contrast(in: screen.image, rect: frame)
            let element = issue.element.map { "\($0.elementType.rawValue) '\($0.label)' id='\($0.identifier)' value='\(String(describing: $0.value ?? "").prefix(60))'" } ?? "no element"
            if issue.element == nil { self.report.append("  detail: " + issue.detailedDescription.replacingOccurrences(of: "\n", with: " ")) }
            self.report.append("  [\(issue.auditType.rawValue)] \(issue.compactDescription) | \(element) | frame=\(Self.fmt(frame)) insideWindow=\(inside) overlapsWindow=\(overlapping) measured=\(measured)")
            return true
        }
    }

    @MainActor private func logWindows(_ app: XCUIApplication, _ label: String) {
        report.append("setup \(label): " + app.windows.allElementsBoundByIndex.map { "'\($0.title)'[\($0.identifier)] \(fmt($0.frame))" }.joined(separator: "; "))
    }

    private func fmt(_ r: CGRect) -> String { Self.fmt(r) }
    private static func fmt(_ r: CGRect) -> String { String(format: "(%.0f,%.0f %.0fx%.0f)", r.minX, r.minY, r.width, r.height) }

    /// Rough WCAG-style estimate: relative luminance of the 5th and 95th percentile pixels in
    /// the element's rectangle of a full-screen capture. Diagnostic only, not colour-managed.
    private static func contrast(in image: NSImage, rect: CGRect) -> String {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return "no image" }
        let scale = CGFloat(cg.width) / image.size.width
        let pixelRect = CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale).integral
        let bounds = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
        let clipped = pixelRect.intersection(bounds)
        guard !clipped.isEmpty, let crop = cg.cropping(to: clipped) else { return "offscreen" }
        let width = crop.width, height = crop.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return "no context" }
        context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
        func linear(_ c: UInt8) -> Double { let v = Double(c) / 255; return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        var lum: [Double] = []
        lum.reserveCapacity(width * height)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            lum.append(0.2126 * linear(pixels[i]) + 0.7152 * linear(pixels[i + 1]) + 0.0722 * linear(pixels[i + 2]))
        }
        lum.sort()
        let dark = lum[Int(Double(lum.count - 1) * 0.05)], light = lum[Int(Double(lum.count - 1) * 0.95)]
        let clippedNote = clipped == pixelRect ? "" : " (partly offscreen)"
        return String(format: "%.2f:1 dark=%.3f light=%.3f", (light + 0.05) / (dark + 0.05), dark, light) + clippedNote
    }
}
