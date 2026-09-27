# Mail app integration component

Scope: local `.eml` files through Import, existing file-URL drop handling, and Dock/open-URL document registration. No mailbox or network access. No full P4, final, or release claim.

The independent parser review was committed first (f6f546e), followed by a normal merge of root 302a6c7 (c81976c); the only conflict was the process log, and both histories were preserved. Root QA, current tests and accessibility/PDF labels remain intact.

## Behavior

An imported email stays in the durable inbox while it is read. Its FileGrant is captured for the entire detached parsing/materialization operation. The helper opens a regular non-symlink file, checks its size before allocating message bytes, and reads at most 32 MB plus one detection byte in 64 KB chunks to detect growth. MIME limits remain active.

Plain or safely extracted HTML body text becomes a readable paginated CoreText PDF, bounded to 200 pages. All attachment PDFs are checked with PDFKit for readable, unlocked, nonempty structure and the existing 200-page limit. Each attachment's exact decoded bytes is written without overwrite into a fresh app-owned directory. Sender filenames never become paths. The original EML is never written or removed. Body and attachments all enter ordinary manual review, never auto-file.

Optional InboxItem.importNotices preserves parser notices and explains that the original email is unchanged. This field survives JSON persistence/relaunch, and old inbox JSON without the field still decodes. Notices appear in the review view. Malformed, oversized, empty/unsupported and unreadable-attachment errors remain actionable and tell the user the original email is unchanged.

## Verification performed

- `swift test --package-path Packages/PaperloftKit --scratch-path build/MailIntegrationPackage -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`: exit 0; 46 Swift Testing cases plus 9 export XCTest cases passed. Log: build/mail-integration-package.log.
- `xcodebuild -project Paperloft.xcodeproj -scheme PaperloftApp -destination 'platform=macOS' -derivedDataPath build/MailIntegrationDebug -configuration Debug SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:PaperloftKitTests -resultBundlePath build/MailIntegrationDebug.xcresult test`: exit 0; 12 XCTest + 46 Swift Testing cases passed; no warning/error lines. This compiles actual AppModel.swift and includes MailInboxTests. Log: build/mail-integration-app-debug.log.
- Release app build in build/MailIntegrationRelease with SWIFT_TREAT_WARNINGS_AS_ERRORS=YES: exit 0, no warning/error lines. Log: build/mail-integration-app-release.log.
- Targeted MailFlowTests in build/MailIntegrationUI4.xcresult: exit 0, 1 test passed in 32.297 seconds; no warning/error lines. Real NSOpenPanel granted access to a bundled synthetic EML. It verified body and attachment review, notices after relaunch, no automatic filing, and byte-identical original EML. GUI lock acquired atomically for tests and released afterward. Log: build/mail-integration-ui4.log.
- MailImportTests verify paginated text including Unicode and all 180 lines, exact attachment bytes, unique repeated outputs, ignored-content notices, original preservation, sparse oversized input rejection, source symlink rejection, and no output on malformed/empty/corrupt-attachment failures. MailInboxTests verifies current/legacy JSON.

UI attempts 1–3 failed in test infrastructure: runner checkout-write permission, missing resource phase, then ambiguous Open/Touch Bar button. Fixed the fixture/query rather than changing app grants or adding launch hooks. Attempt 4 passed. Failed bundles remain in ignored build directories for diagnosis.

The pre-existing preflight evidence change is incidental and excluded from this component commit. No private/holdout or other app container was read from the shell. Independent parent review and integration verification remain required.
