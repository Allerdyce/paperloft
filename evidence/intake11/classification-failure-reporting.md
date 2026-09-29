# Partial classification failure reporting — 2026-09-29

Read-only product review at root revision `862caa199d02b167b30e76d7b323d16a5093ffd9`. No model execution, prompt changes, refusal retries, GUI interaction or private inputs were used for this change.

## Observed diagnostic gap

Retained synthetic `build/email-diagnostics/system80-20260929/raw-predictions.jsonl` has 80 rows, 31 messages with 37 returned classification errors, all named `FoundationModels.LanguageModelError.refusal`. All 37 affected candidates remain selected. There are zero outer errors and zero candidate error strings. Raw SHA-256: `b437ef9989ce22127aa0ce40e758aadaac8f2c9dc76587bad6e7ce3004e480de`.

The original diagnostic runner checked only thrown/recorded processing errors and source preservation. A completed field extraction followed by an unsuccessful independent classifier therefore exited zero. The raw fields correctly retained classificationError, and the separate truth adapter already withheld field credit for these candidates. The misleading piece was completion accounting, not fabricated raw predictions or scorer acceptance.

## Scoped fix

The runner now writes `run-summary.json` with separate completed-message, processing-error-message, classification-failure-message, classification-failure-candidate, source-change-message and combined failed-message counts. Partial classification failures yield exit 1. A message with multiple failed candidates counts once in the message denominator and individually in candidate counts. Unselected failed candidates still count as attempted failures. Raw fields, kind, partial values and classificationError remain unchanged. Completion explicitly does not imply an accuracy pass.

The historical system80 run and its manifests remain untouched; these observations are retrospective. No new system/model run was performed.

## Product handling review and remaining proposal

SystemBackend preserves completed fields after a classifier error, lowers confidence and retains the classifier error; cancellation propagates. It does not retry refusals. MailReviewPreparation checks classificationError before kind, assigning unresolved disposition. MailCandidateSelection keeps unresolved attachments both with a confirmed receipt (body suppressed) and without one (body also reviewed). This prevents silent loss of the unresolved document.

The review form already displays “Choose the document type shown on the receipt.” for classificationUnavailable, notReceipt or invalidKind. No new top notice or UI change is proposed in this scoped repair.

A separate follow-up may preserve classificationUnavailable provenance in ExtractionAssessment when kind is not_receipt: the early return currently contains only notReceipt. It still prevents automatic filing and the existing kind-field review message is shown, so this is diagnostic completeness rather than an auto-file safety hole. No product behavior or selection policy was changed here.

## Checks

- Strict Swift 6 complete-concurrency warnings-as-errors Release diagnostic build PASS.
- Model-free status tests PASS: partial fields survive JSON roundtrip, two failures in one message retain correct denominators, processing/source failures remain separate, healthy negatives remain successful, unselected classification failures count.
- Tests compile the unchanged production MailReviewPreparation and confirm both invoice and not_receipt partial classifier failures remain selected/unresolved, retain partial values, cannot auto-file, and follow existing body suppression/fallback behavior.
- Existing five truth-projection regressions PASS. Frozen scorer/tests/thresholds unchanged.

Reproduce with `scripts/build_email_diagnostics.sh`, `scripts/test_email_diagnostic_status.sh`, and `python3 Tools/EmailDiagnostics/test_projection.py`; none invokes a model. Local logs: `build/email-diagnostics-status-build.log`, `build/email-diagnostic-status-tests.log`, `build/email-diagnostic-projection-status-tests.log`.
