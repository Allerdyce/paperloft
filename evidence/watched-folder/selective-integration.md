# Selective watched-folder integration

Base: 4cab99e (reviewed saved-email import and cached review assessments). Ported reviewed watcher implementation from local/watched-folder (native review 8d7d77e), without App Intents service conformance, adapters, framework intent definitions, registry or dispatch. Watch failures use AppIssue. Existing scanner core is unchanged. Mail intake via saved EML remains supported exactly as on the base; EML in the watched folder remains explicitly pending and unacknowledged. Production Pro remains conservative false; the existing documented Debug/QA Store mock supplies test entitlement.

The original delivery contract is retained: one user-granted root with retained access; bounded stable scanner candidates; immutable copies and durable inbox proof before acknowledgment; bounded latest-version delivery ledger keyed by folder/name/content with sequence ordering; recoverable acknowledgment/ledger failures; no original mutations or auto-filing. Restored inbox proofs survive set-aside/library changes and are secured before filing removes an item.

Shared startup core was selectively ported from 3a1a3a0: Sendable off-main inbox decoding, coalesced startup, precise missing-file detection (broken symlinks fail), guarded edits/set-aside/persistence/refresh/process and library readiness, async intake/paste retaining grants before the first startup suspension. The watcher keeps mutation readiness false through ledger validation/recovery as well as inbox decoding. A new test verifies corrupt watcher history leaves saved inbox bytes and draft/status untouched and allows mutation after repair/retry. No intake call is made from inside startup, avoiding self-await; watch restoration is scheduled after startup.

App initialization now schedules startup independently of the main Window task, because menu-only launches must also resume watching. Both paths use the same model and coalesced task. The extended native lifecycle diagnostic checks a new input and menu inbox count after restarting and closing any restored main window, before reopening it for review. It does not prove that no Window task ran during launch. This is separate from the unresolved menu-bar Open Inbox action.

## Verification before native follow-up

- Local preflight: 38 PASS, 1 WARN, 0 FAIL/TFAIL; membership/release prerequisites deferred. `build/watch-preflight.log`.
- Protected baseline PASS: `build/watch-final-baseline.log`.
- Debug and optimized Release build-for-testing PASS, zero compiler-warning lines. Release tests use ENABLE_TESTABILITY=YES. Logs `build/watch-combined-{debug,release}-build.log`.
- Full package/app target: 83 tests each configuration (28 XCTest + 55 Swift Testing), zero failures. Results `build/WatchCombinedDebugTests.xcresult` and `build/WatchCombinedReleaseTests.xcresult`; logs `build/watch-combined-{debug,release}-tests.log`. Includes existing Mail/assessment/scanner/resilience checks, watcher adapter/restart/error tests, shared startup checks and new corrupt-ledger mutation test.
- Quiet maximum32MB / near-capacity ledger regression: Debug deliveries 127.80/127.65/134.73 ms, max main-actor gap12.71 ms; Release121.51/123.64/100.90 ms, maxgap14.35 ms. This scoped heartbeat result is not a whole-app frame-time or P6 claim.
- Plain production Release build PASS, zero compiler-warning lines, no testability override: `build/watch-production-release.log`.
- Updated native UI test build PASS: `build/watch-native-build.log`. Native execution and new independent source review are pending at this checkpoint.

No formal gate, phase completion, tag, release archive, upload or submission is claimed.

## Native follow-up

`build/WatchCombinedNative1.xcresult` / `build/watch-combined-native1.log` passed folder selection, initial review, off/on, bookmark restoration and third-file intake, then failed the new windowless-start precondition: macOS reopened the main window after XCTest relaunched the app. This is retained as an unverified windowless-start condition, not a watcher failure or pass. No product code was changed in response.

With parent agreement, the new diagnostic was corrected to close a main window if macOS restores one, then assert continued intake while main remains closed. `build/WatchCombinedNative2.xcresult` / `build/watch-combined-native2.log` passed all lifecycle assertions in82.31seconds, zero compiler warnings. A fourth synthetic PDF arrived after restart and the menu extra displayed four inbox documents while the main window was absent; reopening via the public Window menu showed that file. The test confirmed original bytes, exactly one first/second item, and finished with watching off/app terminated. Three screenshots are in `selective-screenshots/`.

App-owned coalesced startup is independently visible in source; this native run establishes continued intake with main closed after restart, not a launch where no Window task ever executed. No existing acceptance test was changed. Fresh independent source/model/native review is still required before merge.
