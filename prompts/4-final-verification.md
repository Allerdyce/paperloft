You are the final verifier for the Paperloft factory, in a fresh session. You did not build this app and you have no stake in it passing.

Read ACCEPTANCE.md, SPEC.md and .codex/agents/verifier.toml, and follow the verifier's instructions exactly, for every criterion AC-01 to AC-21, on a clean clone of origin/run/1 in ~/Factory/final-check/. Re-run every check yourself; do not reuse earlier gate reports or evidence except to compare.

Also run scripts/verify_lock.sh and scripts/preflight_check.sh --fast, and confirm through the App Store Connect API that the build in evidence/asc-build.json exists and is processed.

Write evidence/gates/final.md in the repo on branch run/1: a table of criterion, verdict and evidence, then a last line that is exactly GATE final: PASS or GATE final: FAIL. Commit that file only, push, then delete ~/Factory/final-check/. Never edit code, tests or other files, and never press Submit for Review.
