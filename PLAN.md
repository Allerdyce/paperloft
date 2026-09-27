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

## Mail window reopening investigation (2026-09-27)

- Approach 1: capture OpenWindowAction before native hosting and explicitly present the main scene at launch. Fresh launch still exposes menus/status only; MailReopen1 and MailReopenTree fail the unchanged toolbar assertion. Full AX tree confirms no window under another identifier.
- Approach 2: disable main-scene restoration in addition to presented launch. MailReopen2 fails identically; no repair proven.
- Approach 3: propagate context.environment into the nested NSHostingView root. MailReopen3 compiles strictly but still has no main window at launch. All experimental product changes reverted after three approaches. Native promised-file interaction remains blocked before drag execution.
- Separate diagnostic uses standard Window > Paperloft Receipts to distinguish scene creation from the menu-bar action. Existing acceptance assertions and timeout thresholds are unchanged.

- Follow-up isolated diagnostic proved Window-menu priming reaches the actual failing Open Inbox interaction on the intended executable. Re-evaluated only the prior captured OpenWindowAction idea against that failure: MailCapturedWindowAction FAIL30.606s at unchanged main reopen assertion. Reverted narrow source experiment and parked; no additional product repairs or drag acceptance claim.
