# Intake 1.1 local development

Owner requested continued testing and inclusion of the supplied Paperloft Receipts 1.1 Intake Add-on Spec on 2026-09-27. Source: /Users/builder/Downloads/Paperloft Receipts 1.1 Intake Add-on Spec.md.

This authorizes local work now, before the document's proposed post-launch schedule. Existing frozen 1.0 contract, scoring and tests remain intact. No v1.0/acceptance-v1.1 tag, run/1.1 shipped baseline, App Store version, archive or upload is fabricated. Distribution signing, archives and App Store Connect uploads are now authorized when readiness checks pass (2026-09-29); submission and public release remain blocked. The embedded kickoff/final-verifier prompts are reference material, not executed instructions.

## Work order

1. Run local preflight/protected baseline and current unit regressions.
2. Add local scan staging with individual-page/default and combined-document options, explicit provider formats, source labels and synthetic format/page tests. Real iPhone scan remains an owner hardware check.
3. Independently develop atomic, bounded share handoff package; verify crash/replay/partial-file safety before integrating extension.
4. Expand MIME and watched-folder synthetic tests, fix identified parser and rename-idempotency issues.
5. Integrate shared intake ownership/idempotency; build Share extension and verify on-device Finder/Preview/Photos handoff with real development signing.
6. Complete email candidate selection, header-bearing local HTML PDF rendering, fixture scoring without modifying frozen scorer; independently review scoring contract before adopting a 1.1 baseline.
7. Re-run accessibility, privacy, extraction accuracy and performance gates; owner scan/live Mail checks where automation unavailable.

## Acceptance tracking

AC-101: full 1.0 regression remains open (existing accessibility/performance/integration gates unresolved).
AC-102–107: Mail parser/candidate/render/holdout/live drag pending; existing .eml support is not a full pass.
AC-108–111: Share extension/activation/live handoff/memory pending.
AC-112: scan provider formats and page handling implementation/tests in progress.
AC-113: real iPhone hardware check deferred, not passed.
AC-114: watched burst/stability/rename testing in progress.
AC-115–117: new surfaces accessibility/design/privacy pending.
AC-118–119: readiness/final gates remain open; missing baseline and unresolved technical checks prevent distribution. Submission/public release remain outside authorization.

No source receipt values or private screenshots belong in this plan.

## 2026-09-27 — 1.1 local intake testing

Implemented scan page modes, bounded provider copying, an embedded Share extension and durable shared Inbox delivery. Added bounded forwarded-mail parsing and watched-file identity regressions. Independent scoped code review passed after fixing provider races, traversal permissions and process-lifetime Inbox ownership.

Verified: Intake11OwnershipUnit.xcresult passes 41 XCTest + 79 Swift tests; signed development Release and deep signature/privacy checks pass. Handoff package independently passes 14 strict tests; headless provider smoke passes. These are local checks, not full CI or acceptance.

Still open: real Finder/Preview/Photos sharing (system Share menu displayed “Unlock Mac to continue with Siri request”), actual iPhone scan, complete Mail candidate/rendering/scoring work, watched app-level rename identity and existing accessibility/performance gates. No release or upload.

## 2026-09-29 — Mail integration and sandbox repair

- Watched delivery identity/recovery implemented and tested, including A→B→A and persistence recovery.
- MIME image candidates and receipt-attachment suppression integrated. Root unit run: 46 XCTest + 90 Swift tests pass (build/Intake11MailIntegrated2.xcresult).
- Native attachment selection, restart, notices, removal and original-byte preservation pass (build/Intake11MailNativeIsolated.xcresult). HTML body flow fails: WebContent terminates under app-sandbox with no network entitlement.
- Approach 1: bounded WebKit renderer passes standalone but fails native sandbox. Approach 2: minimal sandbox probe isolates WebContent termination, not rule compilation. Approach 3: native CoreText fallback using the same sanitized text/pagination under implementation. No network entitlement relaxation; WebKit implementation deviation remains explicit.
- Envelope hints are being added only for missing document fields, with persistent provenance and field-level review warnings. Message-ID dedup ledger is being built independently; integration must preserve durable Inbox proof across crash windows.
- Re-run native HTML flow after fallback, strict builds/privacy/baseline and scoped independent review. Full 1.1 acceptance, fixture scoring, live Share/scan/Mail checks and existing accessibility/performance criteria remain open.
