# Commerce component verification

This is a local component report, not P5 completion or distribution readiness.

## Verified

- `scripts/preflight_check.sh --local --log`: exit 0, 38 PASS, 1 WARN, no FAIL/TFAIL. Membership, signing, acceptance tag and distribution remain deferred.
- `scripts/verify_local_baseline.sh`: exit 0; protected files and existing hashes unchanged.
- `swift test --package-path Packages/PaperloftKit --filter UnderstandingQuotaTests`: exit 0, 2 tests passed. Evidence: `quota-tests.log`. Tests exercise the 26th document, sample exemption, Pro bypass, retry idempotency, calendar rollover, persistence and malformed-ledger failure.
- Unsigned app Debug and Release `xcodebuild ... SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build`: exit 0, no warning/error diagnostics (raw local logs `build/commerce-logs/build-commerce-finaldebug.log` and `build/commerce-logs/build-commerce-finalrelease.log`).

## Strict test build blocked

The new hosted target imports Apple's StoreKitTest. Xcode 27's own `StoreKitTest.framework/Headers/SKTestTransaction.h:34:32` declares deprecated `SKPaymentTransactionState`. With warnings-as-errors the compiler fails while importing the Apple framework, before compiling our test code. The supported implicit-module build setting fails with the identical diagnostic. Evidence: `storekit-sdk-header-failure.log`.

A diagnostic experiment with `-Xcc -Wno-deprecated-declarations` compiled the tests. That suppression was removed and is **not** in the submitted project. Any runtime evidence from those experimental binaries is diagnostic only; it does not satisfy the strict compilation gate. This needs an SDK repair or an owner-approved resolution before formal AC-01/AC-11 readiness.

## Integration contract

Create one `StoreController` in AppModel. Call `await start()` during launch (does not show a paywall), and `await refreshEntitlements()` on application activation. Use observable `ready` to wait before deciding entitlement-dependent operations; `isPro` is based solely on verified StoreKit transactions. StoreKit's signed transaction cache supplies offline entitlement, with expiry checked against the clock; an editable preferences flag never grants Pro. Purchase and restore are user actions only.

Present `PaywallView(store:)` at document 26, first Pro export, and Settings. `Restore Purchases` is present even while Pro. UI must resume queued documents when purchase/restore succeeds. No launch paywall.

Persist a single `UnderstandingQuota` ledger under application support, outside the selected library. Gate immediately before each sequential automatic understanding. Record successful understanding with the persistent inbox UUID, sample flag, and operation date. Persist the ledger before publishing the successful inbox state. A malformed ledger or save failure must block more automatic understanding with a clear error, not reset usage silently. Manual entry bypasses the ledger. Pro successes count so downgrade does not create an extra Free allowance in that month.

`-PaperloftStoreMock YES` exists only under `#if DEBUG || QA`. Visible mock controls select success/cancel/pending/error, approve pending, clear the local entitlement for restore, or expire it. Mock state stays in memory and never changes real StoreKit state. No other launch hooks were added.

Products: `app.paperloft.receipts.pro.yearly` ($29.99/year, seven-day free introduction), `app.paperloft.receipts.pro.lifetime` ($69.99 once). Live UI uses `Product.displayPrice`; intro language appears only when StoreKit says eligible. ASC product creation remains deferred.

Apple API references: https://developer.apple.com/documentation/storekit/transaction/currententitlements and https://developer.apple.com/documentation/storekittest/sktestsession .

Third supported compiler experiment: setting only the hosted test bundle's deployment target to macOS 14 (arm64) also produces the identical framework-header error. It was reverted. Evidence: `storekit-earlier-target-failure.log`.

Diagnostic runtime: mock purchase/cancel/pending approval/restore/expiry test passed (1 test, 0 failures), `build/CommerceMockDiagnostic.xcresult`, `mock-runtime-diagnostic.log`. Real StoreKit runtime run stalled on its first offline-entitlement test and was interrupted; no real StoreKit behavior is verified. Tests now resolve configuration explicitly from the test bundle using `SKTestSession(contentsOf:)`, and offline entitlement coverage no longer waits on intentionally failed product loading. These follow-up test-source changes cannot yet be recompiled under the strict SDK constraint. No accounts, network entitlements, or system settings were changed.
