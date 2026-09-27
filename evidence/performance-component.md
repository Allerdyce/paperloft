# Actual application performance diagnostic — AC-10 remains FAIL

The dedicated QA hosted XCTest target runs the real application's installed AppModel singleton and renders its shipping LibraryView in a test-owned visible NSWindow. The hosted runner did not reliably materialize the SwiftUI Scene window, so the harness explicitly creates that window. It measures ordinary intake, OCR, extraction, duplicate checking, observed review updates and inbox persistence. It does not substitute ReceiptEngine timing for the app pipeline. The only production change is a matched UnderstandInboxBatch begin/end signpost around the ordinary processing loop.

Run `scripts/performance_check.sh parser` or `scripts/performance_check.sh system` while other heavy work is idle. The script obtains the shared GUI lock, verifies local preflight/protected baseline, creates public fixture derivatives, builds optimized QA with warnings as errors, runs XCTest, and exports iteration and metric summaries. No new launch arguments or product test-input branches are introduced; existing documented UI/model arguments are used. The new target is independent of ordinary CI and the frozen acceptance tests.

The 100 public documents are document-001 through document-100: 46 receipts, 34 invoices, 10 bills and 10 non-receipts. Their measured formats are 30 JPEG, 30 PNG, 20 PDF and 20 HEIC. PDF/HEIC derivatives are generated outside the app process using Apple frameworks; all inputs are hash-verified against an attached manifest, with 100 distinct IDs and digests. No holdout/private files or originals are modified.

The final harness clears only the existing temporary UI-test model's inbox array after ordinary newSampleLibrary(discardInbox:true); the next ordinary intake persistence replaces its temporary inbox JSON. Production and original source files remain untouched. This provides a fresh 100-item inbox while retaining real UI/pipeline behavior. It prints the prior temporary record count and reports the measured prior count. Application startup can load prior temporary history before clearing; the lifetime memory peak conservatively includes it. No app-container data is read from the shell.

## Measurements and limits

| Run (UTC suffix) | Completion | Time | Peak physical footprint | Largest main heartbeat gap | Outcome |
| --- | --- | --- | --- | --- | --- |
| parser 072040 iteration 1 | 100/100 persisted | 19.146 s | 419.91 MB | 262.57 ms | Responsiveness FAIL |
| parser 072040 iteration 2 | 100/100 persisted | 19.206 s | 441.91 MB | 280.31 ms | Responsiveness FAIL |
| system 072312 iteration 1 | 86/100 persisted | 360.009 s | 441.94 MB | 347.69 ms | Completion, time, responsiveness FAIL |

These earlier runs retained accumulated temporary aside records between iterations; their historical record counts were not instrumented. They are actual app-history diagnostics, not fresh-inbox baselines. Final telemetry/cleanup and backend-identity assertions were added afterward. The first parser attempt (071843) had missing Scene and measurement-option failures and is explicitly invalid acceptance evidence.

System exceeded the unchanged 240-second criterion; at the separate 360-second diagnostic cutoff the harness reported 86 completed, then the controlling runner cancelled the redundant second six-minute XCTest iteration. Its xcresult is incomplete and contains no exported metrics; the complete console report is preserved. The final harness uses native continueAfterFailure=false after writing its report and cancelling unfinished work through ordinary library switching, avoiding redundant failed warmups without skipping any test. Full 100-document completion remains required for PASS.

XCTest requests Clock, Memory and the production interval signpost metrics. The corrected parser result exported clock and peak physical memory, but no signpost metric. MetricMeasurementHelper logged Cocoa4097 connection failures. The script fails explicitly when any requested metric is absent; the heartbeat/physical-footprint sampler is supporting evidence, not a substitute claim that the required signpost evidence exists. No unsupported pointsOfInterest requirement is inferred.

Main responsiveness uses a background timer with at most one outstanding main-queue callback and measures gaps between completed callbacks, including the ordinary 10ms cadence. This is a conservative upper bound, not an exact stack-attributed hang duration. The kernel's task_vm_info lifetime peak captures brief spikes; it includes hosted XCTest/setup memory but excludes the out-of-process system model daemon. A dedicated sampler test blocks the main thread for 300ms and verifies detection and valid memory reads.

The final harness asserts exact recorded backend counts (system fallback to parser cannot pass the system criterion), 100 ready/persisted reviews, zero failed items, functioning sampling, time <=30/240 seconds, heartbeat <=250ms, and memory strictly below600,000,000 bytes. No acceptance thresholds were changed. Missing signpost evidence and actual failed limits keep AC-10 FAIL. No P6, release or formal gate pass is claimed.

Raw logs, iteration JSON, metrics JSON and local result-bundle paths are under evidence/performance. Result bundles remain local under build. Parent independent review is still required before integration. Future optimization must preserve extraction accuracy and refusal handling; the real system path currently performs two sequential model sessions per document.

## Final-source validation

Final QA strict build/run `parser-20260927T073014Z`: the hosted test cleared746 prior temporary records before measurement; measured priorInboxCount=0. All100 documents were ready and persisted, backend histogram parser=100, zero failures,17.809768s, peak424,494,640 bytes, largest heartbeat gap331.494625ms. Responsiveness FAIL. Native fail-fast ended after the failed warmup, so Clock/Memory/signpost metric exports are all absent for this result; script correctly failed rather than accepting partial metric evidence. The independent300ms-blockage sampler test PASS (0.404s). No compiler warnings were reported. Local preflight and protected baseline PASS under the authorized local exception; formal/release prerequisites remain deferred. The shared quiet resource window and GUI lock were released after this run.
