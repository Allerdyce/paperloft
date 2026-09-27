# P1 local readiness self-check

- `scripts/preflight_check.sh --local --log`: exit 0
- `scripts/verify_local_baseline.sh`: exit 0
- `scripts/ci.sh`: exit 0
- `scripts/privacy_check.sh`: exit 0
- `python3 scripts/check_fixture_set.py`: exit 0
- `scripts/eval.sh --model parser (P1 pipeline/mix/difficulty only; P2 accuracy remains gated later)`: exit 1
- `scripts/eval.sh --model system (P1 pipeline/mix/difficulty only; P2 accuracy remains gated later)`: exit 1
- Source integrity: PASS

LOCAL CHECKS: PASS
Independent verifier decision required. Local readiness never closes a formal gate.
