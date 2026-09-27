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
