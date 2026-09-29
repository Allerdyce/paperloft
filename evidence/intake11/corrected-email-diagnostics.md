# Corrected email diagnostics — 2026-09-29

Production source revision `4b919a3`. No frozen scorer, threshold or fixture bytes changed. Root full hostless unit run passed 99 XCTest + 109 Swift tests (208 total), build/Intake11RecognitionUnit.xcresult. PDF rasterization was independently checked with 3 deterministic tests before merge, including rotations, nonzero page origin and large-page bounds.

## Parser diagnostic results

Same five-message smoke now 5/5 exact selected identities, zero body-suppression observations, 1/1 correct negative; both body receipts 2/2 date/total/vendor/kind. All originals preserved. Run: build/email-diagnostics/parser-corrected-smoke-20260929.

Full 80 synthetic messages: 80/80 exact identities against the provisional generator contract, 16/16 correct negatives, zero body-suppression observations, no processing errors, all original hashes preserved. 40 bodies rendered using WebKit; 40 attachment-bearing messages suppressed the body. Candidate outputs all report parser backend. Run: build/email-diagnostics/parser80-corrected-20260929.

Unchanged frozen scorer invoked directly with --mode private and explicit synthetic paths (report-only; no private samples accessed). Body subset: 24/24 each date,total,vendor,kind, zero missing predictions. All-message projection: 64/64 date,total,vendor; 80/80 kind; zero missing predictions. Category is unlabelled and not assessed. Scorer outputs build/email-diagnostic-parser80-body-score.txt and build/email-diagnostic-parser80-all-score.txt.

The development corpus has 8 repeated simple layouts, 16 synthetic merchants and selectable single-page attachment PDFs. Correctness on it is useful regression evidence, not proof of diverse real-world accuracy or AC-103–105. Provisional first-receipt-attachment identity truth and frozen scorer mode limitations remain as described in Tools/EmailDiagnostics/README.md. No fresh holdout or formal gate verdict.

## Separate on-device model run

Completed system-backend run: build/email-diagnostics/system80-20260929. This run FAILED readiness expectations: 49/80 usable exact selected identities, 16 body-suppression observations, and 16/16 correct negatives. Original hashes all preserved. Frozen report-only scorer: body date/total/vendor/kind 15/24 (62.5%), all date/total/vendor 33/64 (51.56%), kind 49/80 (61.25%). Category is unlabelled and not assessed. Outputs: build/email-diagnostic-system80-body-score.txt and build/email-diagnostic-system80-all-score.txt.

Raw records contain 37 classification refusals across 31 messages (`FoundationModels.LanguageModelError.refusal`). The initial extraction returned fields, but independent type classification failed; these records correctly receive no field credit in the projection. Conservative production selection retained unresolved attachments and in some cases also the cover body. There were no thrown candidate/top-level processing errors. The CLI exited zero because it did not include `fields.classificationError` in its failure accounting; that reporting defect is fixed in1b7e517; root model-free regressions pass. Exit zero was not an accuracy pass. Refused calls are not retried and safety settings remain unchanged.

Cold Vision startup latency remains independently observed at about 64 seconds; these diagnostics are not a performance gate. Parser success above does not substitute for model accuracy. Independent audit confirms these counts and limitations: evidence/email-diagnostics/system80-independent-audit.md.
