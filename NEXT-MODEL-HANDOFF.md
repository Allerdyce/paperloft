# Paperloft 1.1 — handoff to the next model

Updated 2026-09-29 (next-model session: tasks A and B completed and merged; root `run/1` at `0e00dc7` plus this bookkeeping). Resume from the follow-ups below. No background automation is running. All subagents stopped safely, no builds/tests remain running, and `/Users/builder/Factory/.gui.lock` is absent.

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

## Completed 2026-09-29 (next-model session): task A

Refinement-routing repair is merged into root (`bbec7c6` via `3b96dcd`). A read receipt, invoice or bill stays routing-positive after the optional classifier fails: the cover body is suppressed, and `classificationError` plus `classificationUnavailable` review are kept. `not_receipt`+failure, invalid kinds and read failures stay unresolved. The status-test script now rebuilds the kit (it had been linking stale objects). Evidence: `evidence/intake11/refinement-routing-repair.md`. It passed an independent review and a mutation check. Classifier accuracy is unchanged.

## Classifier evidence and limits

- Parser80 synthetic diagnostics:80/80 source identities and labelled fields match; simple8-layout corpus, not holdout/formal accuracy.
- Separate system80 run:37 classification refusals across31/80 emails;49/80 usable exact selections,16 unwanted body selections,16/16 negatives correct. Frozen report-only scorer:33/64 financial date/total/vendor,15/24 body fields. All original hashes preserved. Results are not a model PASS.
- Paths: `build/email-diagnostics/system80-20260929`, `evidence/email-diagnostics/system80-independent-audit.md`, `evidence/intake11/corrected-email-diagnostics.md`.
- Diagnostic CLI originally ignored fields.classificationError in exit status; fixed1b7e517, raw results unchanged. Current reporting explicitly fails partial classifications.
- Native API investigation found no proven schema misuse: @Guide(.anyOf) is supported.64-token limit is a hypothesis, not established cause. Catch currently retains only reflected type/case, losing native debugDescription/metadata.
- Exactly ONE fresh synthetic classifier-only call using exact prompt/schema/default guardrails/64tokens succeeded as invoice in2.888s. It is inconclusive for earlier failures. No retries/variants/asynchronous explanation requests. Evidence `evidence/email-diagnostics/one-call-classifier-investigation.md`; raw probe ignored under handoff worktree `build/classifier-once-20260929`.
- Do not disable safety settings, hide failed results, substitute parser output to manufacture a model pass, or repeatedly resubmit refused inputs. Previous broad/combined classification prompts, unsupported reasoning and prewarm experiments are documented/rejected.
- Three owner cases ran once:two improved against independent source evidence; pickup confirmation remains selected with missing total (no invented amount). Four source hashes unchanged. `evidence/owner-receipt-rerun/bounded-regression.md`; details ignored under root `build/owner-receipt-rerun/run-20260929-once`.

## Completed 2026-09-29 (next-model session): task B

Signed App Intents are integrated into root as `7f15133` (cherry-pick of `01ccfd9`) and `0e00dc7` (cherry-pick of `6021dc0`); duplicate `1f0a69e` was not taken. The export now returns a bounded, memory-mapped Data-backed `IntentFile` (≤100 MB, `PaperloftIntentError.oversizedExport` above that, no URL fallback). The URL-backed result had failed because the sandboxed Xcode runner could not consume its sandbox extension. The framework test is unchanged. Evidence: `evidence/intents-signed/data-backed-export.md`.
- Combined root verification (worktree `/Users/builder/Factory/paperloft-intents-integrate`, logs `build/integrate/`): 123 XCTest + 113 Swift = **236 unit PASS**; AppIntentsTesting **7/7 PASS**; signed Release with 0 warnings; privacy, strict codesign and baseline PASS; direct status test PASS.
- Independent full-component review: PASS, no merge blockers.
- Open follow-ups:
  - Prune retained `Intent-Exports` ZIPs; they grow without bound. Delete only after mapping, and never truncate a mapped file.
  - Disclose the 100 MB Shortcuts export limit in Help/support (AC-20).
  - Large-ZIP memory, real Shortcuts/Siri/Spotlight, real StoreKit entitlement and closed-window Open Inbox remain unverified.
  - No formal AC-15 gate or full CI claim.
- Root pbxproj cosmetic dirt was preserved across the fast-forward (backup `build/root-pbxproj-normalization-20260929.patch`; semantically identical to HEAD).

## Completed later on 2026-09-29 (same session)

- **Full local CI** (`da0dfc7`, evidence/ci/full-ci-20260929.md): 145 XCTest passed, 1 failed (the audit only); 113 Swift Testing passed. `ci.sh` accepts `PAPERLOFT_CI_XCCONFIG=config/PaulDevelopment.xcconfig` so the App Intents tests run.
- **Follow-ups** (`5205c5a`): Finder shares keep the real file name; Shortcuts exports keep only the ZIP and prune exporter-created entries older than 10 minutes; the action states the 100 MB limit. NOTES.md records that the P8 Help/SUPPORT content must mention it. 236 unit tests pass.
- **Accessibility** (`72ce749`, evidence/a11y-probe/intake11-current/settings-isolation.md): all app-owned findings cleared, via larger captions, a shorter Paste hint, and tabbed Settings. The audit now audits each Settings pane as the only window. It **still fails**, on 10 system-owned findings (TouchBar ×7, emoji ×2, unattributed parent/child ×1), all reproduced in a minimal non-Paperloft app. That proposal is in PROPOSALS.md and awaits the verifier/owner decision; nothing is waived. The evidence-only diagnostic lives on branch `local/a11y-diagnostics` (not merged).
- **Open follow-ups:**
  - The embedded sidebar Settings screen isn't audited.
  - `ci.sh` fails on any "warning:" line in tests.log, including intermittent XCTest runtime priority-inversion notices; it should match only compiler warnings.
  - Keep the Claude desktop window and any other Paperloft copies clear of the test window during UI runs.


- **Live Finder Share: RESOLVED for Finder (2026-09-29, `2bdeb32`).** The blank share window was caused by a zero-frame NSHostingView. A/B via the new synthetic host `scripts/build_share_host_probe.sh`. A live Finder share with the fixed signed build delivered to the development inbox (badge 1→2, persisted across relaunch). Follow-ups:
  - Finder shares land as "Document N" because providers lack `suggestedName`. Take `url.lastPathComponent` in the `loadFileRepresentation` callback.
  - Inbox row identity is unchecked (no library in the development container).
  - Preview/Photos hosts and sheet accessibility are unverified.
  - Ten duplicate development-extension registrations were removed with `pluginkit -r` (list in `build/live-share/unregistered-share-copies.txt`). Only `paperloft-share-present/build/SharePresentRelease` remains registered.
  - Evidence: `evidence/live-share/finder-share-20260929.md`.

- Accessibility: app-owned findings cleared (see above); 10 system-owned findings remain pending the proposal. Historical: 18 findings (10 contrast, 6 descriptions, 1 hierarchy, 1 action). System TouchBar/emoji and inactive-window effects reproduced independently. Already-primary dark text in saved crops does not justify blind recoloring or a waiver. Current read-only triage `evidence/a11y-probe/intake11-current/read-only-triage.md`. No new evidenced repair. Optional future viewport-clipping diagnostic would be additive, not replacement acceptance.
- Live Share switch permission pending; no settings change. Real iPhone scan needs owner hardware/TestFlight later.
- StoreKit component isolated `/Users/builder/Factory/paperloft-commerce` b799b90:SDK27 deprecated header fails strict import;3 approaches exhausted, no suppression/merge.
- Native Mail promise wrapper isolated local/mail88dc439;3 drag attempts never generated source events. Saved .eml imports work; live drag unverified.
- System100-doc throughput358.972s fails240s; prewarm attempt rejected, required signpost capture unavailable. No blind repeat.
- Icon16px contrast3/5, formal acceptance tags, independent holdout/final gates and distribution prerequisites remain open. Never claim upload/readiness from the local results above.

## Completed 2026-09-30 (lead mode)

- **Earlier today (already in STATUS/readiness):**
  - the classifier guardrail fix (bills labelled "statement")
  - AC-20 docs and Help
  - QA persona sessions and fixes (QA-01…06)
  - the design critique `evidence/design/2026-09-30-critique.md`
  - the owner guide `docs/OWNER-RELEASE-SETUP.md`
- **AC-16 native-pattern follow-up** (merged; summary `evidence/design/2026-09-30-native/README.md`):
  - Receipt menu
  - export sheet with pickers and ⇧⌘E
  - Library with sortable, aligned headers, localized dates and currency, toolbar actions and ⌘F
  - review form with one label column and a currency pop-up
  - Inbox Import/Paste moved to the toolbar
  - Settings with folder display, fitted panes and a category list
  - View › Sidebar
- **What stayed on purpose, and why:** see that README. The Library look comes from the owner's reference, and frozen NavigationTests pins the sidebar and heading.
- **CI:** 155 XCTest pass. The audit fails only on the 10 known system findings. The audit test now waits for section switches to settle, because the window title was flagged mid-animation in 1 of 2 runs.
- **Gotchas:**
  - SwiftUI `Text` with an accessibility identifier exposes its string as XCUI `value`, not `label`.
  - The UI-test Inbox persists between runs (stub items all say "Sample merchant"), so tests must identify documents by row, not vendor.
  - 10 pt captions trip the contrast audit; use callout.
- **Icon:** unchanged. SPEC §6.5 routes the contrast tweak to the owner; the candidate is in PROPOSALS.md.

## Completed 2026-09-30 evening (lead mode)

- **Second design review** (`evidence/design/2026-09-30-r2-critique.md`, run by a critic subagent with background app tools on a QA build):
  - confirmed most first-round fixes
  - new P1s R2-01 (History Undo lost the receipt) and R2-02 (Remove couldn't be undone)
  - R2-03 found while fixing: ⌘Z was hard-wired to Undo Last Filing, even inside text fields
  - all fixed through the window's UndoManager, an Undo-to-Inbox return path with the confirmed values, and a notice banner; see BUGS.md
- **QA-05/07/08 fixed:**
  - attachment display names
  - a renamed library is followed through a renewed bookmark, verified live in the sandbox by `LibraryRenameUITests`
  - Return doesn't file an unverified total
- **Quick wins and polish:**
  - ⌘1–⌘3
  - one export name
  - empty states (no library, empty library, empty History)
  - Quick Look shows the row's name
  - rows lead with merchant and total
  - export summary line and Inbox notice
  - file-name example
- **AC-10:** `Tools/ConcurrencyProbe` showed two-at-a-time understanding gives no throughput gain (the model serializes sessions). The options and a recommendation are in PROPOSALS.md for the owner.
- **Still below 4 in the second review, by type:**
  - deliberate branding: green sidebar, serif heading, Library card rows
  - frozen-test constraints: NavigationTests pins the sidebar buttons and the Inbox heading
  - smaller polish:
    - Categories rows always editable
    - status chips vs segmented control
    - Help Book
    - History row selection
    - "Needs check" badge wording
  - Paywall and menu bar extra couldn't be reviewed.

## Dirty files and safe resumption

Root has intentional pre-existing dirt: Xcode project comment normalization and settings reordering only; `evidence/ci/{QA,preflight,tests}.log`, `evidence/preflight-latest.txt`, old untracked verifier artifacts. Preserve; no blanket git add/reset/cleanup. This handoff commits only its own docs/PLAN/STATE/STATUS changes. Worktrees must remain for resumption; do not archive/delete them.

No GUI lock or running agent job remains. Agent names are not a durable dependency; all work is saved in the stated files/branches. Resume taskA or taskB, keep commentary concise and frequent, and report remaining technical failures honestly. The owner dislikes repeated permission requests and reassurance without progress.
