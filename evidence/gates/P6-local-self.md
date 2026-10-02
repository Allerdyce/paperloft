# P6 local readiness self-check

- `scripts/preflight_check.sh --local --log`: exit 0
- `scripts/verify_local_baseline.sh`: exit 0
- `scripts/ci.sh`: exit 0
- `scripts/privacy_check.sh`: exit 0
- `scripts/build_qa.sh`: exit 0
- `python3 scripts/coverage_check.py`: exit 0
- `python3 scripts/performance_evidence_check.py`: exit 1
- Source integrity: PASS

LOCAL CHECKS: FAIL
Independent verifier decision required. Local readiness never closes a formal gate.
AC-09: ResilienceTests (in CI). AC-13: the audits in CoreFlowTests and ScreenAuditTests (in CI). AC-14: scripts/privacy_check.sh. AC-10: scripts/performance_evidence_check.py on the newest committed evidence/performance runs.
