# Paperloft factory kit

Everything the second Mac needs before the agent starts. `SPEC.md` is the full spec; its section 3 is the setup checklist and section 4 the shakedown.

## What's here

| Path | Purpose |
| --- | --- |
| `SPEC.md` | The spec: decision, setup, run contract, product, acceptance, phases, verification |
| `AGENTS.md` | The run contract Codex reads at the start of every session |
| `ACCEPTANCE.md` | The 21 criteria. Frozen once you tag `acceptance-v1` |
| `ACCEPTANCE.lock` | Empty. The agent appends hashes of approved tests and fixtures; it can only grow |
| `.codex/agents/*.toml` | The four checkers: verifier, qa_explorer, critic, release_checker (all frozen) |
| `.codex/config.toml` | Project config (subagent limits) |
| `codex/config.user.toml` | Copy to `/Users/builder/.codex/config.toml` |
| `scripts/preflight_check.sh` | Read-only doctor; no line may say FAIL before a run |
| `scripts/asc_ping.swift`, `scripts/fm_check.swift` | App Store Connect and Apple Intelligence checks used by the doctor |
| `scripts/verify_lock.sh`, `scripts/lock_add.sh` | Keep the acceptance bar from moving (frozen) |
| `scripts/score_eval.py` | The only extraction scorer; thresholds for AC-03 to AC-06 (frozen) |
| `prompts/1-shakedown.md`, `prompts/2-shakedown-after-reboot.md`, `prompts/3-run.md` | Paste these into Codex, in order |
| `prompts/4-final-verification.md` | Started by the agent as a fresh scheduled session for the final gate |
| `asc.env.example` | Template for `~/Factory/.secrets/asc.env` |
| `design/app-icon-source.png` | Ali's app icon artwork; the agent rebuilds it in Icon Composer (SPEC.md 6.5) |

## Install (as `builder`, after SPEC.md 3.1 to 3.4 and the SSH steps in 3.5)

```sh
cd ~/Factory && git clone git@github-paperloft:<owner>/paperloft.git && cd paperloft
unzip ~/Downloads/paperloft-factory-kit.zip -d /tmp/kit && cp -R /tmp/kit/paperloft-factory-kit/. .
chmod +x scripts/*.sh
mkdir -p ~/.codex && cp codex/config.user.toml ~/.codex/config.toml
mkdir -p ../.secrets && chmod 700 ../.secrets
[ -f ../.secrets/asc.env ] || cp asc.env.example ../.secrets/asc.env; chmod 600 ../.secrets/asc.env   # fill it in if new
git add -A && git commit -m "Factory kit"
git tag acceptance-v1 && git push origin main acceptance-v1
scripts/preflight_check.sh
```

Before any of this, buy paperloft.app and point it at GitHub Pages (SPEC.md 3.5). Then in GitHub, add rulesets (a private repo needs GitHub Pro): block force-pushes and deletion on all branches, and block updates and deletion of tags matching `acceptance-*` and `p*-done`.
