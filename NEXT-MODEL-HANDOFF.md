# Paperloft 1.1 — handoff to the next model

Updated 2026-09-29. The owner requested this checkpoint because weekly model credits are nearly exhausted. **Stop here; resume when the owner continues with the next model.** No background automation is running. All subagents stopped safely, no builds/tests remain running, and `/Users/builder/Factory/.gui.lock` is absent.

## Goal and authorization

Complete Paperloft Receipts 1.1 development/testing, then distribution signing, release archives and App Store Connect upload **only when readiness checks pass**. Owner explicitly authorized those conditional distribution actions; do not ask again. **Submission for review and public release remain prohibited.** See `docs/DISTRIBUTION-AUTHORIZATION.md`.

App is NOT finished or launch-ready. General development is not blocked by the owner. Live Share testing alone has a pending permission question: whether to enable Paperloft in macOS Sharing extensions. It was observed OFF. Do not toggle System Settings without the answer; AGENTS.md prohibits settings changes. Real iPhone scanning will require owner hardware later.

## Repository and startup

- Main repo: `/Users/builder/Factory/paperloft`, branch `run/1`. Chat cwd may be unrelated; always specify the repo/worktree explicitly.
- Root source checkpoint before this handoff commit: `2db08bd`; root commits `b0e620d` and `2db08bd` are respectively watched-help wording and one-call classifier evidence after prior pushed `c3d5dbd`.
- Read `AGENTS.md`, `LESSONS.md`, this file, `STATE.json`. Run `scripts/preflight_check.sh --local --log` and `scripts/verify_local_baseline.sh`. Latest run:39 PASS,1 WARN,0 FAIL,0 TFAIL,15 MANUAL (`build/intake11-reliability-preflight.log`); baseline PASS.
- `acceptance-v1` is still deferred. Protected kit baseline is `640eab51a302cef28e57cd17f481673043c7dc9d`. Do not change frozen SPEC/ACCEPTANCE/AGENTS, locked tests, or frozen scorer. Do not claim formal gates from local checks.
- Follow atomic GUI lock protocol before native UI/model harness work. Only one agent drives GUI at once. AGENTS allows independent P3+ agents in separate worktrees; do not mutate another agent's checkout.
- Never read Factory/holdout or Factory/private-samples. Owner explicitly authorized `/Users/builder/Downloads/recipt-test-pack`; keep private content/names/amounts/screenshots in ignored local output only.
- Paid Apple development team Paul Allerdyce `GQ4UA5C6RQ`; config `config/PaulDevelopment.xcconfig`. App development ID `app.paperloft.receipts.development`, share extension suffix `.share`.

## Verified root state

`evidence/intake11/hardening-followup.md` is the latest integrated check:
- **214 unit tests PASS** (101 XCTest +113 Swift), `build/Intake11HardeningUnit2.xcresult`. Initial wrong-target command ran no tests; corrected result is authoritative.
- Fresh development-signed Release **zero warnings/errors**, strict deep signature and privacy checks PASS. App: `build/Intake11HardeningSigned/Build/Products/Release/Paperloft Receipts.app`; log `build/intake11-hardening-signed.log`.
- Last full green CI remains `d9454df`; unit/build results are not full CI or acceptance.
- Complete native UI regression earlier:15 functional PASS,1 unchanged accessibility audit FAIL with18 findings, `build/Intake11OwnedNativeAll.xcresult`. No exclusions. Subsequent changes have scoped tests, not another full GUI run.
- Added 10,000 diverse MIME stress cases:3,159 parsed,6,841 declared safe rejections;0.84s optimized loop. All80 synthetic seeds get operators; harmless added headers preserve original parse. Independent review `evidence/intake11/mail-corpus-mutation-review.md`. No peak-memory/completeness/formalAC102 claim.
- Common owned IntakeQueue is integrated across imports/paste/watch/mail/share/scan. Publication is atomic; durable Inbox proof precedes upstream acknowledgement. Original identity is separate for Move. Preserve recovery, validation, per-support startup ownership, generation guards and ambiguous-write freezing when adding adapters.
- Temporary cleanup removes only proven committed Mail parents/current-attempt scratch or safely retired removed records. Unknown/ambiguous orphans remain. Do not simplify cleanup casually.
- PDF raster scaling corrected previously missed OCR text; parser uses document evidence and blank OCR fails closed. Classification failure provenance now survives negative assessment/restoration. Copy-phase stripping of an already signed extension fixed via host COPY_PHASE_STRIP=NO; no warning suppression.

## Immediate task A: email routing after optional classifier failure

**NOT IMPLEMENTED.** Read-only design review approved a narrow routing repair; this is the best next root task.

Current `SystemBackend` successfully extracts ModelFields, then independently refines document type. On refinement failure it retains fields.kind, lowers confidence, stores classificationError and requires review. `MailReviewPreparation.prepare` currently checks classificationError *before* valid financial kind and marks the attachment unresolved, thereby adding the cover email unnecessarily.

Approved boundary:
1. A successful read with valid receipt/invoice/bill kind remains routing-positive even if the optional refinement failed: retain attachment, suppress cover body, preserve classificationError and mandatory review/no auto-file.
2. Read/extraction failure, blank OCR or invalid kind remains unresolved.
3. `not_receipt` plus refinement failure remains visible/unresolved; do not silently discard it to improve scores.

Implementation workspace prepared and clean: `/Users/builder/Factory/paperloft-intake11-handoff`, branch `local/intake11-handoff`, HEAD `0a8c88bf766ec399b3b72b145f4439ba444b6521` (merged root2db08bd). No edits/tests started on this repair.

Next edits/checks:
- Reorder the two disposition checks in `Apps/PaperloftApp/MailReviewPreparation.swift`.
- Add `Tests/PaperloftAppTests/MailRoutingRefinementTests.swift`: all3 positive kinds with/without classification failure, body renderer not called/read once, errors persist and cannot auto-file, negative/error/invalid/thrown cases preserved.
- Existing unlocked `Tools/EmailDiagnostics/StatusTests.swift` expects body+attachment for a failed invoice. Update that policy assertion: financial=>attachment only/0 body renders; negative+error=>body+attachment/1 render. Check lock before any edit.
- Run strict unit/direct tests and independent review before merging. **Do not change projector/scorer or erase errors.** This repairs candidate presentation, not model accuracy. No repeated refused model calls are needed for these injected/replay tests.

## Classifier evidence and limits

- Parser80 synthetic diagnostics:80/80 source identities and labelled fields match; simple8-layout corpus, not holdout/formal accuracy.
- Separate system80 run:37 classification refusals across31/80 emails;49/80 usable exact selections,16 unwanted body selections,16/16 negatives correct. Frozen report-only scorer:33/64 financial date/total/vendor,15/24 body fields. All original hashes preserved. Results are not a model PASS.
- Paths: `build/email-diagnostics/system80-20260929`, `evidence/email-diagnostics/system80-independent-audit.md`, `evidence/intake11/corrected-email-diagnostics.md`.
- Diagnostic CLI originally ignored fields.classificationError in exit status; fixed1b7e517, raw results unchanged. Current reporting explicitly fails partial classifications.
- Native API investigation found no proven schema misuse: @Guide(.anyOf) is supported.64-token limit is a hypothesis, not established cause. Catch currently retains only reflected type/case, losing native debugDescription/metadata.
- Exactly ONE fresh synthetic classifier-only call using exact prompt/schema/default guardrails/64tokens succeeded as invoice in2.888s. It is inconclusive for earlier failures. No retries/variants/asynchronous explanation requests. Evidence `evidence/email-diagnostics/one-call-classifier-investigation.md`; raw probe ignored under handoff worktree `build/classifier-once-20260929`.
- Do not disable safety settings, hide failed results, substitute parser output to manufacture a model pass, or repeatedly resubmit refused inputs. Previous broad/combined classification prompts, unsupported reasoning and prewarm experiments are documented/rejected.
- Three owner cases ran once:two improved against independent source evidence; pickup confirmation remains selected with missing total (no invented amount). Four source hashes unchanged. `evidence/owner-receipt-rerun/bounded-regression.md`; details ignored under root `build/owner-receipt-rerun/run-20260929-once`.

## Immediate task B: signed App Intents integration — major new progress, isolated

Workspace `/Users/builder/Factory/paperloft-intake-queue`, branch `local/intents-signed`, **HEAD01ccfd9**, committed/pushed/clean. **Do not merge yet:6/7 framework tests pass, one export transport failure remains.** Future cherry-pick only01ccfd9; ancestor1f0a69e duplicates root watched-help wording.

Read `evidence/intents-signed/README.md` there first. Prior local/intents atdb1a3f3 had3 failed ad-hoc discovery attempts. Paid same-team app+runner signing and actual matching development bundle lookup now clear metadata discovery. This was a genuinely new supported setup, not a blind retry.

Current isolated component:
- Four App Intents/Shortcuts:File Document, Export Accountant Pack, Total Spent, Open Inbox.
- New .shortcut intake origin; file action stages owned bytes, awaits common publication guard and persists Inbox snapshot before acknowledgement; original Move disabled.
- Actual development test lookup uses explicit unlocked `Tests/Support/IntentTestInfo.plist`; generated customInfo keys alone were ignored for UI bundle.
- App, runner and test bundle verified Apple Development/teamGQ4UA5C6RQ; all4 intents present in metadata.
- **229 unit tests PASS** (116 XCTest+113 Swift); strict fresh signed Release0warnings/errors, privacy/signatures/baseline PASS.
- One genuine framework run **6/7 PASS**:metadata, invalid dates, empty-input rejection, file delivery/relaunch, free Pro gate, Open Inbox, Total Spent pass.
- **Pro ZIP return FAIL:**cross-process IntentFile decoding emits sandbox_extension_consume EPERM/security-scope-signature failure, LNValue unarchive then castingFailed NSNull→IntentFile at `let file: IntentFile = try result.value`, before reading bytes. Failing test remains enabled.
- Result: `build/IntentSignedFramework.xcresult`; logs `build/intents-signed/{framework,unit2,release}.log`.

Next supported investigation: inspect SDK/Apple IntentFile transport APIs and scope issuance. Current output uses documented URL-backed persistent app-owned ZIP. Adding startAccessingSecurityScopedResource in the test cannot fix decoding that fails before IntentFile exists. Data-backed IntentFile is supported but could inflate memory for large exports: design bounded allocation/large-export behavior before changing it. No fix or retry has been attempted. Keep real framework test enabled; all7 must pass before scoped acceptance/merge. Root reviewed initial adapter but full final independent review remains necessary.

## Other gates and owner dependencies

- Accessibility18findings unresolved:10contrast,6descriptions,1hierarchy,1action. System TouchBar/emoji and inactive-window effects reproduced independently. Already-primary dark text in saved crops does not justify blind recoloring or a waiver. Current read-only triage `evidence/a11y-probe/intake11-current/read-only-triage.md`. No new evidenced repair. Optional future viewport-clipping diagnostic would be additive, not replacement acceptance.
- Live Share switch permission pending; no settings change. Real iPhone scan needs owner hardware/TestFlight later.
- StoreKit component isolated `/Users/builder/Factory/paperloft-commerce` b799b90:SDK27 deprecated header fails strict import;3 approaches exhausted, no suppression/merge.
- Native Mail promise wrapper isolated local/mail88dc439;3 drag attempts never generated source events. Saved .eml imports work; live drag unverified.
- System100-doc throughput358.972s fails240s; prewarm attempt rejected, required signpost capture unavailable. No blind repeat.
- Icon16px contrast3/5, formal acceptance tags, independent holdout/final gates and distribution prerequisites remain open. Never claim upload/readiness from the local results above.

## Dirty files and safe resumption

Root has intentional pre-existing dirt: Xcode project comment normalization and settings reordering only; `evidence/ci/{QA,preflight,tests}.log`, `evidence/preflight-latest.txt`, old untracked verifier artifacts. Preserve; no blanket git add/reset/cleanup. This handoff commits only its own docs/PLAN/STATE/STATUS changes. Worktrees must remain for resumption; do not archive/delete them.

No GUI lock or running agent job remains. Agent names are not a durable dependency; all work is saved in the stated files/branches. Resume taskA or taskB, keep commentary concise and frequent, and report remaining technical failures honestly. The owner dislikes repeated permission requests and reassurance without progress.
