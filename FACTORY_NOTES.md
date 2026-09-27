# Factory observations — local development draft

This is an unfinished local run, not a successful autonomous release. Current authorization excludes distribution and upload. Evidence and outstanding work are recorded in REPORT.md, STATUS.md and HANDOFF.md.

- Establish the local-development approval once and persist it. Repeated permission questions add no safety when the owner already authorized reversible implementation and tests. Keep release prerequisites separate and explicit.
- Test the entire automation chain during setup: app selection, screenshot, click, keyboard, window close/reopen, a real native file promise, and the exact executable path. A screenshot alone did not predict working native Computer Use; later clicks failed in the bridge. Native XCTest remained usable.
- Validate Apple test infrastructure before relying on it as the last gate. AppIntentsTesting metadata discovery, StoreKitTest SDK-header compilation under warnings-as-errors, and Instruments signpost collection each blocked isolated work despite unrelated app tests passing. Preserve failures; do not weaken strict checks.
- Check first-launch agreements for build tools in the supervised setup. Icon Composer's agreement blocked native icon assembly after the vector layers were prepared. Autonomous agents must not accept it under this project's rules.
- Use fresh, bounded performance data and retain the actual backend histogram, completed/persisted counts, prior inbox count, peak memory and responsiveness gaps. Accumulated synthetic inbox history distorted earlier measurements. Passing parser timing did not establish system-model timing or signpost evidence.
- Keep visual profiling separate from timing. Intrusive native stack sampling changed the measured workload substantially; its traces helped locate layout costs but could not support acceptance timing.
- Share one startup task, retain file grants across suspension, and gate all writes until persisted state is validated. A failed restoration must not be mistaken for an empty inbox. Test corrupt snapshots, failed watched ledgers and subsequent user actions together.
- Persist watcher delivery proof before acknowledgement and test restart recovery, pause/resume and background intake. Component unit passes alone did not establish real sandbox bookmark behavior.
- Independently review small changes, then rerun the combined app. Scoped component passes do not compose automatically into phase acceptance; the merged app passed83 core and8 functional interface tests while its accessibility audit still failed.
- Preserve model quality checks when changing performance. No speed result justifies silently changing extraction prompts, guardrail behavior, scoring thresholds or accepted fixtures.
- A recurring wakeup facility must be demonstrated, not assumed. No recurring background automation was available/created in this session; persisted state supports resumption but does not execute itself.

These observations are candidates for improving the next kit. Frozen specifications, criteria and verifier code remain unchanged in this run.
