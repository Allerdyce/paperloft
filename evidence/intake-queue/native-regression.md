# Complete native UI regression after owned intake

2026-09-29, root product revision `403f362` (documentation HEAD `75949b8`). No test exclusions or frozen test changes.

All 15 functional UI tests passed. Coverage includes draft restoration, duplicate filing/Undo, invalid amount handling, keyboard editing/filing/search/export, Inbox row selection, email body and attachment imports across restart, menu reopening, navigation, appearance persistence, status filters, Library filters/View, receipt deletion/restoration/tax export, sidebar Settings, and watched-folder bookmark pause/resume/relaunch/background intake.

The sixteenth test, the unchanged all-types accessibility audit, failed with 18 findings: 10 contrast failures, 6 missing descriptions, 1 parent/child mismatch and 1 missing action. No near-threshold findings remained. System Touch Bar/emoji findings remain recorded; none were suppressed. These results do not establish accessibility or release readiness.

Entire target: 16 tests, 665.650 seconds, xcodebuild exit 65 due to accessibility. Result: `build/Intake11OwnedNativeAll.xcresult`; log: `build/intake11-owned-native-all.log`. Test command:

```
xcodebuild -project Paperloft.xcodeproj -scheme PaperloftApp \
 -destination 'platform=macOS' -derivedDataPath build/Intake11Native \
 -resultBundlePath build/Intake11OwnedNativeAll.xcresult \
 CODE_SIGN_IDENTITY=- SWIFT_TREAT_WARNINGS_AS_ERRORS=YES COPY_PHASE_STRIP=NO \
 -only-testing:PaperloftUITests test
```

This run predates the later temporary-copy cleanup commit `5b0a88f`. That change has separate scoped unit/build evidence; no claim that this UI run covered subsequent changes. GUI lock released after the entire target finished. Synthetic fixtures only. Full CI and formal acceptance remain unclaimed.
