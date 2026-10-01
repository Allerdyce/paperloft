# Paperloft development status — 2026-09-30

**Checkpointed for the next model at the owner’s request; not launch-ready.** Distribution signing, release archives and App Store Connect uploads are authorized once readiness checks pass. Submission and public release remain blocked.

## Latest verified work
- Email attachment selection and searchable body-PDF fallback work in the sandbox. Native import/restart/removal tests pass.
- Transactional Message-ID duplicate recovery is integrated. Reimporting changed bytes with the same ID remains a duplicate after restart; two native tests pass. Root combined unit run: 156 pass (`build/Intake11DuplicateCombined.xcresult`).
- Watched EML/TIFF routing merged after independent review: 160 unit tests and strict Release pass in the author worktree, including partial writes, rename, retry and proof recovery.
- Accessible native Library/scan pickers merged. Four product picker-action findings cleared; latest complete native accessibility audit still fails with 18 findings. Native Library filter/search/View flow passes; light/dark captures inspected.
- Display/startup blocker cleared; local preflight and protected baseline pass.

## Current work
Latest (2026-09-30 evening, lead mode):
- **AC-16 design follow-up merged:** Receipt menu, export sheet, Library sorting and formatting, review form, Inbox toolbar, Settings, ⌘1–⌘3 section shortcuts, and clearer empty states. All use native macOS patterns with the owner's branding kept. Summary: `evidence/design/2026-09-30-native/README.md`.
- **Second design review** (`evidence/design/2026-09-30-r2-critique.md`): most first-round fixes confirmed. It found two new P1s (Undo from History lost the receipt; Remove couldn't be undone), and I found a third (⌘Z undid a filing instead of typing). All three are fixed. AC-16 still has lines below 4: some are deliberate branding, some are frozen-test constraints, and some are smaller polish items.
- **Bugs:** QA-05, QA-07 and QA-08 fixed. The second review's R2-01–R2-07 are fixed, except R2-06: a one-off layout-loop crash, mitigated and being watched. See BUGS.md.
- **Full local CI:** 165 tests pass, with no crashes. Only the accessibility audit fails, on the same 10 system findings.
- **Waiting on the owner (PROPOSALS.md):**
  - AC-10 speed: the target can't be met by scheduling, since two documents at once gave no gain
  - AC-13 system audit findings
  - icon tray contrast
- **Parked:** StoreKit waits on the membership conversion; TAX INVOICE refusals.

## Remaining launch gates
Full regression/accessibility, extraction accuracy and fresh email holdout, performance, live Mail/Share/scan, StoreKit/App Intents integration, icon review, formal acceptance baseline and final readiness checks remain open. The last full green CI commit remains `d9454df`; scoped passes above are not full acceptance.

## Owner action
- Apple's confirmation of the individual-to-LLC membership conversion (submitted 2026-09-30); then the steps in `docs/OWNER-RELEASE-SETUP.md`.
- Decisions in PROPOSALS.md: the small-size icon contrast candidate (#357C51 tray-front) and the AC-13 system audit findings.

No distribution upload has occurred. Evidence and history: REPORT.md; blockers: HANDOFF.md.
