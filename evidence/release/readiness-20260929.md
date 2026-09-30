# Release readiness check — 2026-09-29

**Verdict: NO-GO.** The conditional authorization (docs/DISTRIBUTION-AUTHORIZATION.md) does **not** apply, so no distribution signing, archives or App Store Connect uploads were performed. Submission and public release remain prohibited regardless.

## Formal release checks (run on run/1 at ee39333)

| Check | Result | Log |
|---|---|---|
| `scripts/preflight_check.sh --log` (full, no `--local`) | **NO-GO**: 41 PASS, 1 WARN, **10 FAIL**, 0 TFAIL, 5 MANUAL | build/release-preflight-20260929.log |
| `scripts/verify_lock.sh` | **FAIL**: tag `acceptance-v1` is missing | build/release-verify-lock-20260929.log |

### Owner-only blockers from preflight (need the organization membership / DUNS)

1. **Apple Distribution** and **Mac Installer Distribution** signing identities are missing. Create them in Xcode › Settings › Accounts › Manage Certificates for the EvidencePair LLC team.
2. **App Store Connect API key:** `~/Factory/.secrets/asc.env` still has the example `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` and `TEAM_ID`, and there's no `.p8` key file. Create an ASC API key (App Manager role or higher), save the `.p8`, and fill in `asc.env`. Never paste secrets in chat.
3. **Team ID:** set `TEAM_ID` to the organization team once enrolled. The paid development team used locally (GQ4UA5C6RQ) is for development signing only.
4. **`acceptance-v1` tag:** per AGENTS.md this is created at the full supervised shakedown, after the acceptance baseline is established. It isn't something the agent creates unilaterally.
5. **Manual confirmations:** Focus/DND; Codex/Computer Use settings; GitHub rulesets; Paid Apps Agreement and Small Business Program (5 MANUAL items).
6. WARN: `pmset autorestart` is unset (needs sudo; owner's choice).

## Acceptance criteria status (local evidence; no formal gate is claimed without the verifier)

| AC | Status | Evidence / gap |
|---|---|---|
| 01 build, zero warnings | Local PASS | Strict signed Release builds today with 0 warnings (followups, a11y, classifier branches); clean-clone verifier rerun pending |
| 02 unit tests, coverage ≥ 75% | Tests PASS; coverage not re-measured | 123 XCTest + 114 Swift Testing pass (build/classifier/unit2.log); coverage last verified at P2 |
| 03 system fixtures | **PASS** | eval c944adf: date 100, total 99.26, vendor 97.78, kind 99.33, category 100 (eval-history.csv) |
| 04 holdout | Pending verifier | The verifier generates a fresh holdout; not re-run |
| 05 parser | PASS (last run) | eval-history 2026-09-26: date 1.0000, total 0.9926 |
| 06 private samples | Not gated | Owner receipt reruns reported separately |
| 07/08 file safety, crash recovery | PASS at P2; tests pass in CI | Full CI 2026-09-29 |
| 09 resilience | Tests pass; P6 gate not run | ResilienceTests in unit suite |
| 10 throughput | **FAIL** | 100 documents in 358.972 s against ≤ 240 s; signpost capture unavailable |
| 11 UI and purchase flows | **Blocked** | StoreKitTest strict import blocked (SDK header); real products need DUNS/membership |
| 12 accountant pack | Tests pass; P4 gate not run | ExportTests |
| 13 accessibility | **FAIL** | App-owned findings cleared; 10 system Touch Bar/emoji/unattributed findings pending the PROPOSALS decision |
| 14 privacy | **PASS** | privacy_check.sh PASS on today's signed Release builds |
| 15 App Intents | Local PASS | AppIntentsTesting 7/7 (evidence/intents-signed/data-backed-export.md); formal P4 gate not run |
| 16 design critic ≥ 4/5 | **Open** | Icon at 16 px scored 3/5 (evidence/design/2026-09-27-critique.md) |
| 17 QA personas, zero P0/P1 | **Not done** | No evidence/qa yet |
| 18 release checker, screenshots, site | **Not done** | Needs final UI and site pass (P8) |
| 19 build uploaded and processed | **Blocked** | Credentials and identities missing (above) |
| 20 README, PRIVACY, SUPPORT, Help | **Incomplete** | README.md exists; PRIVACY.md, SUPPORT.md and the in-app Help page are missing (Help must include the 100 MB Shortcuts limit, NOTES.md) |
| 21 final verification | **Not done** | Requires AC-01…20 PASS |

## Agent-actionable next work (no owner input needed)

- AC-20: write PRIVACY.md and SUPPORT.md (10 FAQs), and add an in-app Help page.
- AC-10: throughput investigation (bounded; signposts need a different capture approach).
- AC-17: QA persona sessions on the QA build; AC-16: design critique rerun and the icon contrast proposal.
- CI hygiene: `ci.sh` should flag only compiler warnings, not XCTest runtime notices.
