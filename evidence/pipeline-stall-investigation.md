# Remaining pipeline heartbeat gap investigation

After assessment reuse the fresh100-parser workload still records a297ms maximum main-queue heartbeat gap. This investigation does not change models, extraction rules or AC-10 thresholds.

Source candidates:
- synchronous intake performs100 grants/canonicalizations plus an initial inbox write;
- processing writes the entire inbox twice per document on MainActor;
- SwiftUI initially constructs the100-row list and selected review controls;
- DocumentPreview generates a thumbnail off-thread, encodes it as PNG, then constructs compressed NSImage(data:) on MainActor. First drawing may decode again.

An isolated actual-AppModel test with100 internal temporary files, an unconfigured engine, and real inbox persistence completed the synchronous intake in5.965ms. It verifies100 persisted records and no processing; this is diagnostic evidence against intake being the297ms culprit, not an AC-10 pass. The test does not create invalid-input branches in product code. Current shared machine activity makes this non-calibrated evidence.

The next diagnostic records synchronous intake duration, explicit final-layout duration and the time offset where the longest heartbeat gap ended. A separate script uses Apple's native `sample` tool against the exact QA app executable launched by the existing locked runner, for20seconds at1ms. It is explicitly intrusive, cannot establish acceptance timing and does not bypass GUI coordination. The normal runner retains all strict assertions and metrics checks. No speculative product repair is made before examining the stacks.

## Intrusive profile and next bounded repair

The native sample succeeded: raw38MB stack trace is preserved locally as build/PipelineStacks-20260927T074959Z.txt; its SHA256 and selected main-thread frames are committed under evidence/pipeline-stacks-20260927T074959Z. Sampling covers startup and the first part of the workload; the aggregate graph has no per-sample timestamps, so its node counts cannot be assigned to the exact longest gap or treated as milliseconds. Recursive frames must not be summed.

Main-thread frames include a941-sample window layout branch,371-sample NSTableView.layout branch,370 visible-row update branch,262 automatic-row-height calculation and258 uncached automatic-row-height samples. The largest individual AppModel.persist branch has13 samples. Startup decoding appears prominently (453 samples) but happens before measured intake; this is an outstanding startup responsiveness concern, not evidence that it caused the measured gap. No substantial preview-image decode branch was identified, so the speculative image rewrite was not performed.

The sampled workload completed100/100 persisted/parser records in28.002s, with46.33ms synchronous intake and0.242ms explicit final layout. Its largest heartbeat gap was2.592s ending7.133s into measurement. This large profiler disturbance makes it unsuitable as acceptance timing and does not prove the original297ms gap had the same cause. Full raw failure reports remain under evidence/performance/parser-20260927T074959Z.

The bounded next repair extracts InboxRow into an Equatable SwiftUI view carrying only scalar id/name/status/duplicate values. Unrelated extraction updates to the whole items array need not reconstruct unchanged row content and height layout. Selection tag, existing accessibility identifier, text wrapping, font metrics and status/duplicate labels are preserved. There is no fixed-height constraint and no captured model/action excluded from equality. This is based on observed automatic row-layout work, but its improvement must be measured separately. Strict optimized QA build-for-testing passes before the next queued GUI measurement.

## Fresh row-repair baseline (not sampled)

After the queued GUI work finished, other agents held heavy work for the fresh QA100-parser run `parser-20260927T075752Z`:

| Iteration | Completed/persisted | Seconds | Peak physical bytes | Largest heartbeat gap | Gap ended after intake |
| --- | --- | --- | --- | --- | --- |
| Warmup |100/100|16.408313|447,317,600|177.282ms|0.722481s|
| Measured |100/100|16.435588|452,134,640|224.927ms|0.566006s|

Both iterations report priorInboxCount0, parser100, no failed items and valid memory/heartbeat sampling. Intake took5.697/6.857ms; explicit final layout took0.232/0.132ms. All direct parser-workload threshold assertions PASS. The deliberate300ms blockage test PASS. XCTest exported Clock16.172651s and peak physical452,134.64kB, but still omitted UnderstandInboxBatch. The strict runner therefore exits1: required signpost evidence remains missing, system timing remains failed/unresolved, and AC-10 is NOT PASS. One before/after run is not proof of the original297ms gap's cause. No extraction/model/threshold changes were made and all historical failures are preserved.

## Functional verification limit

Two existing UI tests were attempted against the row change: testDuplicateStateFollowsFilingAndUndo and testInvalidAmountCannotFileAndSetAsideAdvancesInbox. Both FAILED in freshApp at CoreFlowTests.swift:10, waiting for toolbar.settings after launch (16.704/17.368s). Neither reached an inbox-row interaction. This cannot verify row selection/duplicate behavior; the native-window availability problem is recorded separately, without claiming the row change caused or fixed it. Log: evidence/inbox-row-functional.log; local result: build/InboxRowFunctional.xcresult. No test was excluded, rewritten or retried to hide the failure. GUI was handed to the next verifier. Parent independent review and functional verification remain required.
