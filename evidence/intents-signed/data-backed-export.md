# Accountant-pack intent result transport — 2026-09-29

Branch `local/intents-signed` after `01ccfd9`. Resolves the one remaining AppIntentsTesting failure recorded in README.md (`testProExportReturnsReadableZip`). This is approach 1 of the 3 allowed; no retry of the unchanged configuration.

## Diagnosis (supported by the fix, not proven by framework internals)

The failure occurred in `PaperloftUITests-Runner`, which is sandboxed by Xcode's standard xctrunner entitlements (not a project setting); its entitlements already include read-only `/` access. The URL-backed `IntentFile` carried a sandbox extension the runner could not consume (`sandbox_extension_consume` EPERM → security-scope signature check → LNValue unarchive → `castingFailed NSNull→IntentFile`). The product ZIP was never the problem. Real Shortcuts consumers were not tested either way.

## Change

- `ExportAccountantPackIntent` returns `IntentExportOutput.file(for:)`: `IntentFile(data:filename:type: .zip)` from `Data(contentsOf:options: .alwaysMapped)`, off the main actor.
- Bound: 100 MB, the same as inbound `IntentDocumentInput`. An uncached `FileManager` size is checked before mapping (so a mapping fallback cannot read an oversized file), then the mapped length is checked before any copy; `URL.resourceValues` was rejected because the first iteration's unit test proved it returned a cached size (`data-unit.log`). Oversized throws `PaperloftIntentError.oversizedExport` ("choose a shorter period, or export it from Paperloft"). An empty or missing file throws. There's no silent URL fallback. The retained ZIP is left in place.
- The framework test `Tests/PaperloftUITests/AppIntentFrameworkTests.swift` is unchanged.

## Verified

- Signed (Paul, GQ4UA5C6RQ) unit target, warnings as errors: 117 XCTest + 113 Swift Testing = **230 PASS**, 0 warning/error lines. Final: `build/IntentDataUnit3.xcresult`, `build/intents-signed/data-unit3.log`. New `testExportReturnsBoundedDataBackedZip`: nil fileURL, exact bytes/filename/type, retained file unchanged, oversized (sparse 100 MB+1) rejected with size unchanged, exactly 100 MB accepted, empty is a read failure (not a size error), missing file and directory raise CocoaError. The Pro intent's own returned value is Data-backed with the expected bytes.
- Real AppIntentsTesting runs, parallel testing off, 60/90 s limits: **7/7 PASS** (`build/IntentDataFramework.xcresult`, `data-framework.log`, 24.8 s). After the review follow-ups changed code, it was re-verified at **7/7 PASS** (`build/IntentDataFramework2.xcresult`, `data-framework2.log`, 24.9 s). There were no sandbox or serialization errors. Each run followed a passing unit build of the same source. The GUI lock was held and released each time.
- Fresh signed Release of the final code: 0 warning/error lines (`data-release2.log`, DerivedData `build/IntentsDataRelease`); privacy PASS (`data-privacy2.log`); strict deep codesign PASS (TeamIdentifier GQ4UA5C6RQ); protected pre-tag baseline PASS (`data-baseline2.log`).
- Independent read-only review: PASS, no merge-blocking findings in the change or in the committed component (no auto-file, durable inbox before acknowledgement, Pro gate checked in the intent and twice in the model, scratch cleanup never touches owned bytes). Its code and test follow-ups were applied and re-verified above.

## Limits, not claimed

- Follow-ups: each Shortcuts export leaves a UUID-named ZIP in hidden Application Support/Intent-Exports indefinitely, and that includes oversized ones that are rejected. That retention is no longer needed by any consumer. Pruning after mapping is safe, but truncating or rewriting a mapped file is not. The 100 MB Shortcuts limit also needs to be disclosed in Help/support copy (AC-20).

- Exports over 100 MB can't be returned through Shortcuts; users must use the in-app export. That is a deliberate conservative limitation, not a SPEC requirement. Framework serialization may still copy up to the bound when archiving the result, and peak memory wasn't measured.
- No large-ZIP, real Shortcuts/Siri/Spotlight, real StoreKit entitlement or closed-window Open Inbox check. AC-15 is locally evidenced, but that is not a formal gate result. Full CI is not claimed.
