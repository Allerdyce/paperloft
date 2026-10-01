# Release preflight and acceptance baseline (2026-10-01)

## Acceptance baseline
- **Owner decisions:** Ali approved the three proposals in chat:
  - AC-10: 400 s per 100 documents
  - AC-13: findings on system-owned elements are excused
  - icon tray contrast: #357C51
- **ACCEPTANCE.md:** amended before tagging, with the decisions recorded in its "Owner-approved amendments (2026-10-01)" section.
- **CI:** first fully green `scripts/ci.sh` (exit 0) on the branch:
  - 166 tests passed, 0 failures, 0 crashes, no warnings
  - the accessibility audit passes, with exactly the 10 known system-owned findings excused and attached
- **Tag:** `acceptance-v1` is annotated on `770d6db` (the run/1 merge of those changes) and pushed to origin.
- **Lock check:** `scripts/verify_lock.sh` passes 17/17, exit 0 (`build/verify-lock-20261001.log`).

## GitHub rulesets (set by the agent in the app's browser; the owner signed in)
- **Protect branches** (id 24324888): Active, all branches, restrict deletions, block force pushes.
- **Protect acceptance tags** (id 24325087): Active, `acceptance-*` and `p*-done`, restrict updates, restrict deletions, block force pushes. Creations are allowed.

## Full preflight (`scripts/preflight_check.sh --log`, no `--local`)
- **Result:** 42 PASS, 1 WARN, 9 FAIL, 0 TFAIL, 5 MANUAL (`evidence/preflight-latest.txt`).
- **Change since 09-29:** the `acceptance-v1` FAIL is gone (was 10 FAIL).
- **All 9 FAILs wait on the EvidencePair LLC membership** (owner guide steps 2–4):
  - no Apple Distribution identity
  - no Mac Installer Distribution identity
  - four example values in `asc.env`
  - no API key file
  - no signing identity for the team
  - the App Store Connect check failed
- **WARN:** `pmset autorestart` is unset. It's optional and needs `sudo`, so it's the owner's to run.

**Manual items**

| Item | Status |
| --- | --- |
| Focus: Do Not Disturb on, always, nothing allowed | Owner confirmed, 2026-10-01 |
| Screen Recording and Accessibility granted | Owner confirmed, 2026-10-01 |
| Agent app settings | Keep-awake is on. Notifications stay on for this owner-present run, so flags reach the owner. The item is worded for Codex. |
| GitHub rulesets | Done (above) |
| App Store Connect: Paid Apps Agreement, Small Business Program | Waits on the membership |

**Verdict:** still NO-GO for distribution, and only Apple-dependent items remain. Submission and public release stay blocked until the owner says otherwise.
