# Owner receipt-library changes — scoped verification, 2026-09-27

Implemented double-click/Open Receipt via native Quick Look, context actions, direct recoverable Delete, persistent Recently Deleted restore UI, blue Processing/green Ready to review/orange Duplicate or Needs attention pills, inbox counts, more spacious document rows, and a clear Tax & Accountant Export entry point.

Independent reviewer receipt_ux_verifier passed export core, deletion core/model, source review and integrated native UI evidence. This is a scoped local result, not P3 acceptance or launch readiness.

- Local preflight:38 PASS,1 WARN,0 FAIL,0 TFAIL; Foundation Models available. `build/ux-request-preflight.log`.
- Protected baseline PASS before and after changes: `build/receipt-ux-baseline.log`.
- Export:12 independent tests PASS, including recorded-tax unknown/zero and separate currency totals. Tax branch47b0883 integrated a46d9fa.
- Deletion: original strict89-test suite PASS; six final deletion core cases and actual AppModel case independently PASS. Finder-rename metadata mismatch found by reviewer, fixed and regression-tested. Integrated4652e1b+7f05aa4.
- Combined optimized Release build PASS, no compiler warning/error: `build/receipt-ux-release.log`.
- `build/ReceiptUX2.xcresult`:2 native UI tests,0 failures,80.291s. New ReceiptLibraryUXTests proves actual receipt content opens on double-click, delete exclusion, restart persistence, restore and tax export entry. Existing InboxRowDiagnosticTests proves row editing/selection, duplicate state and filing Undo compatibility.
- First new test failed because it expected filename as Quick Look window title; actual macOS window title is Quick Look and document contents were visible. New un-frozen test corrected to assert native window and source text. No existing tests weakened.
- Root and independent reviewer inspected exported screenshots in `build/receipt-ux-attachments`: library actions, ready/duplicate pills and export sheet legible/unclipped. Transient Processing appearance is code-reviewed, not independently captured on screen.

History Undo remains available for existing recovery behavior; Delete no longer requires navigating there. Deleted files are retained, never permanently removed. Tax pack reports recorded data, not deductions or a filed return. Existing full accessibility/performance/commerce/intents/signing/release gates remain open.

## Appearance and temporary development signing followup

- Owner requested System/Light/Dark switch. AppStorage preference applies to main window, Settings and menu-bar view, default System.
- Optimized build `build/appearance-release.log` PASS. Native `build/AppearanceUX2.xcresult` PASS: selects Light, verifies preference across termination/relaunch, selects Dark then restores System. Root inspected screenshots showing Light Paperloft alongside dark macOS windows and Dark Settings/main window.
- Initial new test asserted a String radio value; native control supplies NSNumber. Corrected new test assertion to NSNumber1, preserving selection requirement. No product workaround or frozen test change.
- Owner provided paid team GQ4UA5C6RQ. Opt-in config/PaulDevelopment.xcconfig signs separate bundle app.paperloft.receipts.development. `build/paul-development-build.log` BUILD SUCCEEDED; root and independent reviewer codesign --verify --deep --strict PASS and authority/team checked. No archives/uploads/production identity changes.
- Protected baseline `build/appearance-baseline.log` PASS.
