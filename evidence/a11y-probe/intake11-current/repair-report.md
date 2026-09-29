# Focused repair audit

2026-09-29. Audited isolated revision `790acf5`, merged root `c13ba70` plus native filter/action and measured text contrast changes. The unchanged frozen all-types audit still FAILS; exit 65. No filtering, thresholds, frozen tests or acceptance claims changed.

## Verified changes

- Debug warnings-as-errors build and isolated build-for-testing PASS.
- Actual app PID 51255 ran from `/Users/builder/Factory/paperloft-intake11-handoff/build/A11yRepair/Build/Products/Debug/Paperloft Receipts.app`, under isolated bundle ID `app.paperloft.a11y.app.paperloft.receipts.development`, ad hoc signing and no app groups.
- All four product missing-action findings are absent: Library Type, Category, Year filters and Settings scanned-pages popup now use the native accessible popup.
- All eleven previously reported contrast-near-threshold findings are absent. Stronger foreground applies to the measured empty-Inbox copy, Library column headers/footer, and scanning help.
- The sample review form appeared about one second after waiting began. Previous 60-second processing stall did not recur, so no stalled-process sample was captured. This run did audit the populated review form.
- GUI lock acquired exclusively for testing and released afterward. No owner documents used.

## Remaining failures

21 findings: 13 contrast (11 failed, 2 near threshold), 6 missing descriptions, 1 parent/child mismatch, 1 missing action. Details are preserved in `repair-issues.txt`.

- Two empty-Inbox text blocks still fail contrast: Paste explanation and filetype/source-preservation footer.
- Settings appearance explanation and offscreen filing controls/help fail contrast. Inactive/obscured History title and explanatory copy also fail while Settings is open.
- Three Issue status pills fail contrast in the now-covered review state. These already use primary text, and Issue is expected for a stub result disagreeing with the synthetic source; the label alone does not mean import failed.
- Two review captions are newly measured near threshold: Receipt preview and copy/move explanatory copy. A subsequent two-line change strengthens these to primary text, and its warnings-as-errors Debug build passes. That follow-up has not yet been re-audited.
- The remaining missing action belongs to system `emoji & symbols`; missing descriptions are five system Touch Bar instances plus its emoji popup. The parent/child mismatch has no available element. These remain unsuppressed failures.

## Contrast discrepancy, not a waiver

The audit's own cropped element images are saved beside this report, avoiding unrelated desktop content. Paste and footer text look dark against pale backgrounds. Counting RGB pixels in those PNGs gives dominant text/background pairs of `(38,38,38)` / `(246,248,247)` and `(39,39,39)` / `(255,255,255)`. Treating those values as sRGB and applying standard relative luminance gives approximately 14.19:1 and 14.94:1. The selected Issue crop similarly shows dark text on a pale orange background.

This pixel calculation does not account for embedded color profiles, all antialiased edges, or XCTest's internal algorithm. It is diagnostic evidence for a focused rendering/audit reproduction, not a replacement contrast certificate or permission to suppress the findings. Further blind darkening of already-primary text is not justified by these crops.

## Evidence

- `/Users/builder/Factory/paperloft-intake11-handoff/build/A11yRepair.xcresult`
- `build/a11y-repair-audit.log`, `build/a11y-repair-build.log`, `build/a11y-repair-testbuild.log`
- `build/A11yRepairAttachments/manifest.json`
- Follow-up caption compile: `build/a11y-review-caption-build.log`

Build and audit command use the earlier report's isolated xcconfig; audit uses `test-without-building`, derived data `build/A11yRepair`, and result path `build/A11yRepair.xcresult`. No further identical audit is needed; the next run should verify the newly changed captions or a separately evidenced fix.
