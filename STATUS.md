# Paperloft development status — 2026-09-30

**Checkpointed for the next model at the owner’s request; not launch-ready.** Distribution signing, release archives and App Store Connect uploads are authorized once readiness checks pass. Submission and public release remain blocked.

## Latest verified work
- Email attachment selection and searchable body-PDF fallback work in the sandbox. Native import/restart/removal tests pass.
- Transactional Message-ID duplicate recovery is integrated. Reimporting changed bytes with the same ID remains a duplicate after restart; two native tests pass. Root combined unit run: 156 pass (`build/Intake11DuplicateCombined.xcresult`).
- Watched EML/TIFF routing merged after independent review: 160 unit tests and strict Release pass in the author worktree, including partial writes, rename, retry and proof recovery.
- Accessible native Library/scan pickers merged. Four product picker-action findings cleared; latest complete native accessibility audit still fails with 18 findings. Native Library filter/search/View flow passes; light/dark captures inspected.
- Display/startup blocker cleared; local preflight and protected baseline pass.

## Current work
Latest (2026-09-30, lead mode):
- **AC-16 design follow-up merged:** Receipt menu, export sheet, Library sorting and formatting, review form, Inbox toolbar and Settings, all on native macOS patterns with the owner's branding kept. Summary: `evidence/design/2026-09-30-native/README.md`.
- **Full local CI:** 155 tests pass. Only the accessibility audit fails, on the same 10 system findings.
- **Earlier today:** classifier guardrail fix, AC-20 docs and Help, QA persona sessions (AC-17 informal), design critique (AC-16).
- **Parked:** StoreKit waits on the membership conversion, AC-10 speed (about 2.56 s per document against a 2.4 s budget), and TAX INVOICE refusals.

## Remaining launch gates
Full regression/accessibility, extraction accuracy and fresh email holdout, performance, live Mail/Share/scan, StoreKit/App Intents integration, icon review, formal acceptance baseline and final readiness checks remain open. The last full green CI commit remains `d9454df`; scoped passes above are not full acceptance.

## Owner action
- Apple's confirmation of the individual-to-LLC membership conversion (submitted 2026-09-30); then the steps in `docs/OWNER-RELEASE-SETUP.md`.
- Decisions in PROPOSALS.md: the small-size icon contrast candidate (#357C51 tray-front) and the AC-13 system audit findings.

No distribution upload has occurred. Evidence and history: REPORT.md; blockers: HANDOFF.md.
