# Development report

## Verified
- P0–P2 local readiness independently PASS; formal gates remain deferred. Evidence: evidence/gates/P0.md, P1.md and P2.md. Accepted tests/fixtures/helpers appended to ACCEPTANCE.lock.
- Fresh Debug/Release builds with Swift6 strict concurrency and zero warnings;32 tests passed, none skipped; every locked test executed. Whole-kit coverage894/1015 lines(88.08%). See verifier-P2-47f evidence and P2 report for exact xcresult/log paths.
- System fixture scores: date100%, total99.26%, vendor97.78%, kind99.33%, category100%; fresh independent holdout:100%,96.30%,100%,100%,100%. Parser date100%,total99.26%. Scored only by frozen scorer. See verifier-P2-9283-system.txt, holdout.txt, parser.txt and P2 report.
- Classification refinement can fail without losing completed fields:16 fixture and15 holdout fallbacks explicitly reported; partial results require review. No guardrails disabled or refused requests retried.
-1,000 randomized filing/undo operations passed; actual SIGKILL during filing and undo recovered120 originals with matching paths/hashes. P2 engine boundary only; literal app relaunch remains a later check.
- Local protected baseline and privacy checks pass. Dedicated coverage build directories preserve instrumented artifacts while Release remains available for privacy inspection.

- P3 core UI self-check: 34 tests pass, clean Debug/Release with zero warnings, baseline/privacy pass. Result `build/Tests-20260926-230341.xcresult`; native sample/edit/file/search/undo and invalid-amount flows covered. This is not a P3 gate pass.

- P3 expanded package tests: 34 Swift Testing cases and 8 export XCTest cases pass (build/p3-integrated-package.log). Independently reviewed export engine PASS (evidence/export/independent-review.md).
- Five functional UI tests pass, including actual sandbox accountant-pack creation and durable draft relaunch (build/P3-export-ui.xcresult). The same complete UI run FAILS its accessibility test with16 findings; it is not a green CI result.
- Optimized QA configuration compiles with zero warnings (evidence/ci/QA.log). Separate native app reproduces system accessibility findings (evidence/a11y-probe/report.md), without product code or audit filtering.

- Latest complete CI attempt:45unit tests and5functional UI tests PASS; accessibility audit FAIL with15findings. build/Tests-20260926-234415.xcresult, build/p3-checkpoint-ci.log. No test excluded, no phase acceptance. Separate current Release build passes without warnings (build/p3-checkpoint-release.log).
- Real external-folder sandbox flow: system-model sample filed; ZIP+CSV+PDF created; PDF preview displays exact totals after export; copied SHA256 and ZIP integrity verified (evidence/export/external-sandbox-review.md).

- P3 local self-gate FAIL (evidence/gates/P3-local-self.md): preflight/protected baseline/source integrity PASS; fullCI retains14audit findings after native PDF label repair. Independent P3 subsequently FAILS; see the next entry.

- Independent P3 at d17b2bf:50tests PASS,1default accessibility audit FAIL,0skipped,32locked tests executed. Debug/Release/QA, privacy and protected baseline PASS; whole-kit coverage90.23%. Formal and local P3 remain FAIL. Evidence: evidence/gates/P3.md.

- Combined root watcher/startup/row checkpoint1d1bff7:83 core tests PASS (28 XCTest +55 Swift Testing), protected baseline PASS. Evidence: build/RootWatchIntegrated.xcresult, build/root-watch-tests.log, build/root-watch-baseline.log. Strict Release passed without compiler warnings. Full interface suite:8functionalPASS,1accessibilityFAIL with14findings; build/RootWatchUI.xcresult, build/root-watch-ui.log. No new full CI acceptance.
- Reviewed watcher component and actual native grant/restart/main-window-closed intake passed independently; evidence/watched-folder/selective-independent-review.md. Row edit/selection/duplicate/undo passed independently and in root before watcher merge; evidence/inbox-row-review/independent-review.md and build/RootRowIntegrated.xcresult.
- Fresh isolated100-document system run:100 completed and persisted, system backend100,0failed,358.972s (time FAIL),414.50MB peak and222.74ms heartbeat (limits pass). Parser direct limits pass in two fresh runs, but required signpost capture remains missing. Overall AC10 FAIL; no performance acceptance claimed.

- Independent partial design review observed dark ready-state review screen only: visible HIG/hierarchy/copy/polish4/5. QA build passed; native Computer Use bridge failed on next interaction. evidence/design/2026-09-27-critique.md; AC16 and persona checks incomplete.

- Current-root menu-bar Open Inbox independently passed17.485s after Library selection and closing main; new regression merged atdaef890 without product changes. evidence/menu-reopen/README.md. Final protected baseline check passed (build/final-local-baseline.log).
- Isolated prewarm candidate ed8b84e preserved all150 accepted predictions exactly (parent independently compared IDs/objects) and passed frozen accuracy, but timing failed80/100 at360.001s with one model error. No benefit established; source rejected, never integrated into root. Raw memory439.63MB/heartbeat220.70ms observations do not constitute completed acceptance assertions.

## Assumed
- Owner-confirmed manual app preferences; formal manual prerequisites are not all independently verified.
- Third-party synced-folder behavior is not independently tested.

## Not done
- P3 full independent UX acceptance; export/intents, purchases, performance, accessibility, design/QA and final documentation.
- Full app-facing resilience and actual app relaunch recovery.
- Membership/signing/ASC, full shakedown, acceptance tag and all distribution/upload/release work.
