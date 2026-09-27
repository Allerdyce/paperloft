#!/bin/bash
# Local AC-10 diagnostic; no archive/upload or acceptance-gate substitution.
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-}"
case "$mode" in
  parser) scheme=PaperloftPerformanceParser ;;
  system) scheme=PaperloftPerformanceSystem ;;
  *) echo "Usage: scripts/performance_check.sh parser|system" >&2; exit 2 ;;
esac
lock=/Users/builder/Factory/.gui.lock
if ! mkdir "$lock" 2>/dev/null; then
  echo "GUI is in use. Wait for its owner before running performance measurements." >&2
  exit 3
fi
printf 'performance %s %s\n' "$mode" "$(date -u +%FT%TZ)" > "$lock/owner"
trap 'rm "$lock/owner"; rmdir "$lock"' EXIT
stamp=$(date -u +%Y%m%dT%H%M%SZ)
output="evidence/performance/$mode-$stamp"
mkdir -p "$output" build
scripts/preflight_check.sh --local --log > "$output/preflight.log"
scripts/verify_local_baseline.sh > "$output/baseline.log"
swift scripts/generate_performance_inputs.swift > "$output/fixture-generation.log"
result="build/Performance-$mode-$stamp.xcresult"
set +e
xcodebuild -project Paperloft.xcodeproj -scheme "$scheme" -destination 'platform=macOS' \
  -derivedDataPath build/PerformanceDerivedData -configuration QA ENABLE_TESTABILITY=YES \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -parallel-testing-enabled NO \
  -resultBundlePath "$result" test 2>&1 | tee "$output/test.log"
status=${PIPESTATUS[0]}
set -e
printf '%s\n' "$result" > "$output/result-path.txt"
python3 - "$output/test.log" "$output/iterations.json" <<'PY'
import json, pathlib, sys
prefix = "PAPERLOFT_PERFORMANCE "
rows = []
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    if prefix in line:
        rows.append(json.loads(line.split(prefix, 1)[1]))
pathlib.Path(sys.argv[2]).write_text(json.dumps(rows, indent=2) + "\n")
print(f"Captured {len(rows)} pipeline reports. XCTest result remains authoritative.")
PY
xcrun xcresulttool get test-results metrics --path "$result" > "$output/metrics.json"
if ! python3 - "$output/metrics.json" <<'PYMETRICS'
import json, pathlib, sys
rows = json.loads(pathlib.Path(sys.argv[1]).read_text())
metrics = [metric for row in rows for run in row.get("testRuns", []) for metric in run.get("metrics", [])]
print("Recorded XCTest metrics: " + ", ".join(metric["displayName"] for metric in metrics))
required = ["Clock", "Memory Peak", "UnderstandInboxBatch"]
missing = [name for name in required if not any(name in metric.get("displayName", "") or name in metric.get("identifier", "") for metric in metrics)]
if missing:
    print("FAIL: required metric evidence missing: " + ", ".join(missing))
    sys.exit(1)
PYMETRICS
then status=1; fi
if rg '(^|[[:space:]])warning:' "$output/test.log"; then status=1; fi
printf 'Local diagnostic exit %s; evidence: %s\n' "$status" "$output"
exit "$status"
