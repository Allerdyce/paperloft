# Review assessment reuse — targeted responsiveness repair

ReviewView previously reparsed the same immutable review OCR text for its needsReview status and each of seven field highlights, on every observed view refresh. StoredReview now retains the existing ReviewedDocument.assessment when processing completes. Its text and extracted fields remain immutable; the editable ReceiptDraft is separate. ReviewView reads this retained value instead of parsing during rendering. Duplicate-marker updates do not affect extraction assessment. No extractor, prompt, confidence threshold or filing decision changed.

The derived value is excluded from Codable keys. Existing inbox JSON remains compatible; decoding recomputes assessment once from saved immutable text/fields with current rules. No persisted stale assessment is trusted. This moves repeated rendering work to one decode-time computation for restored records, and reuses the engine's existing result for fresh documents. Startup decode remains synchronous as before and is not claimed optimized.

Regression tests cover legacy-key roundtrip, exclusion of derived assessment from persistence, draft/duplicate independence, and distinct assessments for same-hash reviews with different immutable fields. Strict Debug scoped suites pass: 8 intent logic checks plus 18 XCTest app/unit checks and34 Swift Testing checks. Includes existing intent startup/persistence and filing operation regressions. The final QA parser run verifies the real rendered app separately.

## Signpost evidence investigation (still unverified)

1. Compared production matched begin/end IDs and subsystem/category/name to Apple's documented [XCTOSSignpostMetric](https://developer.apple.com/documentation/xctest/xctossignpostmetric) and [initializer](https://developer.apple.com/documentation/xctest/xctossignpostmetric/init(subsystem:category:name:)) requirements. They agree; no special pointsOfInterest requirement is documented.
2. Ran a standalone, unhosted XCTest bundle with matched10ms intervals in both a custom category and pointsOfInterest, with Clock and both signpost metrics requested. Only Clock appeared. Source/log are preserved as evidence/signpost-independent-probe.swift and .log. This isolates the workload from application UI/model/signing, but direct xctest may itself lack the collector session established by Xcode, so it does not prove an OS defect. Its XCTest PASS is not a signpost verification PASS.

The actual hosted pipeline previously logged MetricMeasurementHelper Cocoa4097 and lacked signpost results. No connection error is suppressed, no metric requirement removed, and standalone clock results do not substitute for AC-10. Further collector diagnosis is parked after these two different approaches; a functioning collection environment is still needed.

## Fresh actual-app result

`evidence/performance/parser-20260927T073643Z`: priorInboxCount0,100/100 ready and persisted, exact parser backend100, zero failed items,17.144699s, lifetime peak419,481,184 bytes, maximum heartbeat gap297.129167ms. The responsiveness assertion still FAILS (>250ms), so native fail-fast ends after the failed warmup and exported XCTest metrics are empty; the script correctly fails missing Clock/Memory/signpost evidence. The deliberate300ms sampler test passes. QA strict compilation produced no warnings; local preflight/protected baseline pass.

The earlier fresh run was17.809768s,424,494,640 bytes and331.494625ms. A single before/after run cannot establish a reliable speedup or attribute the remaining stall. The implementation removes concretely repeated immutable work, but does not resolve AC-10. All raw failure logs are retained. No additional calibration repeat was run; GUI and quiet window were released to the next agent. Further main-thread profiling, complete system100-document timing and valid signpost collection remain outstanding. Parent independent review is required before integration; no P6 advancement is claimed.
