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

- P3 local self-gate FAIL (evidence/gates/P3-local-self.md): preflight/protected baseline/source integrity PASS; fullCI retains14audit findings after native PDF label repair. Independent phase acceptance remains pending.

## Assumed
- Owner-confirmed manual app preferences; formal manual prerequisites are not all independently verified.
- Third-party synced-folder behavior is not independently tested.

## Not done
- P3 full independent UX acceptance; export/intents, purchases, performance, accessibility, design/QA and final documentation.
- Full app-facing resilience and actual app relaunch recovery.
- Membership/signing/ASC, full shakedown, acceptance tag and all distribution/upload/release work.
