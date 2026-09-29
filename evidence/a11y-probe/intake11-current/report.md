# Current 1.1 accessibility diagnostic

2026-09-29, root revision `d5d9423`. FAIL, not an acceptance verdict. The unchanged frozen `CoreFlowTests.testCoreScreensAccessibilityAudit` ran with default all-types auditing and no issue suppression. Product sources, frozen tests and thresholds were not changed.

## Evidence and isolation

- Result: `/Users/builder/Factory/paperloft/build/Intake11AccessibilityRetry.xcresult`, exit 65.
- Log: `/Users/builder/Factory/paperloft/build/intake11-accessibility-retry.log`.
- Exported attachments: `/Users/builder/Factory/paperloft/build/Intake11AccessibilityAttachments/manifest.json`. The 32 detailed issue attachments are preserved in `issues.txt` beside this report.
- Exact process: PID 46558, `/Users/builder/Factory/paperloft/build/Intake11Accessibility/Build/Products/Debug/Paperloft Receipts.app/Contents/MacOS/Paperloft Receipts`.
- Isolated bundle identity `app.paperloft.a11y.app.paperloft.receipts.development`, ad hoc signing, app groups disabled, fresh sample library. Existing running signed development app quit gracefully first. GUI lock acquired atomically and released after testing; no owner container was read.
- Initial build-only attempt stopped on extension bundle-prefix validation. Corrected ignored local xcconfig preserved parent/extension hierarchy; no product project changes.

## Result

32 accessibility findings: 21 contrast (10 failed, 11 near threshold), 4 missing actions, 6 missing descriptions, 1 parent/child mismatch. An additional assertion failed waiting 60 seconds for `review.vendor`. The exported app hierarchy proves all five samples imported but remained Processing, with activity `Reading 01-office...`. The last audit therefore examined processing UI, not the ready review form. Do not treat this as complete review-screen coverage or directly compare its count with the historical 14-finding report.

## Concrete product fixes to coordinate

All currently identified product-owned changes belong to `Apps/PaperloftApp/LibraryView.swift`, which another agent owns for duplicate/removal work. No conflicting edit was made.

1. Empty Inbox explanatory copy fails contrast: shared intake-card detail (line 136), intro subtitle (184), drag hint (191), filetype footer (193). Replace secondary foreground with primary, retaining font/spacing hierarchy; verify in both appearances. These four declarations cover five reported texts.
2. Library column headers (608) and explanatory footer (649) fail contrast. Same primary-foreground candidate applies.
3. Library filter chips `library.kind`, `library.category`, `library.year` lack equivalent accessibility actions. Current `LibraryFilterChip` (669) uses a SwiftUI Menu with nested Picker. Reuse or extend the existing native `AccessiblePicker`/`PressablePopup` implementation, maintaining selected value, keyboard behavior and visible design. A label alone does not repair missing actions.
4. Settings `settings.scannedPages` (795) native SwiftUI popup lacks an action; bridge through existing `AccessiblePicker` with an enum/string binding. Scanning explanatory copy (800) also reports low contrast.
5. Settings reports contrast for appearance explanation, Original documents label, filename token help, and move warning. Some already have `.primary`; do not assume a foreground swap fixes these. Inspect rendered foreground/background and scroll clipping before changing layout. History title and empty-state text also fail while Settings is open, matching the earlier independent inactive-window reproduction.
6. Diagnose sample processing exceeding the frozen timeout independently. Do not increase the timeout or special-case these fixtures.

The four initial missing descriptions are system Touch Bar elements. Final processing audit adds missing descriptions with unavailable elements and a parent/child mismatch. Prior minimal probes establish system reproduction, not a waiver. No current evidence supports changing accessibility ownership or hiding controls to silence these issues.

## Reproduction

Ignored local `build/AccessibilityAudit.xcconfig`:

```
PRODUCT_BUNDLE_IDENTIFIER = app.paperloft.a11y.$(PAPERLOFT_DEVELOPMENT_BUNDLE_IDENTIFIER)
CODE_SIGN_IDENTITY = -
PAPERLOFT_APP_GROUP_ENABLED = NO
```

With exclusive GUI lock:

```
xcodebuild -project Paperloft.xcodeproj -scheme PaperloftApp -destination 'platform=macOS' -xcconfig build/AccessibilityAudit.xcconfig -derivedDataPath build/Intake11Accessibility -resultBundlePath build/Intake11AccessibilityRetry.xcresult SWIFT_TREAT_WARNINGS_AS_ERRORS=YES '-only-testing:PaperloftUITests/CoreFlowTests/testCoreScreensAccessibilityAudit' test
```

Use a new result path for another run. Archive/upload/submission/release gates were not attempted.
