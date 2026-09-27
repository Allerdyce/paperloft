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

- Native four-vector-layer icon integrated after independent scoped reconstruction review. Root strictRelease zero warnings/errors, compiledAppIcon.icns/Assets.car/CFBundleIconName and protectedbaselinePASS (evidence/icon/native-assembly.md).16pxtraypolish3/5 and fullAC16 remainopen; material-only trial rejected, originalcolors/geometry retained.

## Assumed
- Owner-confirmed manual app preferences; formal manual prerequisites are not all independently verified.
- Third-party synced-folder behavior is not independently tested.

## Not done
- P3 full independent UX acceptance; export/intents, purchases, performance, accessibility, design/QA and final documentation.
- Full app-facing resilience and actual app relaunch recovery.
- Membership/signing/ASC, full shakedown, acceptance tag and all distribution/upload/release work.

## 2026-09-27 receipt UX update
- **Verified:** scoped independent review, optimized build and two native UI tests pass for double-click source opening, deletion/restart/restore, existing duplicate/Undo flow and tax-export entry. Export12 tests and deletion6 core + actual-model case independently pass. Details: evidence/receipt-ux/verification.md.
- **Assumed:** transient blue Processing pill appearance is code-reviewed but was not captured; Paul signing setup depends on real team details.
- **Not done:** full P3/launch acceptance, personal-team signing, release/upload; prior accessibility/performance and isolated integration blockers remain.

Appearance/signing followup: native theme persistence test and screenshots PASS; optimized build PASS. Paid Paul team GQ4UA5C6RQ opt-in development build and deep strict signature verification independently PASS. Supersedes pending-team-details note above; does not clear distribution/full acceptance gates.

## Library reference correction
Verified: visual redesign, strict optimized build, native search/filter/View/appearance and double-click/delete/restart/restore tests; independent scoped review PASS. Root Computer Use confirmed the exact current Release app's Library with owner's existing receipts; earlier app binding issue resolved in this session after old processes retired. Evidence: evidence/library-redesign/verification.md. Full accessibility/performance/release gates remain incomplete.

## Real-receipt audit and reference UI — 2026-09-27

Local-only audit processed 18 original PDF/EML files into 22 document outputs without thrown extraction errors. Six text excerpts were separately converted to PDFs for supplemental testing; TXT import is not supported. All 20 indexed originals matched supplied hashes. No field-level ground truth exists, so no accuracy percentage is claimed. Private inputs, OCR, predictions and detailed report remain under ignored build/owner-receipt-pack and were not committed.

Findings include unsupported tax, service-period versus transaction-date confusion, merchant recognition errors, and OCR omitting visible totals followed by unsupported model output. These are open extraction limitations. The integrated tax safeguard retains the suggestion but requires review and lowers confidence when clear source evidence is missing. Deterministic replay of 22 saved outputs flags the identified unsupported tax and preserves the explicit supported tax; this was not a fresh model run.

UI now includes forest-green navigation, Settings in the sidebar, and colored Inbox status filters with counts. Selection stays consistent when filtering and when background imports change selection. Tax gets a specific warning and highlighted field. Expensify references informed styling; orange help pointers and unrelated banking/integration features were excluded.

Verification: independent scoped UI/source reviews PASS; InboxStatusFilters.xcresult 2 tests PASS; InboxStatusFilters2.xcresult targeted filter test PASS; tax branch strict package 12 XCTest + 68 Swift tests PASS, independent focused 3 + 7 PASS. Integrated strict Release and Paul development-signed Debug builds PASS (build/owner-pack-integrated-release.log, build/owner-pack-paul.log); codesign verification PASS; protected baseline PASS (build/owner-pack-final-baseline.log). Exact Release process freshly launched PID91366; accessibility tree confirmed new Settings sidebar. Subsequent Computer Use click/screenshot failed with state-change/native-pipe errors, so final populated-screen capture and native tax-warning appearance are not verified. Existing full accessibility/performance gates remain open. Release/uploads remain blocked.

Settings navigation follow-up: sidebar Settings now renders inside the main window with flexible layout and no duplicate heading. Footer uses Saved on this Mac + folder name. Native menu/toolbar preferences retain their conventional window. Strict Release build PASS (build/settings-page-release.log), independent source review PASS, native navigation test PASS (build/SettingsPage2.xcresult): no extra window, Settings content inside main, navigation back to Library. First test incorrectly read static-text label instead of value; corrected assertion. Computer Use native pipe prevented restarting the owner-facing Release process after rebuilding; reopen exact build to see changes.

Inbox follow-up: added accessible Add more receipts row using existing import flow. Added filingUnavailableReason mirroring all existing canFile conditions and displayed beneath disabled filing button. Independent source reviews and strict Release build PASS (build/add-more-filing-reason-release.log). Owner screenshot shows valid ready fields, no duplicate warning, and spinner; busy is suspected but runtime cause is NOT confirmed or repaired. No gate bypass. Current native interaction remains unverified; preserve owner ongoing receipt session.
