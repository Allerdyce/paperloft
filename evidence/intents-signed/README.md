# Signed App Intents integration — partial runtime verification

> **Superseded result (2026-09-29 later):** the ZIP failure below is resolved by a bounded Data-backed result; a fresh framework run passes 7/7. See [data-backed-export.md](data-backed-export.md). The 6/7 run below is retained as historical evidence.

2026-09-29, isolated `local/intents-signed`, based on root `c3d5dbd`. During the first build root inadvertently applied independently reviewed copy-only commit `1f0a69e` to this worktree; it is preserved. Later unit/framework/Release checks include that copy change. No frozen files changed. Root supplied current preflight 39 PASS / 1 WARN / 0 FAIL / 0 TFAIL; final local protected-baseline check passes (`build/intents-signed/baseline.log`).

## Why this was a new supported attempt

Previous component `local/intents` at `db1a3f3` had three ad-hoc runtime approaches fail metadata discovery with error 400. [Apple's WWDC26 framework introduction](https://developer.apple.com/videos/play/wwdc2026/295/) requires the app and UI test runner to be signed by the same development team. Verified Paul development signing is newly available. This attempt also explicitly aligns the lookup bundle identifier with the development app; the previous tests hardcoded the production identifier.

The old component's intent definitions and tests are retained in current project structure. Its old unmanaged import adapter is replaced by the shared IntakeQueue: unique bounded scratch input, immutable `.shortcut` record, validated owned payload, generation/publication coordination, durable inbox snapshot before success. Copy semantics are explicit; no mutable-original Move. Snapshot ambiguity throws, freezes mutation, and preserves the published queue record for recovery. Shortcuts scratch is deleted after scope completion; failed publication does not discard owned queue bytes. No automatic filing. Pro remains false by default pending commerce; documented Debug/QA mock-store hook is unchanged. Exports retain library access and durable owned ZIP results.

UI-test lookup comes from `Tests/Support/IntentTestInfo.plist`, expanded using `PAPERLOFT_INTENT_APP_BUNDLE_IDENTIFIER`. Default is production; Paul development config supplies development. Initial generated `INFOPLIST_KEY_...` was omitted by Xcode's UI-testing product; explicit input plist corrected this before any runtime attempt. Existing intent tests are absent from ACCEPTANCE.lock and new on root; no locked test was edited. Logic tests reuse the current app-unit target instead of adding another target.

## Checks

- Fresh signed build-for-testing and final incremental test build PASS, warnings-as-errors, zero warning/error diagnostics. Local logs `build/intents-signed/build.log`, `build2.log`.
- Initial unit compile found optional-Bool assertion errors in new tests; corrected to explicit `== false`, preserving the intended assertion. Final full native unit run: **116 XCTest + 113 Swift Testing = 229 PASS**. `build/IntentSignedUnit2.xcresult`, `build/intents-signed/unit2.log`; no warning/error diagnostics.
- Adapter tests prove concurrent first-use publication, owned origin/Copy semantics, cleared scratch, failed snapshot refusal/recoverable bytes, ambiguous write-then-error recovery, corrupt startup preservation/retry, full-library totals, retained ZIP and Pro gating. Existing protected tests remain unchanged.
- Fresh actual Paul-signed Release build PASS, zero warning/error diagnostics: `build/intents-signed/release.log`, DerivedData `build/IntentsSignedRelease`. Privacy check PASS (`privacy.log`), app/nested signatures validate strictly.
- Built Debug app, UI runner and UI test bundle all validate with TeamIdentifier `GQ4UA5C6RQ`. Runner and app use distinct expected development IDs; actual test plist lookup equals app ID `app.paperloft.receipts.development`.
- Debug and Release generated metadata contain exactly four actions: FileDocumentIntent, ExportAccountantPackIntent, OpenInboxIntent, TotalSpentIntent. Main-app metadata extraction remains enabled.

## First bounded framework attempt (historical): 6/7 PASS, not a gate pass

GUI lock acquired/released around exactly one seven-test AppIntentsTesting run with parallel testing disabled and 60/90-second test limits. `build/IntentSignedFramework.xcresult`, `build/intents-signed/framework.log`; 27.249 seconds, exit 65.

PASS: invalid export dates, real file handoff with visible Inbox item and relaunch persistence, empty input rejection, free export gating, Open Inbox, Total Spent. These execute through the real out-of-process framework. Error 400 metadata discovery is no longer the blocker.

FAIL: `testProExportReturnsReadableZip`, at conversion of `result.value` to IntentFile, before assertions about ZIP bytes. Framework logs `sandbox_extension_consume failed: 1 (Operation not permitted)`, security-scope signature failure, LNValue unarchive/serialization failure, and `castingFailed(elementType: "NSNull", targetType: "IntentFile")`. Existing assertions remain enabled; no retry, skip, suppression, permissive catch or direct-perform substitute was used. Do not report all intent transport or AC-15 passed.

The product uses Apple's documented [IntentFile(fileURL:filename:type:) representation](https://developer.apple.com/documentation/appintents/intentfile) pointing at a retained app-owned ZIP. No external security grant is involved in the result URL. Test-side `file(contentType:)` cannot repair the observed failure because decoding fails before an IntentFile is available. Data-backed results are a documented alternative, but would change large-export memory behavior; no speculative switch was made. The failure alone does not establish whether this is a framework serialization defect or product integration defect.

Open Inbox currently tested with an already-open window, not after closing the last window. Real StoreKit entitlement, Siri/Shortcuts user flows, large ZIP transport and full P4 acceptance remain unverified. No account/settings changes, archives, uploads, submission or public release performed. Independent review is required before any merge decision; scoped compilation/unit passes do not erase the retained framework failure.
