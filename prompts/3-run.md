/goal Build Paperloft Receipts to submission-ready by following AGENTS.md exactly.

Done means all of these are true and pushed to origin:
- evidence/gates/final.md, written by the verifier subagent, ends with "GATE final: PASS" and covers AC-01 to AC-21 in ACCEPTANCE.md.
- Version 1.0 is uploaded and processed in App Store Connect (evidence/asc-build.json).
- REPORT.md, STATUS.md and FACTORY_NOTES.md are written, and HANDOFF.md lists anything parked.

Start with scripts/preflight_check.sh --log and scripts/verify_lock.sh, then resume from STATE.json (create it in P0 if missing). Work phase by phase from SPEC.md section 8, on branch run/1; the verifier decides every gate. Nobody is watching: never ask me a question, park it in HANDOFF.md and continue with unblocked work. Never press Submit for Review and never change ACCEPTANCE.md.
