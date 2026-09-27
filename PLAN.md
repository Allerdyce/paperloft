# P3 app and core UX

P2 independently accepted locally at47fdb2c. Release remains blocked. Work chunks are at most two hours; split further as needed.

1. Build main-actor app model, security-scoped library setup, persistent inbox, five bundled synthetic samples and real engine integration. Preserve locked navigation identifiers/behavior.
2. Native split-view review with preview and editable validated fields; keyboard confirm/tab; duplicate/error handling; safe copy/move and persistent history/undo.
3. File import, window/Dock/menu bar drops and image paste; library table/search/year/category/kind filters; Quick Look and Reveal; editable categories and settings.
4. QA build configuration and documented launch hooks only. Add deterministic UI flows and first accessibility pass; account for export/purchase phase dependencies explicitly without claiming unimplemented flows pass.
5. Clean CI, P3 self-gate and fresh independent verifier. From P3, independent P4/P5 work can branch from a stable app checkpoint; merge only after their own gates.

Do not read private samples/holdout, weaken locks or ask for more local approval. Keep sample and test data within the app container or Factory-owned build paths. All real external folders require user-granted bookmarks.

## P3 runtime warning investigation

- First two complete CI runs: all 34 tests pass, but AppKit priority inversion warnings block clean CI. Moving index initialization off the main actor did not resolve this warning.
- Symbolicated xcresult backtrace identifies `_getDataDetectorsScanner` through Services-menu population during accessibility inspection; no product frame in the blocking path. Evidence: `evidence/ci/P3-priority-inversion.txt`.
- Second approach: background initialization via public NSDataDetector API. Targeted navigation passes but warning remains (`build/P3-warmup-diagnostic.xcresult`); experiment removed.
- Third approach: remove optional automatic Services command group, retaining standard clipboard/editing and all specified product actions. Checking this with the unchanged navigation test before full CI. No runtime checker suppression or test exclusion is used for acceptance.

- Third approach succeeded: unchanged navigation diagnostic and complete CI pass without warnings. Full result `build/Tests-20260926-230341.xcresult`, 34 tests, clean Debug/Release. Local baseline and privacy checks pass. P3 is not independently accepted yet.

## P3 expanded UI checks

- Draft relaunch and existing keyboard/file/search/undo checks passed. Duplicate+undo initially exposed a plain-button Spacer hit region in the sidebar; adding a rectangular content shape fixes the existing row, and the unchanged failing flow then passed.
- Accessibility audit first identified unlabeled AppKit hosting content; explicit window accessibility labels resolved that element. Current audit covers split-pane names as distinct actionable findings. Audit handler records details and returns false for every issue; nothing is filtered or suppressed.
- Adaptive green accent now has a legible dark appearance, based on actual dark-mode screenshot inspection.
- Filename template parser requires date/vendor/total, rejects unknown tokens/traversal and oversized UTF-8 names. Three new tests plus all31 existing package cases passed.
- Export component d5dad21 independently reviewed PASS; fullP4 not claimed. Commerce component b799b90 stays isolated: app builds/quota/mock diagnostics pass, but strict StoreKitTest import fails in Apple SDK header after3 supported approaches. No warning suppression retained; noP5 claim.

- Integrated export UI test passed in sandbox with real file I/O (test destination inside app support). All five functional tests PASS in build/P3-export-ui.xcresult; default all-types accessibility test FAIL with16 findings, so full run is FAIL.
- Final hosting-ancestor labels remove all app hosting-group findings; native popup press action removes product popup action findings. Independent minimal app reproduces system Touch Bar/emoji/parent-child issues (evidence/a11y-probe/report.md); no suppression.
- Screenshot confirms Category contrast finding is overlapping native popup intrinsic width, not simply color. Constrain native popup proposed size/compression and preserve fixed label width. PDF document view receives public accessibility label. QA compilation passes; audit verification pending GUI lock.

- Latest fullCI Tests-20260926-234415:45unit+5functional UI tests pass; accessibility remains15findings. Source/permission regressions pass, traverse-only ancestor case passes. External real-panel ZIP export and subsequent PDF Quick Look verified. Current Release and QA compile zero warnings. Save as unfinished checkpoint with last_green=d9454df; keep P3 active.

- PDF public-protocol workaround independently demonstrated and integrated; targeted audit removes PDF missing-description while preserving native text. Result build/P3-pdf-label.xcresult remainsFAIL with14system/contrast findings. No root page-label failures remain; fullAC13 is not accepted.

- Independent P3 verdict at d17b2bf is FAIL:14audit findings retained;50other tests pass, coverage90.23%. Source freeze released. Continue separately gated Mail promise delivery, watched-folder app integration and actual-pipeline performance harness. Native probe source preserved on local/audit-probe e5889f4; no automatic waiver or repeated approval request.

## Current independent work

- Combined saved EML/scanner root checkpoint a17e86a:64 package tests and strictRelease build PASS, no new fullCI/phase acceptance.
- Watched-folder model a90fd3e independently passes16tests; native folder grant/relaunch verification remains next. Parent report6ca0453 on isolated branch.
- Assessment cache914afc8 independently passes61tests; diagnostic responsiveness still FAIL. Profile rendering/persistence before further repair.
- Mail promise lifecycle diagnostic will separate restored-windowless launch from Open Inbox behavior, preserving original tests and exact executable provenance. Native wrapper remains isolated.

## Combined local integration checkpoint

- Merge reviewed watcher/startup protection and preserve row rendering: complete at1d1bff7.
- Run combined root package tests, native UI suite and strict Release; record failures without weakening checks.
- Fresh system performance358.972s exceeds240s; inspect existing timing/source for a justified repair before any repeat. Required signposts remain blocked.
- Keep Mail promises, framework discovery, StoreKit SDK and native icon agreement parked; no routine owner approval.

## Resumable local checkpoint

- Combined core83 and functionalUI8 pass, accessibility14findings persists; strictRelease/QA and protectedbaseline pass. Current-root menuOpenInbox independently passes; regression added.
- Prewarm experiment preserved150 predictions exactly but failed100-document completion at360s. Reject/revert isolated source; retain evidence; no repeat without new justified repair.
- Full design/persona work is parked on native Computer Use pipe failure. Native icon agreement, AppIntents discovery, StoreKit SDK, Mail promise gesture, system throughput/signpost and accessibility remain recorded blockers.
- No current heavy process, distribution, upload or background scheduling is planned after evidence is saved. Resume from STATE when a concrete blocker changes or a justified new approach becomes available.

## Owner usability revision — 2026-09-27

- Root: native library double-click/Open action, direct recoverable Delete, Recently Deleted restore sheet, distinct status pills and ready/processing counts; retain scalar row rendering and locked UI identifiers.
- receipt_delete isolated worktree: journaled deletion/recovery + AppModel integration and crash/safety tests.
- tax_export isolated worktree: clear tax/accountant pack UI and recorded-tax PDF groups, missing-tax semantics, export regressions.
- Independent scoped review before integration, then actual native UI delete/relaunch/restore/open/export flow and strict optimized build. Existing P3 accessibility/performance failures remain separately reported.
- Temporary personal-team signing awaits real membership/team details; this does not block local UI implementation.

## Library visual redesign and exact-binary launch — 2026-09-27

Owner correctly identified that prior local UX changes did not achieve supplied Expensify visual reference. Screenshot was additionally an older QA process; both old QA and Release processes were running even after a new build was opened. Gracefully terminate the project app copies before explicitly launching the rebuilt app with a new process.

Implement warm adaptive library canvas, distinct rounded rows with category document icons, compact filter menus, clear row View actions and larger search. Preserve search/filter data paths, local deletion/recovery, native list selection/double-click/context actions, all existing tests and release block. Verify five parser sample receipts in Light/Dark, search/filter actions, double-click/delete/restart/restore and persistent theme. Independent scoped review is required; full accessibility gate is not implied by changing Table to List.

## Inbox action and header cleanup
Provide Paste image in empty and populated Inbox; remove owner-facing sample actions; show only Processing while pending in header. Keep filter counts authoritative. Strict Release, scoped native Inbox test, protected baseline and independent review before committing.
