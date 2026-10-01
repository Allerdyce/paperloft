# ACCEPTANCE.md: Paperloft Receipts v1

Frozen at tag `acceptance-v1`. The run is done when the verifier's `evidence/gates/final.md` shows all 21 criteria as PASS, each with evidence it produced itself. Only Ali changes this file, by re-tagging.

| ID | Criterion | Verified by | Closes in |
| --- | --- | --- | --- |
| AC-01 | A fresh clone builds Debug and Release with zero errors and zero warnings under Swift 6 strict concurrency | Verifier's raw `xcodebuild` with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` on a clean clone | P0, re-checked every gate |
| AC-02 | All unit tests pass; `PaperloftKit` line coverage is 75% or more, measured over whole targets | `xcodebuild test` plus `xccov` | P2 |
| AC-03 | System model on the 150-document fixture set: date ≥ 97%, total ≥ 97%, vendor ≥ 92%, kind ≥ 95%, category ≥ 80% | `scripts/eval.sh --model system`, scored by `scripts/score_eval.py --mode fixtures` | P2 |
| AC-04 | The AC-03 thresholds minus 3 points on the verifier's 60-document holdout | Verifier runs `scripts/eval.sh --holdout` on freshly generated documents (`score_eval.py --mode holdout`) | P2 |
| AC-05 | Deterministic parser alone: date ≥ 90% and total ≥ 90% on the fixture set | `scripts/eval.sh --model parser` (`score_eval.py --mode parser`) | P2 |
| AC-06 | Real receipts in `~/Factory/private-samples/`, if any: scores reported, not gated | Eval report | P2 |
| AC-07 | 1,000 randomized file operations: nothing overwritten or deleted; originals byte-identical in copy mode; undo restores every path and hash | Property tests | P2 |
| AC-08 | App killed mid-batch: on relaunch no file is lost or duplicated, and the journal completes or rolls back | Integration test with a forced kill | P2 |
| AC-09 | Empty file, corrupt PDF, locked PDF, 50-megapixel image, 200-page PDF, non-receipt, missing library, stale bookmark: each gets a clear message, no crash, no hang | `ResilienceTests` | P6 |
| AC-10 | 100 mixed documents understood in ≤ 400 s with the system model (≤ 30 s parser-only); no main-thread hang over 250 ms; peak memory under 600 MB | XCTest metrics and signposts | P6 |
| AC-11 | UI flows with the stub model: samples to first filed document, keyboard-only review, edit, undo, search, export, paywall at document 26, buy yearly, buy lifetime, restore, expiry back to Free | XCUITest suite plus StoreKit tests | P3 and P5 |
| AC-12 | Accountant pack: CSV parses cleanly; row count matches the range; category totals match to the cent; `summary.pdf` opens and agrees with the CSV; every listed file exists | `ExportTests` | P4 |
| AC-13 | Accessibility audit passes on every main screen, except findings on system-owned elements the app doesn't create (Touch Bar items, the emoji & symbols popup, unattributed issues) that a minimal non-Paperloft app reproduces; every control reachable by keyboard and labelled for VoiceOver | UI tests with `performAccessibilityAudit()` | P6 |
| AC-14 | No outgoing network entitlement (or an exception documented in `REPORT.md`); Apple frameworks only per `otool -L`; no `Package.resolved`; privacy manifest present | `scripts/privacy_check.sh` | P6 |
| AC-15 | Every App Intent passes App Intents Testing framework tests | Intent tests | P4 |
| AC-16 | `critic` scores 4 of 5 or better on every rubric line for every main screen | `evidence/design/` critique with screenshots | P7 |
| AC-17 | `qa_explorer` completes four persona sessions on the QA build; zero open P0 or P1 bugs | `evidence/qa/` summary and `BUGS.md` | P7 |
| AC-18 | `release_checker` finds no App Review blockers; metadata complete; five 2880 x 1800 screenshots; privacy and support URLs on `SITE_DOMAIN` (paperloft.app) return HTTP 200; the copyright field, Info.plist copyright, privacy policy and site footer all name `LEGAL_ENTITY` (EvidencePair LLC) | `evidence/release/` review | P8 |
| AC-19 | Build 1.0 archived, exported, uploaded and shown as processed through the App Store Connect API; in-app purchase metadata complete | API response saved to `evidence/asc-build.json` | P8 |
| AC-20 | `README.md` with build and test commands, `PRIVACY.md`, `SUPPORT.md` with 10 FAQs, and an in-app Help page | Verifier | P8 |
| AC-21 | The verifier's final report lists AC-01 to AC-20 as PASS, each with an evidence link | `evidence/gates/final.md` | P8 |

## Bug severity

- **P0:** data loss, crash, can't file, purchase broken.
- **P1:** a silently wrong result, a blocked main flow, an accessibility blocker.
- **P2:** everything cosmetic.

## Fixture rules (P1)

The builder writes a generator that renders receipts with ground-truth labels: at least 12 layouts and 40 vendors, with thermal-print styling, rotation, blur, compression and perspective. The 150-document set must be at least 30% photographed-style, 20% long itemized receipts, 10% non-receipts, and 10% with confusable totals (subtotal, tax, tip).

`scripts/score_eval.py` (frozen) enforces the mix and the minimum sizes, and reports the difficulty check: the verifier rejects the set if the parser alone scores above 98% on totals. Once accepted, the fixtures and their labels are added to `ACCEPTANCE.lock` and never change. The holdout comes from the verifier's own generator, with layouts and vendors the builder has never seen. The verifier renders a fresh 60-document set with a new seed at each scoring, and only totals are ever written down.

## Evidence

Every PASS names its evidence: the command and exit code, test IDs, `.xcresult` path, eval scores, screenshot paths, or API responses. A criterion with no evidence is a FAIL.

## Owner-approved amendments (2026-10-01)

Ali approved these in chat on 2026-10-01, before the `acceptance-v1` tag was created. Evidence and options are in `PROPOSALS.md`.
- **AC-10:** the system-model target is 400 s per 100 documents (was 240 s). On-device model speed sets the floor; scheduling changes were measured and don't close the gap.
- **AC-13:** audit findings on system-owned elements the app doesn't create (Touch Bar items, the emoji & symbols popup, issues XCTest attributes to no element) don't count against "passes", provided a minimal non-Paperloft app reproduces them. Every finding on an app element still fails the audit.

