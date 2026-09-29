# Paperloft development status — 2026-09-29

**Actively developing 1.1; not launch-ready.** Distribution signing, release archives and App Store Connect uploads are authorized once readiness checks pass. Submission and public release remain blocked.

## Latest verified work
- Email attachment selection and searchable body-PDF fallback work in the sandbox. Native import/restart/removal tests pass.
- Transactional Message-ID duplicate recovery is integrated. Reimporting changed bytes with the same ID remains a duplicate after restart; two native tests pass. Root combined unit run: 156 pass (`build/Intake11DuplicateCombined.xcresult`).
- Watched EML/TIFF routing merged after independent review: 160 unit tests and strict Release pass in the author worktree, including partial writes, rename, retry and proof recovery.
- Accessible native Library/scan pickers merged. Four product picker-action findings cleared; accessibility audit still fails21findings. Native Library filter/search/View flow passes; light/dark captures inspected.
- Display/startup blocker cleared; local preflight and protected baseline pass.

## Current work
Common container-owned intake is merged after independent review:185unit tests and strictRelease pass in the author worktree. Root complete nativeUI regression is running. Safe temporary-copy cleanup and synthetic email accuracy diagnostics continue. Development continues independently of the Share setting permission.

## Remaining launch gates
Full regression/accessibility, extraction accuracy and fresh email holdout, performance, live Mail/Share/scan, StoreKit/App Intents integration, icon review, formal acceptance baseline and final readiness checks remain open. The last full green CI commit remains `d9454df`; scoped passes above are not full acceptance.

## Owner action
Only live Share testing is waiting for permission to turn on Paperloft under macOS Sharing extensions (currently off). Real iPhone scanning will also need the owner’s device. No distribution upload has occurred. Detailed evidence and history: REPORT.md; blockers: HANDOFF.md.
