# Paperloft development status — 2026-09-29

**Actively developing 1.1; not launch-ready.** Distribution signing, release archives and App Store Connect uploads are authorized once readiness checks pass. Submission and public release remain blocked.

## Latest verified work
- Email attachment selection and searchable body-PDF fallback work in the sandbox. Native import/restart/removal tests pass.
- Transactional Message-ID duplicate recovery is integrated. Reimporting changed bytes with the same ID remains a duplicate after restart; two native tests pass. Root combined unit run: 156 pass (`build/Intake11DuplicateCombined.xcresult`).
- Watched EML/TIFF routing merged after independent review: 160 unit tests and strict Release pass in the author worktree, including partial writes, rename, retry and proof recovery.
- Accessible native Library/scan pickers merged. Four product picker-action findings cleared; latest complete native accessibility audit still fails with 18 findings. Native Library filter/search/View flow passes; light/dark captures inspected.
- Display/startup blocker cleared; local preflight and protected baseline pass.

## Current work
Common owned intake and conservative cleanup are merged. Root200unit tests and3focused native restart flows pass; the complete earlier UI target passed15functional tests and failed only accessibility. Email diagnostics found two real selection failures, now under investigation. Share metadata warning has a reviewed target-specific fix; final integrated build remains pending.

## Remaining launch gates
Full regression/accessibility, extraction accuracy and fresh email holdout, performance, live Mail/Share/scan, StoreKit/App Intents integration, icon review, formal acceptance baseline and final readiness checks remain open. The last full green CI commit remains `d9454df`; scoped passes above are not full acceptance.

## Owner action
Only live Share testing is waiting for permission to turn on Paperloft under macOS Sharing extensions (currently off). Real iPhone scanning will also need the owner’s device. No distribution upload has occurred. Detailed evidence and history: REPORT.md; blockers: HANDOFF.md.
