# P2 local readiness self-check

- `scripts/preflight_check.sh --local --log`: exit 0
- `scripts/verify_local_baseline.sh`: exit 0
- `scripts/ci.sh`: exit 0
- `scripts/privacy_check.sh`: exit 0
- `python3 scripts/coverage_check.py`: exit 0
- `python3 scripts/crash_recovery_test.py`: exit 0
- `scripts/eval.sh --model parser`: exit 0
- `scripts/eval.sh --model system`: exit 0
- `scripts/eval.sh --private`: exit 0
- Source integrity: PASS

LOCAL CHECKS: PASS
Independent verifier decision required. Local readiness never closes a formal gate.
AC-04 requires the independent verifier's fresh60-document holdout run. The builder never reads or scores it directly. P1 fixture difficulty was decided before locking; P2 uses the frozen accuracy thresholds on the unchanged corpus.
