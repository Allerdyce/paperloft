# Independent intent component review

Scoped status: PASS for the new intent-layer component and its eight direct logic tests. Not a P4, AC-15, framework integration, installed Shortcuts, or release pass.

## Reviewed scope

- Apps/PaperloftApp/PaperloftIntents.swift
- Tests/PaperloftIntentLogicTests/IntentLogicTests.swift
- Tests/PaperloftUITests/AppIntentFrameworkTests.swift
- New logic target and scheme additions in Paperloft.xcodeproj

No concrete correctness defect was found in this component's implemented logic. Exact integer totals preserve currency boundaries and detect overflow; range parsing validates ordering; imports reject empty/unsupported inputs and normalize the filename before delegation; export gates on Pro before delegation; unavailable runtime fails explicitly. The nonhost logic target compiles the same production intent source and links PaperloftKit. Existing tests remain present in the app scheme; no skip or filtering mechanism was added to them.

## Independent verification

Read AGENTS.md and LESSONS.md. Local preflight returned 38 PASS, 1 WARN, 0 FAIL, 0 TFAIL, with deferred prerequisites kept separate. Local protected-baseline/hash verification passed.

Ran from /Users/builder/Factory/paperloft-intents:

```sh
xcodebuild -project Paperloft.xcodeproj -scheme PaperloftApp -destination 'platform=macOS' -derivedDataPath build/IntentsReviewDerivedData -resultBundlePath evidence/IntentsIndependentReview.xcresult -only-testing:PaperloftIntentLogicTests test
```

Exit 0; eight tests executed, zero failures. The fresh independent build/test log contains no `warning:` or `error:`. Targeted run establishes only component behavior and does not replace full tests. No GUI was driven by this nonhost logic-test run.

Evidence: evidence/intents-independent-review-tests.log; evidence/IntentsIndependentReview.xcresult; evidence/intents-review-preflight.log; evidence/intents-review-baseline.log.

## Integration obligations and limits

1. No production assignment to PaperloftIntentRuntime.service exists in this branch. Root must install the real adapter during startup and await readiness in operations. Without it all four actions fail unavailable; the source comment describes a required integration contract, not verified behavior.
2. The adapter must durably store import bytes and inbox metadata before returning, use all committed receipts for totals, recheck Pro during export, and preserve the ZIP's lifetime/grant for the recipient. Mock-service tests do not establish these properties.
3. Genuine AppIntentsTesting runs in the author's logs fail AppIntentsServicesMetadataErrorDomain code 400, “app.paperloft.receipts is not present”. Same-team development signing is a plausible prerequisite, not a verified sole cause. I did not rerun the GUI/system test suite. AC-15 remains unverified/blocked; no suppression is authorized.
4. Current framework tests cover Open Inbox, a nonempty Total Spent response, and negative File/Export input paths. They do not yet verify successful file queueing, successful ZIP transfer, cold-start readiness or real Pro behavior through the system framework. These remain for integrated acceptance evidence.

No product, existing test, frozen file, or root worktree was mutated during this review. Review writes are evidence only (the mandated preflight also refreshed evidence/preflight-latest.txt).
