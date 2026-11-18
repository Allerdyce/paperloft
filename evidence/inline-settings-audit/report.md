# Inline sidebar Settings accessibility diagnostic — 2026-11-18

Branch local/inline-audit-20261118 from2974d92. Additive XCTest only; no product change, no frozen helper edits, no new exceptions.

## Result

The efficient third run built successfully with warnings-as-errors and executed both new tests (Light and Dark). Both FAIL on contrast; no test skips, runtime warnings, anchor visibility failures or selector failures. All four section positions were audited with the frozen `auditAccessibility(app)` helper. This is diagnostic evidence, not an AC-13 pass.

- Command: signed PaperloftApp Debug `xcodebuild test -only-testing:PaperloftUITests/InlineSettingsAuditTests`, using config/PaulDevelopment.xcconfig.
- Result: `build/InlineSettingsAudit-20261118-r3.xcresult`.
- Log: `run-20261118-r3.log`; summary: `summary-r3.json`.
- Eight full-window screenshots and geometry snapshots: `selected-r3/`.
- Complete raw exported audit attachments: `attachments-r3/` (local diagnostic artifact).

## Findings

18 `Contrast failed` findings are outside the viewport (y215 through990): Original documents y1002, File name y1054.8, Example y1085 (also its nested child), and Legal and professional services y993. The same filing text has no contrast finding once scrolled fully visible. The final Categories view has no app-owned finding in either appearance. All these findings remain failures; none was suppressed.

Three Light `Contrast nearly passed` findings are fully visible: “Filling in details yourself, browsing and undo are always free.” It appears at y600 in the first two snapshots and y300 at the filing scroll position. This is a genuine app-owned text contrast repair; its current foreground is secondary.

## Proposed repair

Keep Settings as the user's requested sidebar page, with inline General/Filing/Categories tabs reusing current sections. Keep the separate native Settings window unchanged. Switch the Free explanation to primary foreground. Audit every actual inline tab unsuppressed and verify keyboard reachability. The repair below was subsequently applied and checked.

## Harness history

Run1 compiled but incorrectly queried the theme as SegmentedControl; macOS exposes RadioGroup. No product audit reached. Run2 corrected the selector but geometry collection fetched every property separately, taking over2min per stage; interrupted with SIGINT (exit75), not counted as a result. Run3 uses one debugDescription snapshot and catches each thrown audit error before moving to the next stage, without removing assertions. GUI lock held for all runs and released afterward.

## Repair and scoped verification

Implemented inline General/Filing/Categories selection in the sidebar Settings page; only the active section is mounted. Separate native Settings window remains unchanged. Free explanation now uses primary foreground. This removes offscreen cross-section audit contamination without suppressing findings or changing the owner’s Settings-page interaction.

- `build/InlineSettingsAudit-20261118-repair1.xcresult`: **5/5 PASS**,0 skipped,0 runtime warnings. New Light/Dark audits each check all three actual sections. Existing NavigationTests, sidebar-settings-stays-in-main-window test, and SettingsPolishTests pass. `repair1-summary.json` is the exported summary.
- Raw signed Debug and Release clean builds with SWIFT_TREAT_WARNINGS_AS_ERRORS=YES: both exit0, both BUILD SUCCEEDED,0 warning/error lines. Local logs `strict-Debug.log` and `strict-Release.log`. Products are in `build/InlineStrictDerivedData/Build/Products/`.
- `scripts/verify_lock.sh`:185 locked files and protected baseline PASS (`lock.log`).
- `git diff --check`: PASS.
- Inspected rendered Light General and Dark Filing screenshots: inline section controls and existing fields fit; Settings stays in the main window. Six repaired section screenshots/geometry snapshots remain locally under `repair1/`, not committed.
- No full CI or phase PASS claimed; root will integrate and run the complete suite. Keyboard persona verification remains separate.
