# Synthetic email harness smoke — 2026-09-29

Diagnostic only. No AC-103–105 or formal email gate claim. Frozen scorer, thresholds and fixtures are unchanged; no private or holdout input was accessed.

## Implementation and checks

- Moved MailReviewPreparation byte-for-byte into a shared app source, with explicit unit target membership. Runner compiles the same orchestration and body renderer with production PaperloftKit.
- Strict Swift 6 Release harness build PASS; app/unit build-for-testing PASS. Three MailReviewPreparation unit tests PASS in `build/EmailDiagnosticPreparationTests.xcresult`.
- Five truth projection regression tests PASS (`build/email-projection-tests.log`): missing/ambiguous identity, wrong identity/source changes, duplicate/unknown IDs, and overwrite/hash protection. Predictions never read labels; projection is separate.
- GUI lock was held for the AppKit smoke and released afterward. No window was displayed. This standalone process is not sandboxed; its WebKit success does not supersede the separately documented native sandbox renderer fallback.

## Five-message run

Local retained run: `build/email-diagnostics/parser-smoke-20260929-c` with raw predictions, run/build provenance, fixture hashes, selection observations and projection hashes. Parser backend; automatic renderer; exit 0; five rows, no processing errors, all originals preserved. Manifest/raw filesystem timestamps span approximately 64 seconds (16:01:49–16:02:53 PDT); this is a run interval estimate, not per-message latency instrumentation. Four rendered bodies used WebKit; the mixed-message body was suppressed.

| Message | Production observation | Truth-side treatment |
| --- | --- | --- |
| email-001, PDF | Receipt PDF classified not_receipt; cover body selected with greeting as vendor, email date hint and no total | Wrong identity; no field prediction credited |
| email-029, HTML body | Maple Market receipt selected | Correct identity |
| email-030, plain body | North Software invoice selected | Correct identity |
| email-053, mixed | Receipt and terms PDF both selected; terms classified invoice with no total; body suppressed | Ambiguous selection; no field prediction credited |
| email-065, negative | Body classified not_receipt | Correct negative |

Three of five identities matched the provisional generator contract. One expected receipt attachment instead led to body selection; the summary calls this a body-suppression violation, though the attachment was not itself selected. These are emitted production classifications and consequent production selection decisions, not scorer failures. Detailed parser/recognition diagnosis is separate work; no expected-document rule or label feedback enters the prediction runner.

The unchanged scorer, invoked directly with `--mode private` and explicit synthetic `body-labels.jsonl` / `body-predictions.jsonl`, reports 2/2 each for body vendor, date, total and kind, with zero missing body predictions. Category is unlabelled and its score is disregarded. Two easy body examples do not establish accuracy. Candidate truth remains provisional and corpus diversity limitations remain in the tool README.

## Retained unsuccessful setup attempts

`parser-smoke-20260929` failed before prediction because the harness had not created the library parent; this originally surfaced as an uncaught top-level error. `parser-smoke-20260929-b` retained five materialization errors because the destination parent was missing. Harness setup now creates both parents, catches setup errors and exits nonzero for processing errors. Neither failed attempt counts as a successful extraction run. Their folders/logs remain under build/email-diagnostics; no output was overwritten.

No 80-message or system-model run was performed as part of this commit. Run/build hashes identify the exact dirty development source at the smoke; the builder will record a fresh revision/hash manifest for subsequent runs.
