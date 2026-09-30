# Throughput investigation (AC-10): per-stage timing and concurrent classification — 2026-09-30

AC-10 requires 100 mixed documents in ≤ 240 s with the system model: about **2.4 s per document**, including OCR. The last app-pipeline measurement was 358.972 s (3.59 s/document; HANDOFF.md, performance branch).

## Method

`Tools/PipelineTiming` (`scripts/build_pipeline_timing.sh`) runs the real `DocumentRecognizer` and `SystemBackend` on the synthetic fixtures (Tests/Fixtures), once per document, and times OCR and model work separately. Modes alternate **by pairs**, because fixtures alternate photo and scanned layouts by index. **Correction (independent review):** pairing also sent every long fixture (ids ≡ 2 mod 4, over 500 characters) to the sequential arm, so the raw per-arm means below are confounded by document length. On sequential documents that classified cleanly, the classifier was also timed alone on the same text, to split the two model calls.

## Results

Run 2 (48 fixtures; photo/scan balanced but **length-confounded**; `build/throughput/timing2.jsonl`):

| Mode | n | Model mean | Model median | OCR mean |
|---|---|---|---|---|
| Sequential (previous production) | 24 | 3.86 s | 3.51 s | 0.24 s |
| Concurrent classification | 24 | **3.11 s** | **3.15 s** | 0.21 s |

- Split (sequential, n=23): classifier alone **1.36 s**; field extraction ≈ **2.56 s**.
- Run 1 was unbalanced by mistake: modes alternated by index, so every photo went to one arm. It showed 3.57 s vs 3.47 s and is kept only as a caution.
- The concurrent calls overlap only partly (3.11 s against an ideal max(2.56, 1.36) ≈ 2.56 s). The on-device model appears to serialize some of the work.

## Conclusions

1. Running the independent classifier concurrently with field extraction is a real but modest improvement. On **matched short documents** it saves about **5–10%** of model time per document: run 2 is 3.39 s vs 3.11 s, run 3 is 3.38 s vs 3.18 s, and the same documents timed across runs agree. The larger raw differences in the tables come from document length, not concurrency. Both calls read the same text; neither uses the other's output, and results are combined exactly as before.
2. **AC-10 still cannot pass with this pipeline.** Field extraction alone averages about 2.56 s, above the 2.4 s-per-document budget before OCR, persistence and UI. With concurrency, a realistic mix including long documents is still about 3.4–3.6 s/document (roughly 340–360 s per 100), far over 240 s. The criterion is frozen, so this needs either a faster extraction call or an owner/verifier decision.
3. Candidate next approaches (not yet tried):
   - prewarming the field-extraction session with its instruction prefix (`prewarm(promptPrefix:)`)
   - a leaner extraction schema (shorter guides and fewer generated tokens, e.g. dropping the model-generated confidence)
   Each needs a full accuracy re-check (AC-03), because earlier prompt changes moved totals.

## Accuracy check of the production change

See the 150-fixture system eval appended below.

**150-fixture system eval with concurrency enabled (commit 1b735f3):** SCORE fixtures PASS, with identical scores (date 100.00%, total 99.26%, vendor 97.78%, kind 99.33%, category 100.00%). Fallbacks were 4 refusals, as before. **0 of 150 predictions differ** from the sequential run. Its wall time (1,204 s against 582 s before) is not comparable: the Mac had load averages of 23–42 from unrelated user applications (a game launcher's renderer at 100%+ CPU plus GPU, and other apps).

**Long run** (run 3; 120 fixtures; interleaved by pairs, so background load and heat affect both arms, but length-confounded as noted; `build/throughput/timing3.jsonl`):

| Mode | n | Mean | Median | First half | Second half |
|---|---|---|---|---|---|
| Sequential | 60 | 3.82 s | 3.49 s | 3.81 s | 3.83 s |
| Concurrent | 60 | **3.16 s** | **3.17 s** | 3.10 s | 3.21 s |

Raw arms differ by about 17%, but that includes the length confound; on matched short documents the saving is about 6% (3.38 s vs 3.18 s). There's no drift across the run. That doesn't reproduce the earlier rejected prewarm experiment's slowdown. The production change is adopted; AC-10 stays open (see Conclusions).

**Review follow-ups:** the classifier task is now cancelled when the caller is cancelled (`withTaskCancellationHandler`), and the timing tool's split condition is fixed. Predictions record kind/vendor/date/total/category, so "identical" covers those saved fields. No load snapshot was saved for the slow eval run; the load averages quoted came from `uptime` just before run 3. Independent review: code PASS; evidence corrected as above.
