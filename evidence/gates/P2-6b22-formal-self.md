# P2 formal self-check

- `scripts/preflight_check.sh --log`: exit 1
- Source integrity: PASS

SELF-CHECK: FAIL
Independent verifier decision required. Local readiness never closes a formal gate.
AC-04 requires the independent verifier's fresh60-document holdout run. The builder never reads or scores it directly. P1 fixture difficulty was decided before locking; P2 uses the frozen accuracy thresholds on the unchanged corpus.
