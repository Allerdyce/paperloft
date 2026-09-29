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

Review workflow refinements (2026-09-27): Confirm replaces File Copy, with copy/move behavior explained; Remove is red and only removes Inbox entry, preserving source. Add-more row remains. Shared display status separates Ready, Processing, Duplicate and Issue; Issues includes extraction assessment warnings and invalid drafts, not only failed imports. Overall uncertainty stays a receipt-level notice, no longer outlines every field. Invalid field messages appear directly below that field; empty tax is valid. Calendar picker uses explicit Use date, preserving typed input until confirmation.

Ready receipt confirmation now proceeds during background operations. Owned operation tokens preserve exclusive library changes and prevent one task clearing another's lock; watched delivery ledger commits serialize and stale refreshes cannot replace newer results. 36 XCTest + 68 Swift tests PASS, including 4 concurrency regressions (build/concurrent-confirmation-tests.log). Native review flow PASS (build/ReviewRefinements.xcresult): issue filtering, calendar, Confirm/Remove labels, missing-total message and re-enabled confirmation after correction. Strict Release and protected baseline pass. Full launch gates remain open; existing owner-facing process may need reopening to load the rebuilt binary.

Final independent scoped source/concurrency review PASS. Reviewer caught stale Waiting status text and filter-driven selection changes; both corrected. Active editable receipt remains visible until selection/filter changes or confirmation; Processing rows are not pinned. Native tests ReviewRefinements2/3 PASS, including actual Issue text; final ready-only pin narrowing strictly rebuilt and source reviewed, not separately exercised with a real-model ready-to-issue transition. No full acceptance/release claim.

Issue explanation follow-up: replaced generic review notice with an exhaustive list of recorded assessment reasons under Why this needs checking. Differentiates uncertainty/cross-check failures from invalid fields, and original extraction problems from user corrections. Strict Release build PASS (build/issue-explanations-release.log), independent source review PASS, native IssueExplanations.xcresult PASS including visible parserUnavailable reason. No new extraction accuracy claim or private data committed. Remove text explicitly red inside button label.

Review simplification and inspection: removed header extraction explainers and duplicate tax warnings. Short verification actions now sit under relevant orange fields; missing category prompts its field. Original import notices remain available in collapsed Import details below actions. Cross-check parsing is cached in StoredReview without changing Codable format. Calendar hides its redundant label, uses intrinsic compact sizing, opens toward window center and keeps explicit Cancel/Use date. Preview now has Expand preview and a clickable document overlay using native resizable Quick Look, preserving current draft.

Final verification: MailFlow PASS in ExpandedReceiptPreview3.xcresult, preserving notices and original email bytes. ExpandedReceiptPreview5.xcresult PASS: both explicit Expand preview and direct receipt click open Quick Look; returning preserves fields; inline validation and calendar interaction pass. Calendar screenshot inspected at build/expanded-preview5-attachments/F3A56A89-000D-42FF-B594-52FFED171F09.png: compact and wholly inside main window. Strict Release and baseline PASS. Independent source review PASS; inherited accessibility identifiers found by native tests corrected with explicit child containers. Owner running session not restarted.

Inbox bulk controls and Library cleanup: checkboxes select individual Inbox items, Select all selects current visible view, Clear selection resets, and red Remove selected removes only entries (original files untouched). Filter changes clear selection and disappearing entries are pruned. Conflicting busy operations disable bulk removal. Removed duplicate top toolbar import/sample/settings icons; Inbox controls, sidebar Settings, native preferences shortcut and File menu remain. Library selected rows retain normal surface and show border only; native keyboard/context selection preserved. Independent source review PASS; strict Release and protected baseline PASS. Native bulk/selection checks underway.

BulkAndSelection.xcresult: both native tests PASS (select-two/remove, select-all/remove, Library filters/View/appearance). Selected Library row screenshot inspected: border only, normal background and readable text; toolbar icons absent. Scoped independent source review PASS. Full launch gates unchanged.

Inbox cleanup: header shows only Processing while pending; all result counts remain in filters. Paste image is available as a button in empty and populated Inbox. Owner-facing sample actions removed; fixture loading/reset are DEBUG-only. Strict Release build and protected baseline PASS. InboxCleanup2.xcresult scoped native Inbox flow PASS, including Paste button availability in both states and absent Ready header; first run caught link-style accessibility mismatch, corrected. Actual clipboard import was not exercised. Full P3 and release gates remain open; running owner session preserved.

Inbox creation controls: Add receipts and Paste image now fixed above left receipt list, replacing bottom add row and global paste action. Successful paste selects new item, reveals All filter, scrolls to it and shows Image added. Returning to Inbox preserves selection/filter. Strict Release, local preflight and protected baseline PASS; independent source review PASS. InboxCreation.xcresult native Inbox flow PASS; screenshot inspected confirms fixed top-left controls. Actual long-list clipboard paste/scroll was source-reviewed, not exercised end-to-end; owner clipboard untouched. Full launch gates unchanged.

Inbox action row: Paste then Import aligned side by side at far right of filter row, outside horizontal filter scroll. Removed left creation header; paste feedback retained beneath actions. Strict Release, protected baseline, independent source review and InboxActionRow.xcresult PASS. Native assertions verify labels, ordering and vertical alignment; screenshot inspected. Owner running process preserved. Release/uploads blocked.

Entry/calendar design pass: Import and Paste are distinct outlined icon boxes at right of filter row. Replaced compact graphical picker with spacious seven-column calendar, direct month/year menus, month arrows, Today and selected-date footer, retaining Cancel/Use date. Gregorian month heading matches grid; selected-day text adapts to dark mode. Strict Release and baseline PASS. EntryCalendar.xcresult native UI PASS including month navigation, Today/Cancel preserves draft and Use date; screenshot inspected. Leap-day selection and final dark-mode contrast tweak source reviewed, not separately UI exercised. No release/upload.

Empty Inbox redesigned as two side-by-side Import/Paste cards, each icon/title/explanation/CTA, plus drag guidance. Native EmptyInboxCards.xcresult PASS and screenshot inspected; final icon height aligned. Protected baseline PASS. Actions and IDs preserved. No release/uploads.

Empty Inbox cards: final strict Release build and independent source review PASS.

## 2026-09-27 — 1.1 local intake testing

Implemented scan page modes, bounded provider copying, an embedded Share extension and durable shared Inbox delivery. Added bounded forwarded-mail parsing and watched-file identity regressions. Independent scoped code review passed after fixing provider races, traversal permissions and process-lifetime Inbox ownership.

Verified: Intake11OwnershipUnit.xcresult passes 41 XCTest + 79 Swift tests; signed development Release and deep signature/privacy checks pass. Handoff package independently passes 14 strict tests; headless provider smoke passes. These are local checks, not full CI or acceptance.

Still open: real Finder/Preview/Photos sharing (system Share menu displayed “Unlock Mac to continue with Siri request”), actual iPhone scan, complete Mail candidate/rendering/scoring work, watched app-level rename identity and existing accessibility/performance gates. No release or upload.

## 2026-09-29 — Authorized distribution boundary and Mail integration

### Verified

- Conditional distribution signing/archive/ASC upload permission recorded in docs/DISTRIBUTION-AUTHORIZATION.md; submission and public release remain blocked. Display preflight cleared (build/intake11-authorized-preflight.log).
- Receipt attachment selection, notices, relaunch, removal and original bytes: native test PASS. Body-only HTML import exercises actual sandbox fallback and the same lifecycle: native test PASS. Evidence: build/Intake11MailNativeFallback.xcresult (2 tests). Earlier WebKit-only failure retained in build/Intake11MailNativeIsolated.xcresult.
- Final integrated root unit run: 46 XCTest + 100 Swift tests PASS (build/Intake11MailFinalUnit.xcresult), including the additive ledger. Earlier hint run passed 46 + 93 (build/Intake11MailHints2.xcresult). Ledger tests and integration contract: evidence/intake11-mail/message-id-dedup.md.
- Signed development Release: build/intake11-mail-fallback-signed-release.log; deep strict signature verification PASS; app/extension privacy checks PASS (build/intake11-mail-fallback-privacy.log); protected baseline PASS (build/intake11-mail-fallback-baseline.log). This is development signing, not a distribution archive.
- Independent scoped source reviews PASS for candidate selection/integration, hints, native renderer fallback and Message-ID ledger. Renderer sandbox and hostile-resource probes documented in Tests/EmailBodyRendererTests/README.md.

### Assumed / limited

- Sender-derived merchant is only a hint. Existing nonempty document values are never replaced; low-confidence nonempty merchant refinement remains conservative.
- HTML becomes a bounded text transcription, not a faithful recreation of the original HTML layout. Native PDF fallback is an explicit deviation from the requested WebKit path.

### Not done

- Message-ID ledger-to-Inbox transaction integration, partial-failure retry policy, unified intake queue, full email fixture and holdout scoring, live Mail promises, Finder/Preview/Photos Share and real iPhone scanning.
- Existing full accessibility, system throughput, StoreKit/App Intents, icon and formal/final gates. No full CI/1.1 completion claim, archive, upload, submission or public release.

## 2026-09-29 — Transactional Mail duplicate recovery

Verified: durable Inbox proofs precede Message-ID ledger acknowledgment; startup replays committed proofs and blocks mutation on ambiguous recovery. Nine failure/recovery tests passed in the independently reviewed branch; strict Release and 155 combined unit tests passed there. Root native MailFlow tests both PASS in build/Intake11MailDuplicateNative2.xcresult: attachment selection and HTML body import, review preservation, removal, same-ID changed-byte duplicate and persistence across restart. Original fixtures unchanged. Root combined unit regression is still running.

Not done: watched EML integration and updated accessibility repairs are in progress. Live Share requires enabling the currently disabled system sharing extension; owner permission requested because AGENTS.md prohibits System Settings changes. Full launch readiness remains unverified.

Root combined duplicate regression PASS:55XCTest+101Swift tests (156total), build/Intake11DuplicateCombined.xcresult. Native Library filter/search/View/light-dark flow PASS69.22s, build/Intake11NativeFilters.xcresult; both captures visually inspected. Scoped picker implementation reviewed independently. WatchedEML/TIFF merged8445cdd after independentreview: author59XCTest+101Swift tests and strictReleasePASS, evidence/intake11-mail/watched-mail-routing.md. Latest full accessibility audit21findings remainsFAIL; four product popup actions and11old nearcontrast findings cleared. Two further review-caption primarycolor changes compilePASS but not reaudited; see evidence/a11y-probe/intake11-current/repair-report.md.

Common owned intake merged403f362 after independent source review. Author84XCTest+101Swift tests (185) and strictReleasePASS. All new adapters stage through IntakeQueue; restored queuedbytes validate before OCR/preview/Copy, original Move uses reviewedhash; corruption fails closed, ambiguous Inboxsave recovers before watched retry, and retained Shareclaims validate extant ownedcopy beforeack. Component tests include13author+3independent adversarialcases; see evidence/intake-queue/. Root complete nativeUITarget is running in build/Intake11OwnedNativeAll.xcresult. Temporary-record cleanup is separately in progress and no fullreadiness claim is made.


## 2026-09-29 — Complete native regression and temporary cleanup

Verified: root product403f362 passed all15 functional native UI tests, including Mail restart, Library deletion/restore/tax export and watched background recovery. The unchanged accessibility test failed18 findings (10contrast,6descriptions,1hierarchy,1action); complete suite exit65 remainsFAIL. See evidence/intake-queue/native-regression.md and build/Intake11OwnedNativeAll.xcresult. No excluded tests or weakened audit.

Temporary cleanup73988db independently reviewed and merged5b0a88f: committed raw Mail parents and current-attempt scratch are removed only after durable owned delivery; failed/ambiguous transactions retain recovery copies. Root unit run build/Intake11CleanupUnit.xcresult passed88XCTest+101Swift tests (189total). This later cleanup was not part of the preceding UI run. Startup retirement99fceec remains unmerged pending fixes for same-process startup reentrancy and conflicting references; unknown orphans must remain preserved. Email field diagnostics are underway, not a formal accuracy pass.

Root Release5b0a88f compiles successfully but emits one Xcode PaperloftShare metadata warning (no AppIntents.framework dependency). It does not meet warning-free strict CI. App/extension privacy checks and pre-tag protected baseline pass; logs build/intake11-cleanup-root-release.log and build/intake11-post-cleanup-baseline.log.


Startup removal retirement merged9719ddb after independent re-review of99fceec+d21e08f. Root200unit tests and3native Mail/Library restart flows PASS; see evidence/intake-queue/startup-removal-retirement.md. Synthetic diagnostic harness38de26f merged303fd42 after unchanged-enum comparison and5projection tests. Its5-message parser smoke preserves two production failures (receipt attachment missed; terms treated as invoice); body subset2/2 is diagnostic only. No full80-email/system-model or formal gate claim.

Share metadata warning fixed by target-only task configuration c5e1a4f after source review; fresh unsigned isolated Release has zero warnings, main-app extraction remains enabled. Root signed integration build remains pending subsequent extraction fixes.

## 2026-09-29 — Recognition fixes and model diagnostic outcome

Verified: bounded PDF raster scaling and generic parser document evidence fixes merged4b919a3; root208unit tests pass. Parser80 synthetic run matches all provisional source identities and labelled fields, independently audited. Separate system80 run does not pass readiness:37partial classification refusals across31messages;49/80usable identities and33/64labelled financial predictions. Independent audit preserves full denominators; see evidence/intake11/corrected-email-diagnostics.md and evidence/email-diagnostics/system80-independent-audit.md. No retries or safety-setting changes. Diagnostic CLI failure accounting is fixed in1b7e517; root model-free status and unresolved-candidate regressions pass.

Verified: final development-signed Release compiles, strict/deep signature and privacy checks pass; one signed-extension stripping packaging warning remains. Pre-tag protected baseline passes, formal baseline deferred. See evidence/intake11/final-development-build.md. Three private owner cases ran once with unchanged originals; two improved and one no-total pickup confirmation remains incomplete. See evidence/owner-receipt-rerun/bounded-regression.md.

Assumed: neither simple synthetic diagnostics nor three targeted private examples establishes general receipt accuracy. No formal email holdout or end-to-end readiness verdict.

Not done: model classification reliability, full accessibility, performance, live intake integrations and existing formal release gates. Conditional distribution authorization is recorded but readiness has not passed; no archive/upload/submission/public release.

## 2026-09-29 — Hardening continuation

Verified: root214unit tests PASS, fresh development-signed Release0warnings/errors, strict deep signature/privacy/pre-tag baselinePASS. Negative assessments retain classification-failure provenance across saved Inbox restoration. Signed-extension copy no longer asks to strip signed bytes. Additive10000-case MIME corpus safety test independently reviewed and passed. See evidence/intake11/hardening-followup.md.

Assumed: none of these changes solves the separate system-model classification failures or establishes broad extraction accuracy.

Not done: previously recorded accessibility, model reliability, performance, live integrations and formal readiness remain. No distribution archive/upload/submission/public release.
