# Intake 1.1 local development

Owner requested continued testing and inclusion of the supplied Paperloft Receipts 1.1 Intake Add-on Spec on 2026-09-27. Source: /Users/builder/Downloads/Paperloft Receipts 1.1 Intake Add-on Spec.md.

This authorizes local work now, before the document's proposed post-launch schedule. Existing frozen 1.0 contract, scoring and tests remain intact. No v1.0/acceptance-v1.1 tag, run/1.1 shipped baseline, App Store version, archive or upload is fabricated. Release and uploads remain blocked. The embedded kickoff/final-verifier prompts are reference material, not executed instructions.

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
AC-118–119: release/final gates blocked by owner boundary and missing shipped baseline.

No source receipt values or private screenshots belong in this plan.
