# Local gate pre-checks (2026-10-01)

These are the agent's own pre-checks. They don't replace the independent verifier, whose reports decide each gate. All were run on `run/1` after the Paperloft Pro merge (`3d5348b`) unless noted.

| AC | Result | Evidence |
| --- | --- | --- |
| AC-01: fresh clone builds with zero warnings | **Pre-check PASS** | `git clone` of run/1 at `3d5348b` into a clean folder. Debug and Release `xcodebuild … SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build` both exit 0, with 0 warnings and 0 errors. |
| AC-02: unit tests pass; PaperloftKit coverage ≥ 75% | **Pre-check PASS** | `ci.sh` green. PaperloftKit line coverage is **95.06%** (2846/2994) over the whole target (`xccov` on the 2026-10-01 green CI result). |
| AC-03: system model on the 150 fixtures | **PASS** | `scripts/eval.sh --model system` at `3d5348b`: date 100.00%, total 99.26%, vendor 97.78%, kind 99.33%, category 100.00%, with 4 refusal fallbacks. These are identical to the previous run (`evidence/eval-history.csv`). |
| AC-05: parser alone, date and total ≥ 90% | **PASS** | `scripts/eval.sh --model parser`: date 99.26%, total 99.26%. The frozen scorer also prints the P1 difficulty diagnostic (parser total above 98%). The P2 verifier already accepted that: the fixture set passed difficulty when it was locked at P1, and the parser improved later. |
| AC-11: UI and purchase flows | **Local PASS, with one owner decision open** | PaywallFlowTests covers the paywall at document 26, buy yearly, buy lifetime, restore, expiry back to Free, and the export paywall, using the Debug/QA mock store. CommerceModelTests covers the model. StoreKitTest unit tests remain blocked by Apple's deprecated header (PROPOSALS.md). |
| AC-13: accessibility audit | **PASS** under the 2026-10-01 amendment | Only the 10 system-owned findings are excused, and each is attached as evidence. |
| AC-18: release materials | **Drafts ready** | `release/metadata.md`, plus five 2880 × 1800 screenshots and the paywall review image in `release/screenshots/`. The site changes are on the local `paperloft-site` branch `release/receipts-1.0-copy`, not published. App Store Connect entry waits on the membership. |
| AC-20: docs | **Kept current** | Help has a new "Free and Pro" topic, and SUPPORT FAQs 3 and 9 cover Free and Pro. |

Still open: AC-04 (the verifier's fresh holdout), AC-10's formal measurement under the new 400 s target, AC-16 and AC-17 (critic and personas), AC-19 (upload, after the membership), and AC-21.
