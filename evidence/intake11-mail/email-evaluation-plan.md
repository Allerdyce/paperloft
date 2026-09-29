# Synthetic email accuracy diagnostic plan

Planning only, 2026-09-29. Do not implement or run the 80-message model evaluation until the common intake pipeline is integrated. No frozen scorer/tests/thresholds or fixtures were changed; no holdout or private samples were accessed. Formal AC-103–105 remain unclaimed.

## Smallest legitimate path

1. Add a separately invoked app-layer diagnostic harness after integration. It must call the same production `MailImport`, `MailReviewPreparation`, `OfflineEmailBodyRenderer`, and `ReceiptEngine.understand` path as the app. Do not reimplement candidate selection in the runner. If necessary, move `MailReviewPreparation` unchanged from AppModel into a shared app source file so both can compile it; that refactor requires coordinated AppModel ownership.
2. Enumerate only `.eml` files from the explicit authorized `Tests/MailFixtures` directory. The prediction process never opens labels. Use a fresh temporary library/index/output under `build/`, preserve original EML hashes, and emit each candidate's provenance (body or attachment index/hash), chosen/omitted status, classification/error, fields, backend, rendering engine/fallback and header-hint flags.
3. Bodies must use the renderer's `bodyText`, which excludes From/To/Date/Subject transport headers. Pass that text and the envelope to `ReceiptEngine.understand` exactly as production does. Keep envelope date/vendor as marked fallback hints; never use labels or headers to manufacture confident document fields. Exercise actual rendering and record its engine; a native-only preliminary smoke is not equivalent to the production automatic-renderer run.
4. Run a small parser smoke first to check plumbing, failures and output schema, then all 80 parser diagnostics. Schedule a separately recorded system-model run only after the shared pipeline and smoke are sound. Preserve missing/error predictions as failures; never choose the model candidate that best matches a label. Coordinate GUI ownership for app-layer/AppKit/WebKit execution and separately verify the sandbox-native path.
5. A separate truth adapter, outside extraction, projects the existing label data into the frozen scorer's schema. Keep raw predictions and projected labels immutable per run, with source revision/dirty status, fixture hashes, backend and command manifest. A missing or ambiguous selected candidate gets no fabricated field prediction. Do not pad, repeat, relabel or filter unsuccessful messages to meet a legacy mode's sample minimum.

Proposed additive files after approval to implement: `Tools/EmailDiagnostics/` harness, `scripts/eval_email_diagnostics.sh`, a small truth projection utility, and diagnostic schema/projection tests. A shared `Apps/PaperloftApp/MailReviewPreparation.swift` may be needed solely to reuse production orchestration. The existing frozen tests and scorer remain unchanged. Keep the potentially slow model run out of the ordinary unit-test suite.

## Reuse the unchanged scorer only for reported field metrics

The frozen scorer supports `fixtures`, `parser`, `holdout`, and `private`, not `email` or `email-holdout`:

- `fixtures`/`parser` require 150 documents; fixtures also requires the unrelated 1.0 photo/long/confusable mix.
- `holdout` requires 60 documents, not the add-on's fresh 40-email holdout.
- `private` is a **report-only mode**, with minimum one document and no gating thresholds. Its date equality, cent-level total matching, vendor normalization/fuzzy comparison and missing-prediction failures remain the frozen implementation.

The lawful diagnostic invocation uses `score_eval.py` directly with explicit synthetic paths, for example:

```
python3 scripts/score_eval.py --mode private \
  --labels build/email-diagnostics/RUN/body-labels.jsonl \
  --predictions build/email-diagnostics/RUN/body-predictions.jsonl
```

Use another explicit projection for all 80 messages if useful. **Never invoke `scripts/eval.sh --private` for this task**: that flag selects the actual private-samples directory. The mode name here does not mean private data was read. Report its output as “synthetic email field diagnostics using frozen report-only matching,” not as private-sample results or an email gate. Exit zero in this mode says nothing about accuracy thresholds. Do not append these observations to the 1.0 gated evaluation history.

## Labels and separate selection checks

Current corpus: 28 PDF receipt emails, 24 body receipt emails (12 plain/12 HTML), 12 receipt-plus-other-PDF emails, 16 non-receipts. Existing `MailFixtureCorpusTests` verifies MIME parts, selectable PDF text, exact attachment bytes and original preservation. It does not evaluate candidate selection or field accuracy.

- Receipt labels include date, total, vendor and kind, but **no category**. Do not invent category truth or treat the frozen scorer's category output as meaningful; mark it unlabelled/not assessed. A projected all-email label uses `kind=not_receipt` for the 16 negative messages, retaining the scorer's exclusion of their receipt fields.
- Labels specify `expectedBodySelected`, `expectedReceiptCount` and part count, but **no explicit expected attachment identity**. Count/body checks alone could incorrectly accept the wrong single PDF. Before exact-document diagnostics, add a reviewed truth sidecar identifying expected MIME attachment ordinal/hash. The current generator places the receipt PDF first and terms second; preserve and independently verify that contract, rather than infer truth from predictions. Do not alter fixture bytes merely to suit the runner.
- Keep existing deterministic `MailCandidateSelection` and `MailReviewPreparation` policy tests. Add explicit production-trace selection diagnostics across the 80 messages: exact chosen document identities, attachment-over-body suppression, unresolved/error candidates, and one `not_receipt` result for negative messages. These are separate from receipt-field scoring; a correct field score cannot prove correct document selection.
- Report the 24 body messages separately. A body omitted, misclassified or errored must remain in the denominator. A label-conditional request to extract an unselected body would not measure production behavior.

Written target reference only: AC-103 asks at least 76/80 exact email selections, no body alongside a receipt attachment, and at least 15/16 correct negative results. AC-104's 24-body set requires at least 23/24 for each date, total and vendor at its stated 95%, 95%, 92% thresholds. These integer observations do not authorize a formal gate verdict. AC-105 belongs to the independent verifier's fresh 40 emails and is not run by this task.

## Limitations and formal boundary

The development corpus has eight repeating text layouts and sixteen synthetic merchants. Attached PDFs are simple single-page selectable text; the only mixed attachment distraction is a terms PDF. The corpus does not independently establish realism, forwarded-chain/image/encoding variety, difficult receipt boundaries or robust email accuracy. Separate MIME edge/fuzz tests help parser coverage but cannot substitute for selection/field difficulty review. A high parser score may reveal an easy set, not system-model readiness.

The add-on requests `email` and `email-holdout` scoring modes, but the existing scorer is frozen under the current baseline. Formal evaluation needs the proper add-on acceptance baseline, verifier-approved corpus difficulty/selection truth, an authorized scoring extension with preserved matching/threshold semantics, and fresh verifier-owned holdout evaluation. Do not edit the protected scorer, import its functions to create an unofficial replacement gate, or claim AC-103–105 from report-only output.
