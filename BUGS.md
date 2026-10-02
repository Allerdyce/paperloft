# Open development findings

- P3 / AC-13: default all-types accessibility audit fails. Latest complete UI run before PDF fix: build/Tests-20260926-234415.xcresult (15 findings, remaining five tests pass). System Touch Bar description, emoji popup description/action, and parent-child mismatch reproduce independently without Paperloft code; evidence/a11y-probe/report.md. No suppression/waiver; parked framework findings continue to block acceptance.
- P3 review: native PDF Page description is fixed using public accessibility-protocol page labels, verified by build/P3-pdf-label.xcresult (14remaining findings). Category overlap/contrast is fixed and verified by audit plus live UI.
- P3 settings: contrast findings include native active/inactive window titles and inactive History content; unresolved, no blanket platform exemption claimed.
- P5 isolated branch: StoreKitTest header deprecation fails strict import. Three distinct supported approaches failed; no suppression retained. Runtime purchase flows not verified; component not merged.

- 1.1 Mail selection: synthetic diagnostic smoke `email-001` has a visibly valid receipt PDF but production Vision yields no text, causing parser `not_receipt` and selection of the cover body. Open recognition investigation and fail-closed guard; evidence/intake11/email-diagnostic-smoke.md.
- 1.1 Mail classification: `email-053` terms attachment says it is not a receipt or invoice, but parser marks it invoice from the incidental word; both PDFs are selected. Generic heading/transaction classification repair under review; frozen tests/scorer unchanged.
- Latest full accessibility regression at403f362:18 unsuppressed findings,15functional UI tests pass,1audit test fails. See evidence/intake-queue/native-regression.md. Earlier counts above are historical.

2026-09-29 update: both synthetic Mail selection findings above are repaired in4b919a3 (bounded PDF scaling, document-heading evidence, blank-OCR refusal). Same5 examples and full80 parser diagnostic now match all expected identities. System-model and varied real-world accuracy remain separate; cold OCR latency remains open.

- 1.1 on-device model diagnostic (2026-09-29): separate classification refused 37 candidates across 31/80 synthetic emails. Exact selection49/80; full labelled date/total/vendor33/64. Conservative retention can also surface a cover body when attachment classification is unresolved. Routing repair (local/intake11-handoff): a read receipt/invoice/bill now stays routing-positive despite failed refinement, suppressing the cover body while keeping classificationUnavailable review; not_receipt+failure, invalid kinds and read failures stay unresolved. See evidence/intake11/refinement-routing-repair.md. No safety bypass/retry; unresolved classifications remain review issues. CLI exit accounting omitted classificationError despite retaining it in raw output; reporting repair1b7e517 is verified. Product classification reliability remains open. Evidence: evidence/intake11/corrected-email-diagnostics.md.

## QA 2026-09-30 (builder-run persona pass; see evidence/qa/2026-09-30-summary.md)

| ID | Sev | Persona | Steps | Expected | Actual |
|---|---|---|---|---|---|
| QA-01 | P1 | First-timer | Fresh QA/Release launch | "Try with samples" (SPEC 6.3 P0: five samples, first filing within 60 s) | Not offered; samples exist only in Debug builds |
| QA-02 | P1 | First-timer | Export Q3 accountant pack | Documents named as in the library (`2026-08-18_Fern-Cafe_132.38.png`) under plain category folders | Files and category folders are named with UUIDs, and the pack folder name ends in a UUID |
| QA-03 | P1 | Keyboard-only | Default macOS keyboard settings, fresh launch | Choose Library Folder reachable by keyboard | The onboarding button has no default action or menu command. (Correction: Import Receipts… has ⌘I; only ⌘O was tried during the session.) |
| QA-04 | P2 | First-timer | Review documents 001 and 025 | "Issue" explains what needs checking | Issue badge but no field highlighted and no reason shown |
| QA-05 | P2 | First-timer | Import an .eml with a receipt attachment | Inbox row named after the attachment or email | "Attachment-<UUID>.pdf" |
| QA-06 | P2 | Messy data | Import a non-receipt | Says it doesn't look like a receipt and offers Remove | Empty required fields, type "Receipt", Confirm disabled, no explanation |
| QA-07 | P2 | Messy data | Rename the library folder in Finder, then file | The security-scoped bookmark follows the rename, or the stale path updates | Filing is refused until the folder is chosen again; the sidebar and Settings show the old name |
| QA-08 | P2 | Keyboard-only | Return on a flagged total (document-044) | A flagged total needs a deliberate confirmation | Return files it (41.65 against an actual 39.31) |
| QA-09 | — | Keyboard-only | ⌘O in the Inbox | Opens Import Receipts… | **Not a bug:** Import Receipts… is ⌘I; ⌘O was the wrong key to try. Withdrawn. |

**QA status (2026-09-30):**
- **Fixed:** QA-01 Try with Samples, QA-02 readable pack names, QA-03 keyboard library choice (all a7bd99d); QA-04 Issue explanation and QA-06 non-receipt note (this change).
- **Fixed later on 2026-09-30:**
  - QA-05: attachments show the sender's sanitized filename; staged paths stay UUIDs.
  - QA-08: Return on an unverified total moves focus to the total instead of filing. Clicking Confirm or pressing ⌘Return files it, and a corrected total can be confirmed with Return.
  - QA-07: a renamed or moved library folder is followed through its bookmark, both at launch (the stale bookmark is renewed) and while open (on activation and before filing). The search index rebuilds for the new path. Unit tests cover it outside the sandbox, and LibraryRenameUITests checks a rename in the sandboxed app.
- **Open (P2):** none.

**Second design review (2026-09-30-r2, `evidence/design/2026-09-30-r2-critique.md`):**

| ID | Severity | Found | Problem | Status |
|---|---|---|---|---|
| R2-01 | P1 | critic | Undo from History made the receipt disappear (in neither Library nor Inbox) | **Fixed:** Undo returns it to the Inbox with the confirmed values; History says "Returned to the Inbox for review" and offers Show in Inbox |
| R2-02 | P1 | critic | Remove from Inbox was silent and couldn't be undone | **Fixed:** Edit › Undo (⌘Z), plus a "Removed … · Undo" notice; bulk removal is one undo step |
| R2-03 | P1 | lead, while fixing R2-01 | ⌘Z was hard-wired to "Undo Last Filing", so undoing a typo in a review field undid the previous filing | **Fixed:** standard Undo/Redo restored; filing and removal register with the window's undo manager, so text fields undo typing first |
| R2-04 | P2 | critic | No feedback after Confirm; selection jumped to the top row | **Fixed:** "Filed to 2026/…/ · Undo" notice; the next row in list order is selected |
| R2-05 | P2 | critic | One ↓ in the Inbox list moved focus into Vendor | **Fixed:** review only takes focus when the list doesn't have it |
| R2-06 | P0 | lead, full CI | The app crashed once (in ReviewFormTests) with AppKit's "needs another Update Constraints in Window pass" exception. An NSSplitView kept resizing during layout, right after Inbox rows gained a wrapping merchant line. | **Mitigated:** row lines are single-line, so row height no longer depends on pane width. No crash in the 6 repeat runs of the failing sequence since; the root cause isn't proven, so watch for it. |
| R2-07 | P2 | lead, full CI | ⇧⌘E right after launch did nothing: the menu item's disabled state (library not yet open) could stay stale | **Fixed:** the command is always enabled; a request during startup or another task opens the sheet when it ends; with no library it explains |
| R2-08 | P1 | lead, AC-10 run | Opening a document for review held the main thread for 0.4–0.6 s (AC-10 allows 250 ms). The review pane rebuilt its split view, preview and fields for every document, and SwiftUI asked each review pop-up for its text baseline on every layout pass; each answer re-entered window layout and measured every currency in the menu. | **Fixed:** the split view and preview stay in place between documents and only the fields column is rebuilt; on first appearance the fields follow one frame after the preview; the pop-ups state their baseline and cache their size. Parser run: worst stall 226 ms and 207 ms (warm-up and measured). |
| R2-09 | P2 | lead, AC-10 run | Late in a 100-document system run, each Inbox refresh held the main thread for about 200 ms (the measured iteration stalled for 258 ms). Every row and filter chip status check built `Money`, which created a new `NumberFormatter` each time. | **Fixed:** `Money` looks up each currency's decimal places once. System run: worst stall 234 ms / 176 ms. |
- **Withdrawn:** QA-09.

## Third design review, 2026-10-01 (critic; `evidence/design/2026-10-01-critique.md`)

| ID | Sev | Found by | Summary | Status |
| --- | --- | --- | --- | --- |
| R3-01 | P1 | critic | Review pane layout: the fields column narrowed after a filing, banners and notes pushed content past the window edges, rows overlapped and one wrapped | **Fixed:** one stable fields pane, scrolling fields over a pinned button bar, banner in the filter row, every row the same shape |
| R3-02 | P1 | critic | Paywall: no primary action, same headline from every entry point, Pro state kept the Free copy, stale restore message | **Fixed:** reason-specific headline, radio plan picker with one default button and Not Now, Pro content with plan details, results cleared on close |
| R3-03 | P2 | critic | Limit reached looked like Processing and wasn't counted; no reset date; "Enter Details Myself" prefilled fields | **Fixed:** neutral badge counted under Issues, reset date in the pane, Settings and paywall, "Fill In Details" with an honest explanation |
| R3-04 | P2 | critic | Undo brought a document back renamed, at the bottom, read again | **Fixed for filings made this session** (exact restore, no re-read). After a relaunch Undo still re-reads the document with the confirmed values |
| R3-05 | P2 | critic | Export allowed an empty period | **Fixed:** Export disabled with "No filed receipts in Q4 2026. Choose another period." |
| R3-06 | P2 | critic | Dark mode selected-row contrast 2.76:1 | **Fixed:** darker list selection, 6.3:1 with white |
| R3-07 | P2 | critic | Banner path syntax, tiny dismiss target, short duration; Free watched-folder copy; stale restore result in Settings | **Fixed** |
| R3-08 | P2 | critic | Reference-design elements (sidebar Settings, heading, chips, checkboxes, date field, Library cards) below 4 | **Owner decision** in PROPOSALS.md |

## Fourth design review, 2026-10-01 (critic; `evidence/design/2026-10-01-r4-critique.md`)

Lines below 4 fell from 21 of 36 to 7 (8 of 40 with the menu bar extra). Five of the remaining eight are owner decisions (PROPOSALS.md).

| ID | Sev | Found by | Summary | Status |
| --- | --- | --- | --- | --- |
| R4-01 | P1 | critic | One Edit › Undo reversed both a filing and a removal | **Fixed:** each action is its own top-level undo group; `testOneUndoReversesOneAction` fails on the old code |
| R4-02 | P2 | critic | Dark-mode focused selection still white on light green (2.76:1); the list tint didn't reach AppKit | **Fixed:** dark text on the emphasized selection (5.6:1) |
| R4-03 | P2 | critic | Notice banner covered the Issues chip and stayed over 45 s | **Fixed:** banner in the Select all row; 8 s, at most 30 s while hovered |
| R4-04 | P2 | critic | "Finishing a library change…" drawn under Remove and Confirm after filing | **Fixed:** the banner animation no longer cross-fades the fields column |
| R4-05 | P2 | critic | Row badge and form disagreed ("Check date and total" vs Total only) | **Fixed:** both use `ReviewChecks` |
| R4-06 | P2 | critic | Total without a currency; menu bar count too faint; Help said "Accountant packs" | **Fixed** |
| R4-07 | P2 | critic | Two title bands | **Open, owner decision.** Hiding the toolbar title moved the toolbar buttons to the leading edge, and a flexible spacer didn't bring them back, so it was reverted. The locked heading text keeps both bands |
