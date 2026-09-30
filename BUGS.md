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
