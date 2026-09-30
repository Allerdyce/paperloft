# Throughput investigation (AC-10): per-stage timing and concurrent classification — 2026-09-30

AC-10 requires 100 mixed documents in ≤ 240 s with the system model: about **2.4 s per document**, including OCR. The last app-pipeline measurement was 358.972 s (3.59 s/document; HANDOFF.md, performance branch).

## Method

`Tools/PipelineTiming` (`scripts/build_pipeline_timing.sh`) runs the real `DocumentRecognizer` and `SystemBackend` on the synthetic fixtures (Tests/Fixtures), once per document, and times OCR and model work separately. Modes alternate **by pairs**, because fixtures alternate photo and scanned layouts by index. On sequential documents that classified cleanly, the classifier was also timed alone on the same text, to split the two model calls.

## Results

Run 2 (balanced, 48 fixtures; `build/throughput/timing2.jsonl`):

| Mode | n | Model mean | Model median | OCR mean |
|---|---|---|---|---|
| Sequential (previous production) | 24 | 3.86 s | 3.51 s | 0.24 s |
| Concurrent classification | 24 | **3.11 s** | **3.15 s** | 0.21 s |

- Split (sequential, n=23): classifier alone **1.36 s**; field extraction ≈ **2.56 s**.
- Run 1 was unbalanced by mistake: modes alternated by index, so every photo went to one arm. It showed 3.57 s vs 3.47 s and is kept only as a caution.
- The concurrent calls overlap only partly (3.11 s against an ideal max(2.56, 1.36) ≈ 2.56 s). The on-device model appears to serialize some of the work.

## Conclusions

1. Running the independent classifier concurrently with field extraction is a real improvement: roughly **10–19% less model time per document** (median and mean). Both calls read the same text; neither uses the other's output, and results are combined exactly as before.
2. **AC-10 still cannot pass with this pipeline.** Field extraction alone averages about 2.56 s, above the 2.4 s-per-document budget before OCR, persistence and UI. Concurrency brings the estimate to about 3.1–3.3 s/document (about 310–330 s per 100), still over 240 s. The criterion is frozen, so this needs either a faster extraction call or an owner/verifier decision.
3. Candidate next approaches (not yet tried):
   - prewarming the field-extraction session with its instruction prefix (`prewarm(promptPrefix:)`)
   - a leaner extraction schema (shorter guides and fewer generated tokens, e.g. dropping the model-generated confidence)
   Each needs a full accuracy re-check (AC-03), because earlier prompt changes moved totals.

## Accuracy check of the production change

See the 150-fixture system eval appended below.

**150-fixture system eval with concurrency enabled (commit 1b735f3):** SCORE fixtures PASS, with identical scores (date 100.00%, total 99.26%, vendor 97.78%, kind 99.33%, category 100.00%). Fallbacks were 4 refusals, as before. **0 of 150 predictions differ** from the sequential run. Its wall time (1,204 s against 582 s before) is not comparable: the Mac had load averages of 23–42 from unrelated user applications (a game launcher's renderer at 100%+ CPU plus GPU, and other apps).

**Controlled long run** (run 3; 120 fixtures; modes interleaved by pairs, so background load and heat affect both equally; `build/throughput/timing3.jsonl`):

| Mode | n | Mean | Median | First half | Second half |
|---|---|---|---|---|---|
| Sequential | 60 | 3.82 s | 3.49 s | 3.81 s | 3.83 s |
| Concurrent | 60 | **3.16 s** | **3.17 s** | 3.10 s | 3.21 s |

The gain holds across the run (about 10–17% less model time per document) with no drift. That doesn't reproduce the earlier rejected prewarm experiment's slowdown. The production change is adopted; AC-10 stays open (see Conclusions).
