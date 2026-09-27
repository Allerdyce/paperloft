# Independent native accessibility probe

Diagnostic only; no acceptance pass is claimed. Both tests failed and xcodebuild returned 65. All audit issues are retained: performAccessibilityAudit uses the default .all and its logging handler returns false for every issue. No Paperloft product source, existing tests, verifier, thresholds, or locked file was edited.

## Environment and prerequisites

- macOS 27.0 (26A428), Xcode 27.0 (27A266a), arm64 Mac.
- Isolated checkout: /Users/builder/Factory/paperloft-audit-probe, branch local/audit-probe.
- Local preflight: 38 PASS, 1 WARN, 0 FAIL, 0 TFAIL; formal membership/release prerequisites remain deferred.
- scripts/verify_local_baseline.sh passed pre-tag protected files and existing hashes; append-only lock history checked without removed entries.
- GUI lock acquired atomically for the UI test run and released afterward.

## Findings

The failures reproduce in a standalone SwiftUI project with no Paperloft imports or package dependencies:

| Minimal UI | Reported failures |
|---|---|
| Window with clear content, no controls | Disabled host Group has no description; empty disabled TouchBar has no description |
| Window with standard TextField and Picker, TextField focused | Parent/Child mismatch (nil element); host Group has no description; placeholder-only TextField has no description; Picker PopUpButton is missing an action; disabled TouchBar has no description; system emoji & symbols PopUpButton has no description and is missing an action |

This establishes reproduction without Paperloft code on this OS/SDK. It does not prove every product-owned host-group issue is a platform bug, nor rule out app workarounds. The placeholder-only TextField finding remains a normal app-labeling concern. The empty-window host Group result and system TouchBar/emoji results demonstrate that these findings do not require product UI logic. No issue suppression or filtering was tried. Stopped after one minimal probe approach because all requested classes reproduced.

## Evidence

- Result bundle: /Users/builder/Factory/paperloft-audit-probe/evidence/a11y-probe/Probe.xcresult
- Build log: build.log (TEST BUILD SUCCEEDED)
- Test log: test.log (two failed tests; TEST EXECUTE FAILED)
- Exported screenshots and issue descriptions: attachments/manifest.json and files it identifies.
- Named screenshots: empty-window.png and standard-controls.png. Standard-controls screenshot visually checked: native window, Search text field, Status popup set to All.
- Exact project: Tools/AccessibilityProbe/AccessibilityProbe.xcodeproj; only app and ProbeTests targets, Apple frameworks.

## Reproduction command

```sh
xcodebuild build-for-testing -project Tools/AccessibilityProbe/AccessibilityProbe.xcodeproj -scheme AccessibilityProbe -destination 'platform=macOS' -derivedDataPath build/AccessibilityProbe
# Acquire ~/Factory/.gui.lock atomically before driving UI.
xcodebuild test-without-building -project Tools/AccessibilityProbe/AccessibilityProbe.xcodeproj -scheme AccessibilityProbe -destination 'platform=macOS' -derivedDataPath build/AccessibilityProbe -resultBundlePath evidence/a11y-probe/Probe.xcresult
# Release the lock afterward. Use a fresh result path for another run.
```

## Exact app code

```swift
import SwiftUI

@main
struct ProbeApp: App {
    @State private var text = ""
    @State private var selection = "All"
    var body: some Scene {
        Window("Accessibility Probe", id: "main") {
            if ProcessInfo.processInfo.arguments.contains("--empty") {
                Color.clear.frame(width: 400, height: 200)
            } else {
                VStack {
                    TextField("Search", text: $text)
                    Picker("Status", selection: $selection) {
                        Text("All").tag("All")
                        Text("Reviewed").tag("Reviewed")
                    }
                }
                .padding()
                .frame(width: 400, height: 200)
            }
        }
    }
}
```

## Exact test code

```swift
import XCTest

final class ProbeTests: XCTestCase {
    @MainActor private func audit(empty: Bool) throws {
        let app = XCUIApplication()
        if empty { app.launchArguments = ["--empty"] }
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        if !empty { app.textFields.firstMatch.click() }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = empty ? "empty-window" : "standard-controls"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        print("PROBE_TREE \(app.debugDescription)")
        try app.performAccessibilityAudit { issue in
            print("PROBE_ISSUE type=\(issue.auditType) description=\(issue.compactDescription) detail=\(issue.detailedDescription) element=\(issue.element?.debugDescription ?? "nil")")
            return false
        }
    }
    @MainActor func testEmptyWindowAudit() throws { try audit(empty: true) }
    @MainActor func testStandardControlsAudit() throws { try audit(empty: false) }
}
```

## Raw issue records

```text
PROBE_ISSUE type=XCUIAccessibilityAuditType(rawValue: 8) description=Element has no description detail=This element is missing useful accessibility information. element=Attributes: Group, 0x7c56e97700, {{414.0, 350.0}, {900.0, 450.0}}, Disabled
PROBE_ISSUE type=XCUIAccessibilityAuditType(rawValue: 8) description=Element has no description detail=This element is missing useful accessibility information. element=Attributes: TouchBar, 0x7c56ef66c0, {{80.0, 0.0}, {686.0, 30.0}}, Disabled
PROBE_ISSUE type=XCUIAccessibilityAuditType(rawValue: 8589934592) description=Parent/Child mismatch detail=This element is not an accessibility child of the parent element. element=nil
PROBE_ISSUE type=XCUIAccessibilityAuditType(rawValue: 8) description=Element has no description detail=This element is missing useful accessibility information. element=Attributes: Group, 0x7c56e7d540, {{414.0, 350.0}, {900.0, 450.0}}, Disabled
PROBE_ISSUE type=XCUIAccessibilityAuditType(rawValue: 8) description=Element has no description detail=This element is missing useful accessibility information. element=Attributes: TextField, 0x7c56e7d540, {{679.0, 562.0}, {370.0, 26.0}}, placeholderValue: 'Search', Keyboard Focused
PROBE_ISSUE type=XCUIAccessibilityAuditType(rawValue: 4294967296) description=Action is missing detail=This element is missing accessibility action support equivalent to click/tap inputs. element=Attributes: PopUpButton, 0x7c56e7d900, {{835.0, 595.0}, {105.5, 24.0}}, value: All
PROBE_ISSUE type=XCUIAccessibilityAuditType(rawValue: 8) description=Element has no description detail=This element is missing useful accessibility information. element=Attributes: TouchBar, 0x7c56e7bc00, {{80.0, 0.0}, {686.0, 30.0}}, Disabled
PROBE_ISSUE type=XCUIAccessibilityAuditType(rawValue: 8) description=Element has no description detail=This element is missing useful accessibility information. element=Attributes: PopUpButton, 0x7c56effe80, {{79.0, -1.0}, {74.0, 32.0}}, label: 'emoji & symbols'
PROBE_ISSUE type=XCUIAccessibilityAuditType(rawValue: 4294967296) description=Action is missing detail=This element is missing accessibility action support equivalent to click/tap inputs. element=Attributes: PopUpButton, 0x7c56e7be80, {{79.0, -1.0}, {74.0, 32.0}}, label: 'emoji & symbols'
```
