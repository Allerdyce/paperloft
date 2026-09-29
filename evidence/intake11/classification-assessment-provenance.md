# Classification provenance in negative assessments — 2026-09-29

Root preflight reported 39 PASS, 1 WARN, 0 FAIL, 0 TFAIL and 15 MANUAL; root protected baseline passed before implementation. Isolated branch synchronized to root `5769dd3`.

## Change

An extraction with kind `not_receipt` and a classification error previously returned only the notReceipt review reason. Assessment now retains both notReceipt and classificationUnavailable on that early-return path. The original kind, partial fields and diagnostic remain unchanged. Receipt remains nil and automatic filing remains forbidden. Other kinds still retain their existing receipt drafts and classificationUnavailable reason; a successful negative still has only notReceipt. No prompts, model calls, refusal retries, selection policy or safety behavior changed.

## Persistence and presentation

StoredReview persists the original fields and recomputes its derived assessment when decoded. Two native unit tests verify JSON roundtrip for receipt, invoice, bill, not_receipt and unknown kinds, plus restoration of an existing saved negative payload with a classifier refusal. Both review reasons therefore survive application restoration without migration or re-extraction. The stored diagnostic and original values remain intact.

LibraryView's existing kind-field verification checks classificationUnavailable, notReceipt or invalidKind and displays “Choose the document type shown on the receipt.” That predicate already handled negatives; the additional reason preserves provenance without changing the displayed guidance. LibraryView and all UI source remain unchanged. Presentation was source-reviewed; no new visual UI run or top explainer was introduced.

## Checks

- Strict Swift 6 package tests: new parameterized provenance test covers five kinds; separate successful-negative and successful-receipt regressions preserve existing behavior.
- Strict native build plus StoredClassificationProvenanceTests: 2/2 PASS, `build/AssessmentProvenance.xcresult`, log `build/assessment-provenance-native-tests.log`.
- Full strict package run PASS: 28 XCTest plus 112 Swift Testing tests, recorded in `build/assessment-provenance-full-kit-tests.log`.
- `scripts/verify_local_baseline.sh` PASS, including every current locked hash and append-only history. Log `build/assessment-provenance-baseline.log`. Frozen ClassificationRecoveryTests and all other protected tests are unchanged; new tests are separate additive files.
- No model rerun, private input or GUI interaction was used. No formal email accuracy claim is made.
