import XCTest

/// AC-13 audit for the actual sidebar Settings page, all three inline sections in both themes.
/// Every app-owned finding remains a failure; no clipping or viewport exceptions are introduced.
final class InlineSettingsAuditTests: XCTestCase {
    @MainActor
    func testInlineSettingsLightAtEverySection() throws {
        try auditInlineSettings(appearance: "Light")
    }

    @MainActor
    func testInlineSettingsDarkAtEverySection() throws {
        try auditInlineSettings(appearance: "Dark")
    }

    @MainActor
    private func auditInlineSettings(appearance: String) throws {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments = ["-PaperloftUITestMode", "YES", "-PaperloftModel", "stub", "-PaperloftStoreMock", "YES"]
        app.launch(); app.activate()
        defer { app.terminate() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        if !app.buttons["sidebar.settings"].waitForExistence(timeout: 5) {
            app.menuBars.menuBarItems["Window"].click()
            app.menuBars.menuBarItems["Window"].menus.menuItems["Paperloft Receipts"].click()
        }
        let main = app.windows["main"]
        XCTAssertTrue(main.waitForExistence(timeout: 10))
        // A restored secondary window would contaminate contrast measurements of the main page.
        for window in app.windows.allElementsBoundByIndex where window.identifier != "main" {
            let close = window.buttons[XCUIIdentifierCloseWindow]
            if close.exists { close.click() }
        }
        app.returnToFree()
        app.debugMenu("Size Window for App Store Screenshots")
        app.buttons["sidebar.settings"].click()
        let sections = main.radioGroups["settings.section"]
        XCTAssertTrue(sections.waitForExistence(timeout: 10))
        sections.radioButtons["General"].click()
        let root = main.scrollViews["settings.root"]
        XCTAssertTrue(root.waitForExistence(timeout: 10), "Audit the embedded scroll page, not the Settings window")
        guard root.exists else { return }

        let theme = main.radioGroups["settings.appearance"]
        try reveal(theme, in: root, window: main)
        let oldTheme = ["System", "Light", "Dark"].first { (theme.radioButtons[$0].value as? NSNumber)?.intValue == 1 }
        theme.radioButtons[appearance].click()
        defer {
            if let oldTheme {
                // Restore the owner's app appearance without changing the system appearance.
                sections.radioButtons["General"].click()
                try? reveal(theme, in: root, window: main)
                theme.radioButtons[oldTheme].click()
            }
        }
        let stages: [(String, [String])] = [
            ("General", ["settings.appearance", "settings.chooseFolder", "settings.restore", "settings.watchedTypes"]),
            ("Filing", ["settings.scannedPages", "settings.filenameTemplate"]),
            ("Categories", ["settings.categories", "settings.addCategory"])
        ]
        for (name, identifiers) in stages {
            sections.radioButtons[name].click()
            XCTAssertEqual((sections.radioButtons[name].value as? NSNumber)?.intValue, 1)
            XCTAssertTrue(app.buttons["sidebar.settings"].isHittable, "Settings remains a sidebar page")
            let anchors = identifiers.map { main.descendants(matching: .any).matching(identifier: $0).firstMatch }
            guard let last = anchors.last else { continue }
            try reveal(last, in: root, window: main)
            Thread.sleep(forTimeInterval: 1.5) // match the frozen core audit's settled-layout wait
            let viewport = root.frame.intersection(main.frame).insetBy(dx: 2, dy: 2)
            for (index, anchor) in anchors.enumerated() {
                XCTAssertTrue(anchor.exists, identifiers[index])
                XCTAssertTrue(viewport.contains(anchor.frame), "\(identifiers[index]) is fully visible at \(name): \(anchor.frame), viewport \(viewport)")
            }
            attachGeometry(main: main, root: root, name: "\(appearance)-\(name)")
            do {
                try auditAccessibility(app) // frozen helper; only the existing system-owned exceptions
            } catch {
                XCTFail("Inline Settings \(appearance) \(name) audit failed: \(error)")
            }
        }
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in scroll: XCUIElement, window: XCUIElement) throws {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        guard element.exists else { return }
        // Bounded, overlapping scrolls; the trailing edge avoids the nested Categories list.
        for _ in 0..<20 {
            let viewport = scroll.frame.intersection(window.frame).insetBy(dx: 8, dy: 16)
            if viewport.contains(element.frame) { return }
            let offset = element.frame.midY - viewport.midY
            let delta = -min(max(abs(offset), 100), 300) * (offset >= 0 ? 1.0 : -1.0)
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5))
                .scroll(byDeltaX: 0, deltaY: delta)
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTFail("Unable to bring \(element.identifier) fully into the Settings viewport; frame \(element.frame)")
    }

    @MainActor
    private func attachGeometry(main: XCUIElement, root: XCUIElement, name: String) {
        let screenshot = XCTAttachment(screenshot: main.screenshot())
        screenshot.name = "Inline Settings \(name)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let geometry = main.debugDescription
        let detail = XCTAttachment(string: "Window: \(main.frame)\nScroll viewport: \(root.frame)\n\(geometry)")
        detail.name = "Inline Settings geometry \(name)"
        detail.lifetime = .keepAlways
        add(detail)
    }
}
