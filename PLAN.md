# P3 app and core UX

P2 independently accepted locally at47fdb2c. Release remains blocked. Work chunks are at most two hours; split further as needed.

1. Build main-actor app model, security-scoped library setup, persistent inbox, five bundled synthetic samples and real engine integration. Preserve locked navigation identifiers/behavior.
2. Native split-view review with preview and editable validated fields; keyboard confirm/tab; duplicate/error handling; safe copy/move and persistent history/undo.
3. File import, window/Dock/menu bar drops and image paste; library table/search/year/category/kind filters; Quick Look and Reveal; editable categories and settings.
4. QA build configuration and documented launch hooks only. Add deterministic UI flows and first accessibility pass; account for export/purchase phase dependencies explicitly without claiming unimplemented flows pass.
5. Clean CI, P3 self-gate and fresh independent verifier. From P3, independent P4/P5 work can branch from a stable app checkpoint; merge only after their own gates.

Do not read private samples/holdout, weaken locks or ask for more local approval. Keep sample and test data within the app container or Factory-owned build paths. All real external folders require user-granted bookmarks.
