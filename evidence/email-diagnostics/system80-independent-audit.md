# Independent system-model 80-message diagnostic audit

2026-09-29. Reviewer: tax_export. Read-only audit; no model rerun or GUI use. The reported diagnostic counts are supported, but the system-model outcome does not support an accuracy/readiness pass.

Run: `build/email-diagnostics/system80-20260929`; backend `system`, rendering `automatic`, clean recorded revision `4b919a38f50ec85cdb09c9e7c6a4146157a52b3e`. All 80 unique raw IDs match the manifest and synthetic labels. Raw/projection/label/script hashes, all seven projected output hashes, recorded source revision hashes and the present diagnostic binary hash match. All 80 source bytes match their pre-run and present hashes. The scorer is byte-identical to protected kit baseline `640eab51a302cef28e57cd17f481673043c7dc9d`.

## Recomputed outcomes

| Synthetic group | Messages | Usable exact selected identity | Accompanying body selected contrary to attachment truth | Messages with classification refusal |
|---|---:|---:|---:|---:|
| PDF receipt | 28 | 18 | 10 | 10 |
| Body receipt | 24 | 15 | 0 | 9 |
| Mixed receipt/terms | 12 | 0 | 6 | 12 |
| Non-receipt | 16 | 16 | 0 | 0 |
| Total | 80 | 49 | 16 | 31 |

There are **37 candidate classification errors across 31 messages**. Every error is recorded as `FoundationModels.LanguageModelError.refusal`; all 37 affected candidates are selected. The 31 identity failures consist of 22 messages with multiple selected candidates and nine body messages with a single selected candidate whose classification failed. These are partial model classification failures, not proven incorrect numeric-field extractions. The selection policy deliberately preserves unresolved candidates; retaining them does not satisfy the provisional exact-selection truth contract.

All 16 negatives are correctly classified. Exact attachment identity was independently checked against the first decoded MIME PDF's hash and index, with the expected PDF-part count. Body identity uses the body role. This remains the transparent provisional generator contract, not independently approved identity labeling.

Using the frozen scorer's matcher independently, keeping the full truth denominators:

- Financial-message date, total and vendor: each **33/64 (51.56%)**.
- All-message kind: **49/80 (61.25%)**.
- Body-only date, total, vendor and kind: each **15/24 (62.50%)**.

These match `build/email-diagnostic-system80-all-score.txt` and `build/email-diagnostic-system80-body-score.txt`. The projector emits only 49 usable predictions overall and 15 in the body subset. The remaining 31 and nine are missing predictions, counted as misses; it does not cherry-pick accurate fields from ambiguous or refused selections. Category is unlabelled and its printed zero rows are not measured category accuracy.

## Runner status limitation

Raw top-level `error` and candidate `error` counts are both zero. `SystemBackend` records second-stage classification failure in `fields.classificationError`, retaining the first-stage extracted fields with reduced confidence. `MailReviewPreparation` treats such attachment candidates as unresolved. The current diagnostic runner's `failedMessages` condition inspects only top-level/candidate errors and source preservation, **not `fields.classificationError`**. Therefore process completion or exit zero cannot be interpreted as a successful model run. The projection correctly detects these field-level errors and denies them identity/field credit. This runner exit-status omission should be repaired separately; this audit does not alter the runner or results.

Prediction code does not read labels; the separate truth projector does. The frozen scorer runs in report-only `private` mode solely to avoid applying unrelated gates; all inputs here are synthetic. This eight-layout development corpus was used during repairs, is not held out, and has no approved realism/difficulty verdict. Parser results must remain separate: its earlier 80/80 result does not replace or repair these system-model failures. No formal gate, full accuracy, or launch-readiness claim is warranted.
