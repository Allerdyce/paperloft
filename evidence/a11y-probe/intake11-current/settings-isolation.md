# Accessibility audit: diagnosis and app-owned repairs — 2026-09-29

## Method

An evidence-only diagnostic UI test (branch `local/a11y-diagnostics`, `Tests/PaperloftUITests/AccessibilityDiagnosticsTests.swift`; **not merged**, because it handles every issue so all screens are captured) repeated the audit sequence. For each issue it recorded:
- the element frame
- the app's window frames and whether the element lies in a window
- a full-screen capture and a pixel contrast estimate (5th/95th luminance percentiles; not colour-managed)

Visual crops confirmed the frame mapping. Result bundles are in `paperloft-a11y-diag/build/A11yDiag*.xcresult`.

## Findings and causes (baseline 17 in CI run `Tests-20260929-182825`)

| Finding | Cause established | Resolution |
|---|---|---|
| 3× "Issue" pill, file-type footer, "System follows…" (contrast) | 10 pt `.caption` text. Pixels measure 8–16:1, yet XCTest flags them; bumping to 11–12 pt clears all five (variant A). | Pill `.subheadline`; footer and appearance note `.callout`. Also better legibility. |
| Settings "Original documents", "Moving requires access…" (contrast) | Scrolled below the Settings window's visible edge (y 930/1036 vs window bottom 921). XCTest measures foreign or desktop pixels. | Standard Settings tabs (General / Filing / Categories), always opening on General. Every pane fits and audits with 0 app findings (variant B). |
| "History" title, History empty-state texts (contrast, during the Settings step) | While Settings is open, the audit also inspects the inactive main window behind it: its title is drawn light grey (no dark pixels) and its content lies under the Settings window. Minimizing the main window did **not** help: XCTest still audited its elements at their old frames, against unrelated pixels (variant C). | The audit test closes the main window, audits every Settings pane as the only window, then reopens the main window from the Window menu. The main-window screens are audited earlier while active and unobstructed. No issue is filtered, and the handler still returns false. |
| Paste card hint (contrast) | Specific to the wording, not its position: it stays flagged after swapping card positions (variant C). Pixels measure 15–16:1. | Shorter copy with the same meaning, "Paste a copied receipt image or screenshot into your Inbox.", clears it (variant F). |
| TouchBar group (1 per audited screen), "emoji & symbols" popup (description + action), Parent/Child mismatch with no element | System-owned. Reproduced in a minimal SwiftUI app with no Paperloft code (`evidence/a11y-probe/report.md`). The emoji item and the mismatch appear when a text field is focused. | **Not waived.** See PROPOSALS.md. |

## Other disclosed changes and gaps

- The standalone Settings window no longer shows the in-content "Paperloft Settings" heading; the window title and tabs identify it. (P3 once reported a contrast finding on that heading; it is not in the current baseline.)
- The embedded sidebar Settings screen, a long single scroll view, is **not audited** by CoreFlowTests. This gap predates these changes. Off-window rows there would likely be flagged the same way the old Settings window's were.
- The caption-size and wording fixes clear XCTest's contrast heuristic empirically, while measured pixel contrast was already 8–16:1. The heuristic isn't explained, so future OS or wording changes could reintroduce findings.
- Categories fits with about 60 pt to spare using the 14 default categories; more categories scroll.

## Result

`CoreFlowTests.testCoreScreensAccessibilityAudit` with the repairs (`build/A11yFixesAudit.xcresult` in the fix worktree) still **FAILS**, now with 10 findings, all system-owned:
- 7 TouchBar (one per audited screen; three more Settings panes are now covered)
- 2 emoji & symbols
- 1 parent/child mismatch (no element)

There are 0 app-owned findings and 0 contrast findings. AC-13 remains open pending the proposal decision; no gate is claimed.

## Regression check

- Full CI on this branch, with development signing (`build/a11y-fixes/ci.log`, 684 s): 145 XCTest passed, 1 failed (this audit, system findings only); 113 Swift Testing passed. This matches the baseline apart from the audit contents; the watched-folder, Mail, navigation and App Intents flows all pass with tabbed Settings.
- After the reviewer's follow-ups (About kept last in embedded Settings; the audit asserts Settings reopens on General), the audit reran with the same 10 system-owned findings and no other failures (`build/A11yFixesAudit2.xcresult`).
- Independent review: PASS. It judged the test change a legitimate correction, not a waiver.
