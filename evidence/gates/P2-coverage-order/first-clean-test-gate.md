# P2 local readiness self-check

- `scripts/preflight_check.sh --local --log`: exit 0
- `scripts/verify_local_baseline.sh`: exit 0
- `scripts/ci.sh`: exit 0
- `scripts/privacy_check.sh`: exit 1
- Source integrity: PASS

LOCAL CHECKS: FAIL
Independent verifier decision required. Local readiness never closes a formal gate.
AC-04 requires the independent verifier's fresh60-document holdout run. The builder never reads or scores it directly. P1 fixture difficulty was decided before locking; P2 uses the frozen accuracy thresholds on the unchanged corpus.
