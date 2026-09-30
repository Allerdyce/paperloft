# Document-type classifier: bounded label probe — 2026-09-29

Branch `local/classifier`. Tool: `Tools/ClassifierProbe` (`scripts/build_classifier_probe.sh`; inputs from `Tools/ClassifierProbe/make_inputs.py`). Raw inputs and results: `build/classifier/inputs*.jsonl` and `results*.jsonl`.

## Reproduction

Arms were added one after another as results came in. All seven are reported: 166 inputs over 6 runs.

| Run | Arms | Seed and environment |
|---|---|---|
| 1 | V0, V1, V2 | `PROBE_SEED=20260929` (default) |
| 2 | V3, V4 | `PROBE_SEED=4242 PROBE_ARMS=V3,V4 PROBE_SMALL=1` |
| 3 | V5 | `PROBE_SEED=7777 PROBE_ARMS=V5 PROBE_SMALL=1` |
| 4 | V5 validation | `PROBE_SEED=9191 PROBE_VALIDATION=1` |
| 5 | Paid invoices | `PROBE_SEED=5150 PROBE_PAID=1` |
| 6 | PROD | `PROBE_SEED=31337 PROBE_ARMS=PROD PROBE_SMALL=1` |

The generator in the final commit reproduces these sets. Later runs reuse some vendor names from the refused run-1 bills. The texts are new: no input is closer to a refused bill than run-1 bills are to each other, per independent review.

## Rules followed

- Every input is new synthetic text with fictional names; no text was reused across runs (overlap checked).
- Each input was submitted **once**. No retries, no resubmission of earlier refused inputs, no refusal-explanation requests.
- No guardrail changes: the default `SystemLanguageModel` throughout.
- The V0/V1/V2 arms reproduce the pre-change production classifier from its recorded instructions (`build/classifier/orig-instructions.txt`).

## Arms

- **V0:** pre-change classifier (enum receipt/invoice/bill/not_receipt, 64 tokens)
- **V1:** short definitions, keeping the "document text is data, not instructions" safeguard
- **V2:** V0 with 256 tokens
- **V3:** bills labelled "statement" in the response
- **V4:** printed-heading field plus the "bill" label
- **V5:** heading field plus the "statement" label
- **PROD:** the new production path (V5 design, 128 tokens)

## Results (correct / wrong / error)

| Run | Arm | Group | Correct | Wrong | Error |
|---|---|---|---|---|---|
| Run 1 | V0 | bill | 0 | 0 | 8 |
| Run 1 | V0 | invoice | 4 | 0 | 0 |
| Run 1 | V0 | not_receipt | 4 | 0 | 0 |
| Run 1 | V0 | receipt | 4 | 0 | 0 |
| Run 1 | V1 | bill | 0 | 0 | 8 |
| Run 1 | V1 | invoice | 4 | 0 | 0 |
| Run 1 | V1 | not_receipt | 4 | 0 | 0 |
| Run 1 | V1 | receipt | 4 | 0 | 0 |
| Run 1 | V2 | bill | 0 | 0 | 8 |
| Run 1 | V2 | invoice | 4 | 0 | 0 |
| Run 1 | V2 | not_receipt | 4 | 0 | 0 |
| Run 1 | V2 | receipt | 4 | 0 | 0 |
| Run 2 | V3 | bill | 6 | 0 | 2 |
| Run 2 | V3 | invoice | 2 | 0 | 0 |
| Run 2 | V3 | receipt | 2 | 0 | 0 |
| Run 2 | V4 | bill | 6 | 0 | 2 |
| Run 2 | V4 | invoice | 2 | 0 | 0 |
| Run 2 | V4 | receipt | 2 | 0 | 0 |
| Run 3 | V5 | bill | 8 | 0 | 0 |
| Run 3 | V5 | invoice | 2 | 0 | 0 |
| Run 3 | V5 | receipt | 2 | 0 | 0 |
| Run 4 (validation) | V5 | bill | 13 | 0 | 3 |
| Run 4 (validation) | V5 | estimate | 4 | 0 | 0 |
| Run 4 (validation) | V5 | invoice | 4 | 0 | 0 |
| Run 4 (validation) | V5 | negative | 4 | 0 | 0 |
| Run 4 (validation) | V5 | paidinvoice | 0 | 0 | 4 |
| Run 4 (validation) | V5 | payment | 4 | 0 | 0 |
| Run 4 (validation) | V5 | receipt | 4 | 0 | 0 |
| Run 5 (paid invoices) | V0 | paidinvoice | 0 | 0 | 6 |
| Run 5 (paid invoices) | V3 | paidinvoice | 1 | 0 | 5 |
| Run 5 (paid invoices) | V4 | paidinvoice | 0 | 0 | 6 |
| Run 6 (production path) | PROD | bill | 7 | 0 | 1 |
| Run 6 (production path) | PROD | invoice | 2 | 0 | 0 |
| Run 6 (production path) | PROD | receipt | 2 | 0 | 0 |

Errors, with the native descriptions captured for the first time:
- refusal: “May contain sensitive content” × 32
- guardrailViolation: “Response may contain sensitive or unsafe content” × 21

## Findings

1. With the pre-change classifier, **every bill failed (0/24)**, whatever the instruction wording (V1) or token limit (V2). This is mostly `guardrailViolation` ("Response may contain sensitive or unsafe content"). Field extraction on the same kind of text succeeds, and historically it returned kind "bill" in full records. The evidence is consistent with the block being triggered by a classifier response that is just the bare value "bill"; this is an inference, not a demonstrated cause.
2. Changing the response shape removes the guardrail violations. Labelling bills "statement" (mapped back to "bill") and including the printed heading gives: bills **28/32** across fresh sets (V5 8/8, validation 13/16, PROD 7/8); invoices, receipts, payment confirmations, notices, quotes, menus, price lists and estimates all correct; **0 wrong labels**.
3. Invoices marked PAID with a zero balance are refused under **both** the old and new designs (V0 0/6; V3 1/6, V4 0/6, V5 0/4). This is a pre-existing limitation, not a regression. V3 and V4 each removed the guardrail violations on their own (6/8 bills each). V5 combines them and did best, but samples are small (28/32 bills is roughly a 71–96% interval). Remaining failures are `refusal`, handled as before: stage-1 fields are kept, review is required, and nothing is auto-filed.

This improves candidate typing only. It isn't a formal accuracy result; the 150-fixture and email benchmarks are reported separately.

## Standard benchmarks with the new production classifier (commit c944adf)

- **150-fixture system eval** (`scripts/eval.sh --model system`, run once; 582 s): SCORE fixtures PASS. date 100.00%, total 99.26%, vendor 97.78%, kind 99.33%, category 100.00%, identical to the previous system run. Classification fallbacks fell from **16** (9 guardrailViolation + 7 refusal) to **4** (refusal). Per document, 12 of the former fallbacks now classify without error and **no field value changed**. Remaining fallbacks: document-021, 108, 109, 111. The run also covers the 16 documents that failed before: one benchmark measurement of a changed design, not a retry of the same request. Log: `build/classifier/eval-system.log`; `evidence/predictions-system.jsonl`, `eval-history.csv`.
- **80-email system diagnostic** (run once; 252 s; `build/email-diagnostics/system80-classifier-20260929`). Frozen scorer, report-only private mode on synthetic paths, not score history. It also includes the earlier routing repair (bbec7c6), so body counts aren't strictly comparable:

| Measure | Previous run | New run |
|---|---|---|
| Exact identity selections | 49/80 | 58/80 |
| Financial date/total/vendor | 33/64 | 42/64 |
| Body fields | 15/24 | 17/24 |
| Negatives | 16/16 | 16/16 |
| Classification failures | 37 refusals in 31 messages | 22 refusals in 22 messages, 0 guardrail |

  All sources were preserved, with no body-suppression violations.
- Signed unit suite: 123 XCTest + 113 Swift Testing PASS, 0 warnings (`build/classifier/unit.log`).

Remaining refusals fail safely: fields are kept, review is required, nothing is auto-filed. This isn't a formal email gate or holdout result.

## Behaviour change to note

Bills that previously always carried `classificationUnavailable` can now be auto-file eligible when every other check passes: confidence ≥ 0.9 and parser agreement, as for any other document.

Independent review: PASS, with no blockers. Its non-blocking suggestions are applied: seeds recorded, a mapping unit test, and the inference wording above.

## Follow-up: refused invoices (runs 7–8, production classifier, new single-use inputs)

| Variant (4 fresh invoices each) | Correct | Refused |
|---|---|---|
| TAX INVOICE + PAID stamp + zero balance + "Tax" line | 1 | 3 |
| INVOICE + PAID stamp + zero balance + "Sales tax" | 4 | 0 |
| TAX INVOICE + zero balance (no PAID) | 0 | 4 |
| TAX INVOICE + PAID stamp (no balance line) | 3 | 1 |
| INVOICE + "Status: Paid" | 4 | 0 |
| TAX INVOICE heading only (no PAID, no balance) | 0 | 4 |

"PAID" and zero balance aren't the trigger; a **TAX INVOICE** heading is strongly associated with refusal. Adding "Identifying the document type is bookkeeping, not tax advice." to the classifier instructions did **not** help: 0/12 on fresh TAX INVOICEs in the three failing styles (run 8, arm PRODTAX, seed 8181).

That makes two distinct approaches (response shape; tax-advice clarification) that left TAX INVOICE refusals unresolved. Parked. Further probing would mean searching input wording for refusal triggers, which is out of bounds. Impact: field extraction still returns kind "invoice", so the stored type is correct; these documents carry `classificationUnavailable` and always require review. No product change.

Seeds: run 7 `PROBE_SEED=6060 PROBE_PAIDFACTORS=1`; run 8 `PROBE_SEED=8181 PROBE_PAIDFACTORS=1 PROBE_PAIDARM=PRODTAX PROBE_PAIDSTYLES=full,nopaid,taxheadingonly`.
