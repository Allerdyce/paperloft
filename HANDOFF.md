# Latest continuation checkpoint

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

## Owner action: confirm the 2026-10-01 ACCEPTANCE amendments yourself

The P3 verifier (`evidence/gates/P3.md`) passed the AC-13 audit only under the amended wording. It flagged that `acceptance-v1` and the approval notes were all written by the builder identity, so it can't confirm your approval of the AC-10 (400 s) and AC-13 (system-owned findings) amendments. Please confirm them in a way the verifier can see as yours, for example:
- a short commit from your own account adding a line such as "Ali confirms the 2026-10-01 AC-10 and AC-13 amendments" under "Owner-approved amendments" in ACCEPTANCE.md, or
- a GitHub comment on that commit.

Until then the verifier marks the baseline provenance as a flag.

The P4 verifier raised the same point about distribution: `HANDOFF.md` and `docs/DISTRIBUTION-AUTHORIZATION.md` record your authorization for distribution signing, archives and uploads once readiness checks pass, but only in builder-written files, and the frozen AGENTS.md exception still blocks distribution. Please confirm that too, in the same way. Nothing will be archived or uploaded before the membership, the full preflight and your confirmation.

## P6 open item: the Settings page inside the main window isn't audited

`ScreenAuditTests` now audits Help, the menu bar extra, the export sheet and the paywall (all pass). The long Settings page shown from the sidebar scrolls past the window. The audit then measures off-screen text against other pixels and reports contrast failures that aren't real. Whether that page stays at all is your call in PROPOSALS ("Reference-design elements"). My recommendation, the sidebar row opening the real Settings window, would remove the page, and the Settings window's panes are already audited.

## Pre-archive checklist (from the 2026-10-01 release check)

Do these after the EvidencePair LLC membership is confirmed and before the first archive (`evidence/release/2026-10-01-review.md`):
1. **Distribution configuration.** Add `config/Distribution.xcconfig`:
   - production bundle IDs (`app.paperloft.receipts`, `.share`)
   - `PAPERLOFT_APP_GROUP_ENTITLEMENTS_SUFFIX = Shared` and `PAPERLOFT_APP_GROUP_ENABLED = YES`
   - distribution signing for the LLC team

   Without it, the App Group is off and Finder sharing says "Sharing needs a signed Paperloft build". After archiving, confirm that both the app's and the extension's entitlements include the group.
2. **Version.** `MARKETING_VERSION` follows the owner's choice in PROPOSALS.md; it's 1.0 per AC-19 unless the owner picks 1.1.
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
