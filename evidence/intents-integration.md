# App Intents production adapter — local checks

2026-09-26. Supersedes the uninstalled-service limitation in `intents-component.md`; the original isolated-layer evidence remains historical. No P4/AC-15 or release pass is claimed.

## Implemented

Merged `run/1` checkpoint 4a13379 normally in merge 763e848, retaining QA configurations, real AppModel unit-target integration, template changes and existing interactive-export grant fixes. PaperloftApp now registers the production AppModel service synchronously in its initializer. The main window installs a reopen action, and Open Inbox selects the inbox, reopens the main window and activates the app.

UI and intent startup share one main-actor throwing task. Every adapter operation awaits it. A failed task clears itself inside its own catch, allowing a repaired bookmark/inbox to retry; individual waiting callers never clear a newer task. An unreadable or corrupt existing inbox now fails before any new write instead of being treated as missing.

Incoming intent data is copied atomically to a unique app-owned `Intent-Imports` folder. The new inbox state is atomically persisted before the model changes or the action reports success. Failure leaves copied bytes intact for recovery and propagates to the caller. Inputs always require review, including high-confidence extraction; no auto-file path is called. Two concurrent first-use imports share startup and both survive relaunch.

File Document loading occurs off-main. URL-backed transfers require a regular file, check its size before reading, and stream through a bounded FileHandle while holding any security scope. A 100 MiB cap is checked during loading and again at the adapter boundary. If App Intents supplies only Data, the framework's Data getter runs off-main and is size-checked immediately; its internal materialization cannot be streamed through the public API. Existing recognition limits were pages/pixels, not bytes.

Totals fetch all committed receipts directly from the library store, excluding review drafts and current UI filters. Intent export independently verifies Pro, snapshots the full library and creates a ZIP in persistent app-owned `Intent-Exports` storage. It retains the source library access for the full export. Because the destination is inside app-owned storage, there is no temporary external destination grant to expire; unrelated UI export dismissal cannot invalidate the returned ZIP. Files are not automatically deleted after the action returns.

Until commerce integration, the default production entitlement remains false. An injected main-actor entitlement closure is the integration seam. The existing documented `-PaperloftStoreMock YES` hook grants the mock entitlement only under DEBUG or QA; Release compiles that branch out. No new launch arguments or test-input branches were added.

## Checks

- Local preflight: 0 FAIL/0 TFAIL. Protected baseline and lock hashes pass.
- Debug: 16 relevant tests pass, no warning/error diagnostics. `build/IntentAdapterTests5.xcresult`; `evidence/intents-adapter-tests.log`.
- QA optimized: same 16 tests pass with `ENABLE_TESTABILITY=YES`, no warning/error diagnostics. `build/IntentAdapterQATests2.xcresult`; `evidence/intents-integrated-qa.log`. The explicit flag is required to test the package through existing @testable imports in a custom optimized configuration; it does not disable optimization or checks.
- Release app build passes, no warning/error diagnostics. `evidence/intents-integrated-release.log`.
- The 16 tests comprise 9 original-layer/input-bound tests, 5 real AppModel adapter tests, and 2 pre-existing operation-serialization tests. They establish local behavior only, not system intent transport.
- Real AppIntentsTesting: seven tests ran against the integrated app, all failed metadata lookup before executing an intent (`AppIntentsServicesMetadataErrorDomain Code=400`, app not present). `build/IntentFrameworkIntegrated.xcresult`; `evidence/intents-integrated-framework-tests.log`. These are genuine failures and remain enabled. The later bounded-read/startup-retry changes do not affect that lookup failure; transport remains unverified.

New framework tests include successful File Document handoff plus relaunch persistence, successful Pro ZIP result bytes, and rejection with the free entitlement. They use only SPEC 6.7 UI/model/mock-store hooks. They are compiled, but their intended assertions are not reached while metadata lookup is blocked.

## Remaining

AC-15 still requires successful system-framework execution. Apple's framework requires same-development-team app/runner signing; this machine currently has ad-hoc signatures with no team. This is an unmet prerequisite, not a uniquely proven diagnosis of the metadata error. Do not weaken the tests or use the placeholder team. See original component report for three distinct failed runtime approaches and primary Apple references.

The real StoreKit entitlement must replace the conservative provider when the independent commerce component is integrated. Framework success paths, cold-launch system dispatch, window reopening through Siri/Shortcuts, and ZIP transport to another process still need acceptance evidence. Source/unit checks cannot substitute for that evidence. Full CI/P4 readiness is not claimed.
