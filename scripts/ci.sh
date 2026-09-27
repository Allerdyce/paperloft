#!/bin/bash
# Local Debug/Release builds and all unit/UI tests. Never archives or uploads.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/ModuleCache evidence/ci
export CLANG_MODULE_CACHE_PATH="$PWD/build/ModuleCache"
args=(-project Paperloft.xcodeproj -scheme PaperloftApp -destination 'platform=macOS' -derivedDataPath build/DerivedData SWIFT_TREAT_WARNINGS_AS_ERRORS=YES)
for configuration in Debug Release; do
  scripts/preflight_check.sh --local --fast > evidence/ci/preflight.log
  xcodebuild "${args[@]}" -configuration "$configuration" clean build 2>&1 | tee "evidence/ci/$configuration.log"
  if grep -E '(^|[[:space:]])warning:' "evidence/ci/$configuration.log"; then
    echo "FAIL: $configuration build emitted warnings" >&2
    exit 1
  fi
done
scripts/preflight_check.sh --local --fast > evidence/ci/preflight.log
result="build/Tests-$(date +%Y%m%d-%H%M%S).xcresult"
xcodebuild "${args[@]}" -configuration Debug -enableCodeCoverage YES -resultBundlePath "$result" test 2>&1 | tee evidence/ci/tests.log
if grep -E '(^|[[:space:]])warning:' evidence/ci/tests.log; then
  echo "FAIL: test build emitted warnings" >&2
  exit 1
fi
printf '%s\n' "$result" > build/latest-test-result.txt
printf 'Local CI passed. Results: %s\n' "$result"
