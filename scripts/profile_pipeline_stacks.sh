#!/bin/bash
# Intrusive stack diagnostic only: NEVER use this run as AC-10 timing evidence.
set -euo pipefail
cd "$(dirname "$0")/.."
stamp=$(date -u +%Y%m%dT%H%M%SZ)
output="evidence/pipeline-stacks-$stamp"
mkdir -p "$output" build
raw="build/PipelineStacks-$stamp.txt"
printf 'Intrusive native sampling run; not calibrated acceptance timing.\n' > "$output/scope.txt"
# Existing runner owns the GUI lock and uses the documented QA configuration.
scripts/performance_check.sh parser > "$output/test-console.log" 2>&1 &
runner=$!
trap 'kill "$runner" 2>/dev/null || true' EXIT
executable="$PWD/build/PerformanceDerivedData/Build/Products/QA/Paperloft Receipts.app/Contents/MacOS/Paperloft Receipts"
process=""
sample_status=1
while kill -0 "$runner" 2>/dev/null; do
    while read -r candidate; do
        command=$(ps -p "$candidate" -o command=)
        if [[ "$command" == "$executable"* ]]; then process=$candidate; break; fi
    done < <(pgrep -x 'Paperloft Receipts' || true)
    [[ -n "$process" ]] && break
    sleep 0.2
done
if [[ -n "$process" ]]; then
    printf 'PID %s\n' "$process" >> "$output/scope.txt"
    set +e
    /usr/bin/sample "$process" 20 1 -mayDie -file "$raw" > "$output/sample.log" 2>&1
    sample_status=$?
    set -e
    if [[ -f "$raw" ]]; then shasum -a 256 "$raw" > "$output/stack-source.sha256"; fi
fi
set +e
wait "$runner"
status=$?
set -e
trap - EXIT
if [[ "$sample_status" != 0 || ! -s "$raw" ]]; then
    printf 'Native sampling failed or produced no trace (exit %s).\n' "$sample_status"
    status=1
fi
printf 'Diagnostic runner exit %s; evidence %s\n' "$status" "$output"
exit "$status"
