# Fresh system-model pipeline — timing FAIL

One fresh actual-app system run at reviewed checkpoint0823af27dac2f12e1aa31f29d934332d82636aad (row repair373d4ca; startup repair3a1a3a0). Command: scripts/performance_check.sh system. No product, harness, prompt, model, threshold or fixture code changed for this run. Root granted an uninterrupted quiet window after native UI checks; other agents held builds/tests/traces. The existing script owned the GUI lock. No intrusive sampler or app-container reads were used.

Setup cleared132 prior temporary UI inbox records through the documented hosted harness. Measured priorInboxCount was0. The public mixed corpus remained100 documents:30 JPEG,30 PNG,20 PDF,20 HEIC. The actual AppModel singleton and shipping LibraryView were active; measurements include ordinary intake, recognition/extraction, review publication and inbox persistence.

| Recorded result | Value |
| --- | --- |
| Completed reviews |100/100|
| Persisted completed reviews |100/100|
| Recorded backend histogram |system:100|
| Failed items |0|
| Elapsed |358.972342875s — FAIL, limit240s|
| Lifetime peak physical footprint |414,500,304 bytes|
| Maximum main heartbeat gap |222.736958ms|
| Longest gap ended |5.803493s after intake began|
| Heartbeats / memory read failures |35,289 /0|
| Intake / explicit final layout |4.820ms /0.231ms|

The workload finished normally just before the separate360-second diagnostic cutoff. Native XCTest fail-fast stopped after the first failed warmup's elapsed-time assertion; no measured second iteration or repeat run was attempted. The reported memory/gap values are within their numerical limits, but their later assertions were not executed after the earlier timing failure. The separate deliberate300ms-blockage sampler test PASS (0.404s).

The result exports no XCTest metric rows because the warmup failed. The script explicitly reports required Clock, Memory Peak and UnderstandInboxBatch evidence missing and exits1. MetricMeasurementHelper again logged Cocoa4097; prior native collector failures remain separately documented. Runtime logs also include a QoS inversion warning from the hosted XCTest wait and FoundationModels safety-guardrail warnings. No warning was suppressed. Successful review publication is not a frozen extraction-accuracy evaluation or a guarantee that every field is correct.

Source SHA256 at run:
- AppModel.swift:6fcadc6a7e31af9b14cfaccc6d3075dbc2f86197833acd4da165bba93aac82a5
- LibraryView.swift:5219d0a97b95296f9647e24e3ef76d6b600447b4ef765bdaa32061d591e68ebd
- PipelinePerformanceTests.swift:97be4c1c1c7a45c95fb0238639c0731a159ae5df5e7273fbc258471bb6f7a409

Evidence: evidence/performance/system-20260927T082508Z includes preflight/baseline logs, raw test log, iteration JSON, empty metric export and result path. Local xcresult: build/Performance-system-20260927T082508Z.xcresult. Console copy: evidence/performance-system-fresh-console.log. Local preflight/protected baseline passed under the authorized exception. GUI and quiet window were released at08:31:22UTC for root regression.

The older system result had86/100 at360s with accumulated temporary history. This fresh completion does not establish a causal improvement or repair its prior failure. The current system timing requirement still fails by118.972s (~49.6% over240s); required signpost evidence is absent. AC-10 remains FAIL; no phase or release advance is claimed.
