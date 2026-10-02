# P4 local readiness self-check

- `scripts/preflight_check.sh --local --log`: exit 0
- `scripts/verify_local_baseline.sh`: exit 0
- `scripts/ci.sh`: exit 0
- `scripts/privacy_check.sh`: exit 0
- `scripts/build_qa.sh`: exit 0
- `python3 scripts/coverage_check.py`: exit 0
- Source integrity: PASS

LOCAL CHECKS: PASS
Independent verifier decision required. Local readiness never closes a formal gate.
AC-15's App Intents framework tests ran with signing: config/PaulDevelopment.xcconfig.
