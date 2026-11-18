## 2026-11-18 — Production app record created

Apple agreements, bank and W-9 visibly Active. Registered app.paperloft.receipts (no optional capabilities yet) and created Paperloft Receipts, macOS, en-US, SKU paperloft-receipts-macos, App Store ID 6836564418. Version 1.0 Prepare for Submission. Apple reported user-access settings could not be saved, with all existing users having access (same Full Access intended). Screenshot build/app-store-record-created.jpg. No build uploaded. Extension/App Groups provisioning, IAP/listing metadata, local StoreKit shakedown and independent reviews still remain. Integrated CI/performance evidence committed/pushed.

## 2026-11-18 — Integrated checks passed; API unblocked

CI 448 tests passed, zero failures/skips; clean Debug/Release. Coverage 97.87%, privacy PASS. System performance 361.847/361.930 seconds, parser 24.480/23.934 seconds; all 100 documents each run, no failures. Required metrics captured; performance_evidence_check.py PASS. Evidence system-20261118T231955Z and parser-20261118T233237Z. API now returns ASC_NO_APP for app.paperloft.receipts (agreement restriction cleared). Next create ASC app record, local StoreKit purchase shakedown, independent P6/P7 reviews, remaining integration checks. No archive/upload/submission.

## 2026-11-18 — Owner tax and banking setup verified

App Store Connect shows U.S. W-9 Active, submitted Nov 18. Payout bank account is Processing; Apple explicitly says changes should appear in 24 hours. API probe still returns 403 FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED. No additional owner input requested now. Recheck activation before release work. Local preflight passed: 42 PASS, 2 WARN, zero FAIL/TFAIL; all 185 locked hashes and append-only lock history pass. Integrated full CI/performance following the Settings repair remains next; no new full CI launched at this checkpoint. No archive/upload/release.

## 2026-11-18 — Paid Apps Agreement accepted

Owner gave action-time approval. Submitted agreement; Apple now shows effective Nov 18, 2026–Jul 14, 2027, Pending User Info. U.S. Form W-9 is Missing Tax Info; no payout bank account shown. Owner asked to complete Add Tax Info and Add Bank Account directly in Apple. A second old Pending (New Legal Entity) row remains; do not assume fully resolved. Screenshot: build/paid-apps-agreement-accepted.jpg. No upload or release performed.

## 2026-11-18 — Release credentials completed; Apple agreement pending

Owner approved all three credentials. Apple Distribution and Mac Installer Distribution certificates were issued and imported into the login keychain. Paperloft Release App Store Connect API key (App Manager) was created and stored locally with restricted permissions. Ignored local team configuration and protected asc.env were updated. No private key contents were logged or committed.

Full preflight: 48 PASS, 2 WARN, 1 FAIL, 0 TFAIL, 5 MANUAL. The remaining API failure is HTTP 403 FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED, not an invalid key. EvidencePair LLC Paid Apps Agreement is Pending (New Legal Entity). Its agreement dialog is open in App Store Connect. Action-time approval requested under the computer-use tool's mandatory legal-agreement policy; acceptance has NOT occurred. Organization membership itself is active.

No release archive, upload, submission, or public release performed. Integrated CI/performance after the Settings repair and remaining independent release checks are still required. Resume from the pending agreement approval; do not recreate credentials.

## Staged Apple credential requests — November 18, 2026

Live Apple portal confirms EvidencePair LLC organization, Team GQ4UA5C6RQ, Account Holder, renewal July15 2027; latest Program License Agreement accepted November18. Xcode creation menu remains disabled, but web portal accepts CSR staging. No issuance performed yet.

Prepared two local RSA keys/CSRs in ~/Factory/.secrets/paperloft-signing-20261118 (restricted permissions; NEVER commit/read key contents into logs). In-app browser tabs:1 Apple Distribution CSR staged at Continue;3 Mac Installer CSR staged at Continue;2 ASC Generate API Key modal named Paperloft Release with App Manager role, Generate not pressed. Owner confirmation requested because computer-use tool requires action-time confirmation for new security-sensitive credentials. Team-wide access disclosed. Existing unrelated keys untouched. Persist/mark tabs again after future turn if needed.

After approval: issue/download/install certificates, create/download API key once, securely set asc.env real key/issuer/team (issuer visible in ASC; never log key contents), verify full preflight and remaining account setup. No readiness or upload claims yet. Integrated CI/performance on latest Settings change still pending.

## Apple setup checkpoint — November 18, 2026

Owner signed into Xcode. UI verifies EvidencePair LLC, Admin, Certificates/Identifiers/Profiles access. Manage Certificates lists only Apple Development identities; all creation menu choices disabled, reason not established. Opened developer.apple.com/account in in-app browser; separate sign-in required. Owner asked to sign in; browser handoff pending. No certificate/account mutations performed. GUI free for owner; integrated regression postponed during sign-in.

## Latest restart point — November 18, 2026

Settings repair `4c361ce` is independently scoped-reviewed and merged into run/1. Five targeted UI tests, including all inline Settings tabs in Light/Dark, and strict signed Debug/Release builds pass. No audit exceptions added. Earlier full CI (446 tests) and fresh AC-10 passed before this UI change; integrated regression/performance must be refreshed before claiming final current-source readiness.

The owner is asked to sign into Xcode → Settings → Apple Accounts. GUI is free; do not seize it until owner completes that handoff. Xcode inspection found no signed-in accounts. API key absent from standard key folder and Downloads; local asc.env remains placeholders. Owner confirms organization conversion complete. Never request credentials in chat.

Next: after owner sign-in, inspect team/certificates; perform authorized setup within tool confirmation rules. Run integrated CI/performance and independent gates, remaining purchase/design/persona/device checks. Nothing archived/uploaded/submitted/released.

## Owner update — 2026-11-18

Owner confirms Apple membership conversion to EvidencePair LLC is complete. Do not keep migration approval listed as pending. Local distribution certificates/API configuration still need verification/setup. Owner also closed Storage/System Settings after heavy background CPU activity was observed during performance testing.

## Progress — 2026-11-18 regression complete

Power/storage blockers cleared. Full signed CI on local/signpost-persist passed, including 44 UI tests and strict Debug/Release. Six-line persisted-signpost fix independently reviewed and merged into run/1. Fresh performance measurements next; provenance scripts now include Configuration. Release credentials and remaining purchase/design/persona/final checks remain incomplete. See evidence/ci/release-resume-20261118.md.

## Startup recheck — 2026-11-18 11:48 PST

Storage resolved: 93 GB free, PASS. Local preflight now exits 3 solely for power: battery 14%, discharging, approximately 19 minutes remaining. Connect wall power before regression tests. All 185 locked files still PASS. Apple distribution prerequisites remain deferred and unchanged.

## Restart checkpoint — 2026-11-18

Owner now authorizes finishing and launch ("Let's finihs and get it launched...."). This supersedes the earlier submission/public-release hold, conditional on readiness checks passing. No archive, upload, submission or release was performed in this session.

Fresh local preflight exited 1: 21 GB free vs required 40 GB; wall power absent and battery insufficient for the local exception. Display and on-device model PASS. Protected baseline and all 185 locked files PASS. Per AGENTS startup rule, development/testing stopped; no acceptance criteria were weakened.

Owner action: connect wall power and free at least 19 GB (prefer additional build headroom). Distribution prerequisites also remain locally unset: Apple Distribution and Mac Installer Distribution identities missing; ASC key/issuer/path/team remain placeholders. Confirm EvidencePair LLC conversion and provision the account/key/certificates described in docs/OWNER-RELEASE-SETUP.md. Do not share secrets in chat. Live Apple membership/account status was not verified.

Resume: fresh local preflight and verify_lock, then finish local/signpost-persist regression in /Users/builder/Factory/paperloft-signpost under GUI lock, integrate only after green, and run fresh P6 evidence/independent verification. Full release preflight, remaining supervised/device/purchase checks and final verification must pass before authorized distribution and launch.

# Owner summary — 2026-10-02

**Where things stand:**
- **P3 and P4:** both pass locally with the independent verifier (`evidence/gates/P3.md`, `P4.md`). The verifier's P4 finding, V4-01, is fixed.
- **P6:** every check passes except AC-10, which needs your Terminal run (item 3 below).
- **CI:** full local CI is green on run/1.
- **Nothing has been signed for distribution, archived, uploaded or submitted.**

**What I need from you, most important first:**
1. **Apple membership:** Apple's confirmation of the EvidencePair LLC membership conversion. Then:
   - work through `docs/OWNER-RELEASE-SETUP.md` (identities, the App Store Connect app, products);
   - put the team ID in `config/Distribution.local.xcconfig` (pre-archive checklist below).
2. ~~Confirm the 2026-10-01 amendments and the distribution authorization from your own account.~~ **Done 2026-10-02:** `docs/OWNER-CONFIRMATION.md`, commit `ad6656a`, made through GitHub's web editor from your account (Allerdyce).
3. **AC-10 run from Terminal:** run `scripts/performance_check.sh system`, then `scripts/performance_check.sh parser`, and commit both folders ("Local performance checks" below). After that, `scripts/gate.sh P6 --local` can pass.
   - **2026-10-08:** your 10-02 run was most likely slowed by the Mac, not the code: a bisect found no regression. Current run/1 passes timing, memory and main-thread limits from the agent's shell (system 366.9 s / 366.0 s, parser 23.2 s / 22.9 s; `evidence/performance/AC-10-2026-10-08.md`). Only the signpost is missing, and it needs your Terminal. Run it on a Mac that has been awake for a few minutes with nothing indexing. If the system run misses 400 s anyway, run it once more.
   - **2026-10-09:** your Terminal run passed every limit (364.5 s / 366.3 s; committed as `6fb5232`), but the signpost metric didn't record. A minimal probe outside the app (`build/signpost-probe`) records no signpost from your Terminal either, so this Mac's shells can't collect signpost metrics at all. Your choice: (a) in System Settings › Privacy & Security › Developer Tools, turn on Terminal, then rerun the probe; if a signpost line appears, the app's sandbox is the next thing to check; or (b) amend AC-10's evidence to the XCTest clock and memory metrics plus the test's own timing of the batch, which already pass.
   - **2026-10-09, later:** with `builder` now an admin, signposts are collectable. A one-line Info.plist setting (persist the pipeline signpost) makes the system run pass every AC-10 check, signpost included (branch `local/signpost-persist`, `477711c`). **Blocked on a clear screen:** full CI for that branch failed 7 UI tests because another agent (Codex, Loupe/RedWax in `~/Documents/Codex/…`) runs RedWax UI tests without `~/Factory/.gui.lock`; RedWax's Open panel covered Paperloft. Please pause that agent, or have it use the same lock, while Paperloft CI runs (about 40 minutes).
4. **Decisions in PROPOSALS.md:**
   - ~~StoreKitTest option~~ **Decided 2026-10-02: (a)**, confirmed from your account (`docs/OWNER-CONFIRMATION.md` item 3, `625b2b1`). P5 closes after the shakedown purchase.
   - **Reference-design elements:** your sidebar Settings choice also unblocks the last accessibility audit.
   - **First version, 1.0 or 1.1:** 1.0 unless you say otherwise.
5. **Site:** OK to publish the `paperloft-site` branch `release/receipts-1.0-copy`.
6. **Later, with you present:** the AC-17 persona sessions, and one Import From Device try with a real iPhone or iPad.

The sections below "History" are earlier checkpoints, kept for the record. Where they disagree with this summary, STATUS.md or BUGS.md, those three are current. For example, the App Intents tests and the accessibility audits now pass.

# History: continuation checkpoint, 2026-09-29 (superseded)

The owner requested a credit-saving handoff on2026-09-29. Read **[NEXT-MODEL-HANDOFF.md](NEXT-MODEL-HANDOFF.md)** first; it supersedes historical status below where noted. All jobs stopped and GUI lock is free.

# Local development continues autonomously

P0–P2 local readiness independently passed; accepted files are locked. Resume P3 from STATE.json. No owner action is needed for local development.

Current authorization permits distribution signing, archives and App Store Connect uploads once readiness checks pass; submission and public release remain blocked. Paul team GQ4UA5C6RQ development signing is verified. Full distribution credentials/app/products, supervised shakedown, acceptance baseline and technical readiness still require verification. These are not a request for repeat local-development permission. See docs/DISTRIBUTION-AUTHORIZATION.md.

Recurring wakeup tools are unavailable in this session. Work progresses while this turn is active; persisted state supports resumption after interruption. No background schedule has been created.

## Parked local StoreKit test SDK limitation

Separate branch `local/commerce` at b799b90 contains purchase/quota implementation and strict hosted StoreKit tests. Xcode27 StoreKitTest header SKTestTransaction.h uses deprecated SKPaymentTransactionState and fails warnings-as-errors on import. Standard explicit modules, implicit modules, and earlier test-only deployment target all failed. No suppression is retained. Real StoreKit runtime is not verified; the component has not been merged or accepted asP5. Evidence and integration API are in that branch at evidence/commerce/README.md. Continue independent local work; no owner action requested and release stays blocked.

## Parked App Intents framework discovery

Isolated local/intents at db1a3f3 now includes the production adapter;16direct logic/actual AppModel tests independently pass. Seven genuine AppIntentsTesting tests fail metadata discovery before assertions (error400 app not present). Three distinct runtime approaches failed. Same-team development signing is an unmet documented prerequisite, not a uniquely proven cause. System dispatch/file transport remain unverified, production Pro defaults false pending commerce. No P4 acceptance and no owner action requested.

## Accessibility remains open

All-types audit still FAILS. Independent standalone native reproduction documents system TouchBar/emoji and parent-child findings; native PDF Page description is fixed; native/inactive window contrast remains unresolved. Independent P3 verdict at d17b2bf is FAIL with14findings (evidence/gates/P3.md). No issue filtering, skipped tests or acceptance waiver. Current state is resumable but not a green CI checkpoint; last green is d9454df.

## Mail native promises parked

local/mail at88dc439 preserves the isolated native promise wrapper and public provider harness. Three distinct native drag diagnostics reached the gesture but produced no source MOUSE_DOWN or DRAG_STARTED event; no recipient delivery was established. Window-menu-primed Open Inbox also failed to reopen after closing main. Speculative product fixes were reverted. Saved EML file import is separately integrated; native promises are not accepted or merged. Evidence: that branch's evidence/mail-promises.md and evidence/mail-independent-ui.md.

## Owner action: confirm the 2026-10-01 ACCEPTANCE amendments yourself (done 2026-10-02, `docs/OWNER-CONFIRMATION.md`, commit `ad6656a`)

The P3 verifier (`evidence/gates/P3.md`) passed the AC-13 audit only under the amended wording. It flagged that `acceptance-v1` and the approval notes were all written by the builder identity, so it can't confirm your approval of the AC-10 (400 s) and AC-13 (system-owned findings) amendments.

**How:** don't edit ACCEPTANCE.md or AGENTS.md. `scripts/verify_lock.sh` requires both to stay identical to `acceptance-v1`, so any edit fails every later gate. Instead:
1. Signed in to your own GitHub account, open the repository on github.com and switch to `run/1`.
2. Choose **Add file → Create new file** and name it `docs/OWNER-CONFIRMATION.md`.
3. Confirm both amendments (and the `acceptance-v1` baseline at `770d6db`) and the distribution authorization below.
4. Commit directly to `run/1`.

A web commit carries your account and GitHub's "Verified" signature, which the verifier can tell apart from the unsigned "Paperloft Builder" commits.

Until then the verifier marks the baseline provenance as a flag.

The P4 verifier raised the same point about distribution: `HANDOFF.md` and `docs/DISTRIBUTION-AUTHORIZATION.md` record your authorization for distribution signing, archives and uploads once readiness checks pass, but only in builder-written files, and the frozen AGENTS.md exception still blocks distribution. Please confirm that in the same `docs/OWNER-CONFIRMATION.md` file. Nothing will be archived or uploaded before the membership, the full preflight and your confirmation.

## P6 open item: the Settings page inside the main window isn't audited

`ScreenAuditTests` now audits Help, the menu bar extra, the export sheet and the paywall (all pass). The long Settings page shown from the sidebar scrolls past the window. The audit then measures off-screen text against other pixels and reports contrast failures that aren't real. Whether that page stays at all is your call in PROPOSALS ("Reference-design elements"). My recommendation, the sidebar row opening the real Settings window, would remove the page, and the Settings window's panes are already audited.

## Pre-archive checklist (from the 2026-10-01 release check)

Do these after the EvidencePair LLC membership is confirmed and before the first archive (`evidence/release/2026-10-01-review.md`):
1. **Distribution configuration.** `config/Distribution.xcconfig` is ready (2026-10-02):
   - production bundle IDs
   - the App Group on (`PaperloftShared` entitlements)
   - automatic signing
   - version 1.0

   An unsigned Release build with it compiles with 0 warnings, and both Info.plists say 1.0 with the group enabled. What's left:
   - Put `DEVELOPMENT_TEAM = <LLC team ID>` in `config/Distribution.local.xcconfig` (git-ignored).
   - Archive with `-xcconfig config/Distribution.xcconfig`.
   - Export with `config/ExportOptions-AppStore.plist`. It exports to a folder and never uploads.
   - After archiving, confirm that both the app's and the extension's entitlements include the group.

2. **Version.** The distribution config sets `MARKETING_VERSION = 1.0` (AC-19). If the owner picks 1.1 in PROPOSALS.md, change that one line.
3. **App Store Connect description.** Must include the Terms of Use (Apple standard EULA) and Privacy Policy links; they're in `release/metadata.md`.
4. **Device scan.** Try Import From Device with a real iPhone or iPad once; it has never been tried on hardware.
5. **Privacy check.** Run `scripts/privacy_check.sh <archived app>`. It now also checks the required-reason API declarations.

## Local performance checks

**2026-10-01 update:** AC-10's timing, main-thread and memory limits pass locally under the owner-amended 400 s target (`evidence/performance/AC-10-2026-10-01.md`). System model: 100/100 in 369.2 s / 369.4 s, worst stall 234 / 176 ms, 417 MB. Parser only: 23.2 s / 23.4 s, 209 / 200 ms, 443 MB.

**Owner action:** the signpost metric still can't be collected from the agent's shell, because macOS denies it unified-log access ("Could not open local log store: Operation not permitted"). From Terminal, in an up-to-date run/1 checkout with no local changes, run `scripts/performance_check.sh system` and then `scripts/performance_check.sh parser`, and commit both `evidence/performance/<mode>-<stamp>` folders. Together they take about 15 minutes and use the screen. Each folder records the commit it measured. `scripts/performance_evidence_check.py`, which `scripts/gate.sh P6` runs, accepts a run only if it measured the current app sources. If the signpost still doesn't appear there, it's an XCTest collector limitation to note for the verifier. The older notes below are history.


Fresh parser runs after independently reviewed row rendering repair completed and persisted100/100 in16.408/16.436s, peak447.32/452.13MB, maximum heartbeat177.28/224.93ms: direct limits passed. Fresh system run on0823af2 completed and persisted100/100 with exact system backend100, no failed items and no prior records;358.972s FAILS240s, while414.50MB and222.74ms satisfy their limits. No repeat is planned without a justified repair. Required signpost data remains unavailable; a separate minimal native Instruments recorder failed with a corrupt/incomplete-log-archive error. AC10 is not passed. Raw bundles remain in local/performance build/; committed evidence is on that branch.

## Integrated watcher and startup safety

Reviewed watcher/startup integration merged at1d1bff7, preserving root row repair. Independent scoped source/model checks, native folder grant/restart/background intake and original navigation passed (evidence/watched-folder/selective-independent-review.md). Production Pro defaults false pending commerce; watched EML acknowledgement remains deferred. Combined root regression:83core tests,8functionalUI tests and strictRelease pass; accessibility remainsFAIL with14findings. Evidence: evidence/watched-folder/root-integration.md. No whole phase acceptance.

## Native icon assembly prerequisite

Icon Composer opens successfully but requires first-use Icon Composer Agreement EA1954 dated4/16/2025. AGENTS.md says never accept agreements, so none was accepted and no bypass attempted. The app is /Applications/Xcode.app/Contents/Applications/Icon Composer.app. Owner acceptance is required before future native icon assembly; no immediate action is requested while independent code work continues. Four rendered/visually checked SVG draft layers and owner source are preserved on local/icon at723f71c. Actual.icon package, build integration and16/32/128px review remain incomplete.

## Native Computer Use review blocked

Current QA app selection/screenshot worked, but the first Settings click returned “Sky Computer Use native pipe closed before response”. Partial independent critique: evidence/design/2026-09-27-critique.md. Only visible dark review design was scored4/5; all unobserved screen/appearance/keyboard/persona checks remain unverified. No repeat/bypass, no product defect inferred from the bridge failure. Automated UI tests remain operational.

## Rejected isolated classifier-prewarm experiment

Candidate ed8b84e passed43 optimized core tests and the frozen150-document system accuracy evaluation. Parent independently compared parsed predictions: all150 exactly equal accepted baseline, including16classification fallbacks. One fresh system timing attempt then completed/persisted80/100 withsystem80 at360.001s cutoff, versus baseline100/100 in358.972s. One Foundation Models error was recorded. Peak439.63MB/max heartbeat220.70ms are observations; later assertions were not reached after fail-fast. No speed benefit established, no causal slowdown conclusion. Candidate source is restored exactly at local/performance1a7309c (parent verified empty Extraction.swift diff against1eff99b); root never received it. Accuracy/timing evidence is retained there. No blind rerun.

Current root menu-bar Open Inbox independently passes on reviewed product13db8a4, now regression test in daef890; see evidence/menu-reopen/README.md. This does not clear native Mail wrapper failures.

## Restart recovery and owner amendment —2026-09-27

Owner restarted ChatGPT and opened Icon Composer. Root verified New Document click, Cmd+S opening the native save sheet, then Cancel after refreshing the app binding. No agreement screen remains; native icon assembly resumed on local/icon. This clears the previous first-use prerequisite for this app, not every native bridge interaction. Owner explicitly authorized future Apple agreements; scoped standing exception is recorded in AGENTS.md at9ad4c75. Existing release/upload/account/payment restrictions remain. Design review resumes when GUI is available.

## Native icon integrated; first-use blocker cleared

Owner restart cleared the agreement screen; standing Apple agreement exception recorded at9ad4c75. Native four-layer icon fromdaf145d now integrated into root with three buildsettings only. Root strictRelease/compiledicon/CFBundleIconName/protectedbaselinePASS. Independentcritic accepted faithful localreconstruction;16pxtraycontrast still3/5 and background checks incomplete. Translucency-only experiment was independently rejected and reverted exactly; evidence retained. PROPOSALS.md records minimalcontrastoption without alteringownerartwork. MainPaperloft QA selection stillfailsnativepipe even thoughIconComposer controlswork; fullpersona/designchecks remainblocked. No additionalpermissions inferred missing fromthisfailure.

## 1.1 live device checks
Local signed Share extension builds and registers, but Finder Share displayed “Unlock Mac to continue with Siri request”; dismissed without changing settings. When the Mac is unlocked, retry a synthetic PDF through Finder > Share > Paperloft. Actual iPhone/iPad scan and Photos/Preview sharing remain unverified. No release authorization requested or assumed.

## 2026-09-29 — Resume blocked by missing display

Owner requested continuing 1.1. Local preflight returned 38 PASS, 1 WARN, 1 FAIL, 0 TFAIL, 15 MANUAL. The sole FAIL is no detected display. Independent `system_profiler SPDisplaysDataType` lists the M1 Pro GPU but no display or resolution. Evidence: build/intake11-resume-preflight.log. Protected baseline and existing lock hashes passed: build/intake11-resume-baseline.log.

AGENTS.md section 2 requires stopping on preflight exit 1. No product changes or new test-pass claims. Owner action: connect/wake the display (or connect an HDMI display emulator); if using the laptop display, open the lid. Then rerun local preflight and resume Mail candidate/rendering and remaining 1.1 verification. Release/uploads remain blocked.

2026-09-29 retry: display blocker CLEARED. Built-in Color LCD online at 3456x2234; local preflight 39 PASS, 1 WARN, 0 FAIL, 0 TFAIL (15 manual checks remain). Evidence: build/intake11-retry-preflight.log. Local development allowed; distribution/upload/release remain blocked.

2026-09-29 authorization update: distribution signing, archives and App Store Connect uploads are now owner-authorized once readiness checks pass. Submission and public release remain blocked. Earlier blanket distribution restrictions are superseded; see docs/DISTRIBUTION-AUTHORIZATION.md.

## 2026-09-29 current 1.1 handoff

Native attachment and HTML-body import/relaunch/removal pass (build/Intake11MailNativeFallback.xcresult); signed development Release/signature/privacy/baseline pass. Sandbox WebKit termination is repaired through a tested native text-PDF fallback, with implementation deviation documented. Root MailFieldHints keeps header suggestions in review. Message-ID ledger is implemented and independently reviewed; wire it only with durable Inbox proofs, startup replay, returned-delivery conflict handling and explicit partial-failure retry policy. No archive/upload yet because full readiness is incomplete, not because authorization is missing.

2026-09-29 live Share retry: the signed development extension is registered at build/Intake11Signed/Build/Products/Release/Paperloft Receipts.app/Contents/PlugIns/PaperloftShare.appex. Finder's Share menu omits Paperloft because System Settings → General → Login Items & Extensions → Sharing shows Paperloft Receipts switched off. No settings changed. Owner permission to enable this specific switch is pending under AGENTS.md's System Settings restriction; duplicate recovery and other local development continue independently.
