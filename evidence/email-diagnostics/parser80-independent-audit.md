# Independent parser-80 evidence audit

2026-09-29. Reviewer: tax_export. Scope: read-only source and artifact audit; no extraction rerun, model call or GUI use. Result: reported diagnostic counts are supported. This is not a formal gate, difficulty approval or independent holdout score.

Reviewed root run: `build/email-diagnostics/parser80-corrected-20260929`. Build manifest identifies clean revision `4b919a38f50ec85cdb09c9e7c6a4146157a52b3e`, parser backend, automatic rendering. The current diagnostic binary hash and every recorded source hash match that manifest/revision. All seven projection output hashes and the raw, run-manifest, label and projection-script hashes match the projection manifest.

## Independent recomputation

- Exactly 80 unique raw rows match all 80 requested fixture IDs and all label IDs: 28 PDF, 24 body, 12 mixed, 16 non-receipts. No missing, duplicate or extra predictions.
- Exactly one candidate is selected per message. Selected kinds are 48 receipts, 16 invoices and 16 non-receipts; all selected fields record the parser backend. There are no top-level or candidate processing errors.
- All 80 selected identities match the provisional truth contract. For 40 PDF/mixed messages, selection is attachment index zero and its content hash equals the first decoded MIME PDF's SHA-256; each PDF-part count also matches. The remaining 40 selections are bodies, comprising 24 receipts and 16 negatives. No accompanying body is selected alongside an expected receipt attachment.
- All 16 negative messages are selected as `not_receipt`. Actual selected receipt counts match the expected per-message count in every case.
- All 80 fixture hashes match the run manifest, raw source hash and present source bytes; every raw preservation flag is true.
- Using the unchanged frozen scorer's matching functions independently: date, total and vendor each match 64/64 financial messages. The body-only financial subset matches 24/24 for each. Kind is 80/80 overall and 24/24 in the body subset. Vendor matching is the frozen normalized/fuzzy rule, not a claim of character-for-character equality.

These counts agree with `build/email-diagnostic-parser80-all-score.txt` and `build/email-diagnostic-parser80-body-score.txt`. The scorer is byte-identical to protected kit baseline `640eab51a302cef28e57cd17f481673043c7dc9d`. Its `private` mode is used only for report-only behavior; these are synthetic inputs, not private receipts. No thresholds or difficulty check run in that mode. Category has no truth labels: the printed 0/64 and 0/24 category rows must be disregarded rather than represented as measured category accuracy.

## Isolation and limits

`Tools/EmailDiagnostics/main.swift` enumerates EML inputs and runs Mail materialization, MailReviewPreparation, ReceiptEngine and the renderer. It does not open label files or branch on fixture IDs to produce fields. The separate `scripts/project_email_diagnostics.py` opens labels only after predictions exist. Wrong or ambiguous selection is not allowed to earn field credit by choosing the best-matching candidate; missing projected predictions remain in truth denominators.

Exact attachment truth comes from the explicit synthetic generator contract: receipt PDF first, terms second. The projector recomputes the original MIME payload hash. This is transparent development truth, not independent human-approved identity labeling. Body identity is role-based rather than an exact generated PDF hash, since rendering adds headers and generated metadata.

This eight-layout corpus was used to diagnose and repair the implementation. It is not held out and its perfect parser score does not establish realistic difficulty, general accuracy, AC-103, or launch readiness. The diagnostic runner also does not exercise the complete app-owned intake/transaction/UI path. Existing application tests and native verification remain separate evidence.
