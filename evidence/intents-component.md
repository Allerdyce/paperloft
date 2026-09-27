# P4 App Intents component — local implementation, AC-15 blocked

2026-09-26. This is not a P4 gate or phase-completion claim. No archives, uploads, settings/account changes, distribution signing, frozen-file changes, or special launch arguments were used.

## Implemented contract

`Apps/PaperloftApp/PaperloftIntents.swift` defines four App Intents and four App Shortcuts. App metadata extraction includes all four action identifiers and the shortcut provider. Existing AppModel, LibraryView and root app source are untouched; the integrating app **must install the live service**.

Install `PaperloftIntentRuntime.service` synchronously during app initialization with a strong-lived `@MainActor PaperloftIntentService` adapter. Each asynchronous operation must await the app's normal library startup. Do not report success merely because a UI method assigned `message`.

- `isPro`: live/cached StoreKit entitlement. Defaults must remain free while entitlement is unknown.
- `queueDocumentForReview(data:filename:)`: copy the bytes into a new app-owned file and persist a review-inbox entry before returning; throw on either failure. Filename is reduced to its last path component. Never auto-file through this action. The source bytes may be an uncertain/unreadable document, so processing failures remain in review, with originals preserved. The intent returns “Queued for review,” never “filed.”
- `exportAccountantPack(range:)`: recheck Pro, use all committed library documents (not filtered table results), produce a persistent ZIP, return its URL. The intent checks Pro before invoking it and validates inclusive ISO dates. The app must retain any security grant until export completes and the ZIP has been read by App Intents.
- `intentReceipts()`: return every committed receipt, excluding drafts. Total Spent filters category (case-insensitive exact match) and Gregorian calendar period, then sums checked Int64 minor units by ISO currency; no conversion. Empty category means all categories. Period choices: this/last month, this/last year, all time. The current timezone determines calendar boundaries; printed receipt dates are never timezone-converted.
- `openIntentInbox()`: navigate to Inbox and make the window visible; throw if unavailable.

All actions open the app when run. When the service is missing, they fail with a readable setup message instead of silently succeeding. Export dates are YYYY-MM-DD strings to avoid timezone ambiguity.

## Local checks

- Local preflight: 0 FAIL, 0 TFAIL; release prerequisites remain deferred.
- Protected baseline and append-only lock verification: PASS (`evidence/intents-baseline.log`).
- Debug build, build-for-testing, Release build: PASS, no `warning:` or `error:` compiler diagnostics in final build logs.
- Eight independent logic tests: PASS, twice. Latest result `build/IntentsRegisteredTests.xcresult`; suite `PaperloftIntentLogicTests.IntentLogicTests`. Covers mixed currencies including JPY, category/date filters, Int64 overflow, leap-year boundaries, review-only queue, rejected empty/unsupported input, Pro gate, reversed dates, injected inbox/total operations and missing service. These are not App Intents Testing acceptance tests.
- Real AppIntentsTesting: four tests compile and all four FAIL at runtime. No skips, exclusions, permissive error handling or direct-perform substitute for AC-15. Failure assertions deliberately reject infrastructure errors.

## AC-15 external prerequisite and remaining integration

The installed SDK does provide `AppIntentsTesting`, in Xcode's `Platforms/MacOSX.platform/Developer/Library/Frameworks` (not in the SDK framework directory). We inspected its arm64 macOS Swift interface and compiled its APIs.

Three distinct local runtime approaches:

1. Run `IntentDefinitions(bundleIdentifier:).intents[name].makeIntent(...).run()` from the UI test bundle. `build/IntentsTests.xcresult`: all four fail `AppIntentsServicesMetadataErrorDomain Code=400`, `app.paperloft.receipts is not present`.
2. Launch the app normally with XCUIApplication and wait for foreground before calling the framework. `build/IntentsLaunchedTests2.xcresult`: same four failures.
3. Explicitly register the built app with LaunchServices, then launch normally and call the framework. `build/IntentsRegisteredTests.xcresult`: same four failures. The built bundle identifier is correct, and its `Metadata.appintents/extract.actionsdata` lists all four actions.

`codesign -dv` reports `Signature=adhoc`, `TeamIdentifier=not set`. Apple explicitly requires the test runner and app to use the same development team for AppIntentsTesting. See [Apple's WWDC26 session](https://developer.apple.com/videos/play/wwdc2026/295/) and [framework documentation](https://developer.apple.com/documentation/appintentstesting). The signature prerequisite is unmet; we do not claim it is the uniquely proven cause of error400. Active membership/development signing and a rerun through Apple's framework are required before AC-15 can pass. Do not use the placeholder team, change accounts, or weaken the checks.

The four current framework tests cover Open Inbox, Total Spent, invalid File Document input and invalid export dates. Successful file handoff and successful Pro ZIP return still require the integrated app plus controlled entitlement/library setup and further framework tests. Parent integration must add those; pure logic tests do not close that coverage.

## Commands and project wiring

`PaperloftIntentLogicTests` is an independent non-hosted unit target with the same intent source as an explicit source build file plus PaperloftKit. The scheme includes it. New framework tests reside in the existing synchronized UI-test folder. Parent can merge the project additions manually alongside its QA changes.

Independent logic command:

```
xcodebuild -project Paperloft.xcodeproj -scheme PaperloftApp -destination 'platform=macOS' -derivedDataPath build/IntentsDerivedData -only-testing:PaperloftIntentLogicTests test
```

Real framework command (acquire `~/Factory/.gui.lock` first):

```
xcodebuild -project Paperloft.xcodeproj -scheme PaperloftApp -destination 'platform=macOS' -derivedDataPath build/IntentsDerivedData -only-testing:PaperloftUITests/AppIntentFrameworkTests test
```

Full `scripts/ci.sh` cannot be green with the genuine AC-15 runtime failures; no full-CI pass is claimed. Local component results must be kept separate from the blocked formal acceptance criterion.
