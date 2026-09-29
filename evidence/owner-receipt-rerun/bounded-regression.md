# Bounded owner-supplied receipt regression

Local run on 2026-09-29, built from root revision `862caa199d02b167b30e76d7b323d16a5093ffd9`. One execution of three opaque cases; approximately 75 seconds elapsed. This is a targeted diagnostic, not a formal accuracy score or full 1.1 gate.

The ignored helper uses current `ReceiptEngine`/SystemBackend, shared `MailReviewPreparation`, and the native offline email renderer. It records source-side selectable PDF text and original MIME/transcription evidence separately from model predictions. The archived audit and synthetic diagnostic runner were not modified.

| Case | Source-side validation | Outcome |
| --- | --- | --- |
| case-a | Explicit total and tax labels independently agree between the authorized original transcription and its previously generated PDF. | Previously omitted amount text is recognized. Extracted total and tax match those source labels; tax grounding accepts the explicit value. Transaction-date accuracy was not established. |
| case-b | Selected attachment's printed total and receipt date independently checked against its selectable source text. | One attachment selected; body suppressed. Total and date match the source, resolving the earlier body/date-selection regression in this case. |
| case-c | Source confirmation has an explicit date but no printed monetary total. | Date matches; total appropriately remains absent. The model still classifies/selects the confirmation as a receipt, so this remains incomplete and unfileable without additional source or correction. No missing amount was invented. |

Preservation: all three selected input hashes plus the original supplemental transcription reference match their pre-run SHA256 values. User originals were never edited. Three candidates were extracted; two accompanying bodies were suppressed and were not extracted.

Reported failures: zero thrown errors, zero candidate processing errors, and zero `classificationError` values among the three extracted candidates. No refusal was reported in these results, and no model calls or refused calls were retried. This does not turn the incomplete case-c result into a functional pass.

Detailed private evidence remains exclusively under the ignored local path `/Users/builder/Factory/paperloft/build/owner-receipt-rerun/run-20260929-once/`: `results.json`, `source-verification.json`, per-case source evidence, `aggregate-summary.json` and `report.md`. The helper and source/binary hash manifest are in its parent directory. No private filenames, extracted values, source text or receipt images are committed here.

The GUI lock was released after the run. Other private cases, GUI import/filing/Undo, cold-start performance remediation and formal readiness remain outside this bounded check.
