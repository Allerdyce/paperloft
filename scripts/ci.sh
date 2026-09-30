#!/bin/bash
# Local Debug/Release builds and all unit/UI tests. Never archives or uploads.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/ModuleCache evidence/ci
export CLANG_MODULE_CACHE_PATH="$PWD/build/ModuleCache"
args=(-project Paperloft.xcodeproj -scheme PaperloftApp -destination 'platform=macOS' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES)
# Optional development signing (e.g. config/PaulDevelopment.xcconfig) for tests that need a real team.
if [ -n "${PAPERLOFT_CI_XCCONFIG:-}" ]; then args+=(-xcconfig "$PAPERLOFT_CI_XCCONFIG"); fi
scripts/preflight_check.sh --local --fast > evidence/ci/preflight.log
result="build/Tests-$(date +%Y%m%d-%H%M%S).xcresult"
coverage_data="$(mktemp -d "$PWD/build/CoverageDerivedData-XXXXXX")"
xcodebuild "${args[@]}" -derivedDataPath "$coverage_data" -configuration Debug -enableCodeCoverage YES -resultBundlePath "$result" clean test 2>&1 | tee evidence/ci/tests.log
# Compiler and build warnings fail CI. XCTest runtime notices ("<unknown>:0: warning: -[Class test] : ...")
# describe test-time behaviour, not the build, so they're excluded from this check.
build_warnings() { grep -E '(^|[[:space:]])warning:' "$1" | grep -vE '^<unknown>:0: warning: -\[' ; }
if build_warnings evidence/ci/tests.log; then
  echo "FAIL: test build emitted warnings" >&2
  exit 1
fi
printf '%s\n' "$result" > build/latest-test-result.txt
printf '%s\n' "$coverage_data" > build/latest-test-derived-data.txt
# Keep the final Release product available to privacy and bundle checks.
for configuration in Debug Release; do
  scripts/preflight_check.sh --local --fast > evidence/ci/preflight.log
  xcodebuild "${args[@]}" -derivedDataPath build/DerivedData -configuration "$configuration" clean build 2>&1 | tee "evidence/ci/$configuration.log"
  if build_warnings "evidence/ci/$configuration.log"; then
    echo "FAIL: $configuration build emitted warnings" >&2
    exit 1
  fi
done
printf 'Local CI passed. Results: %s\n' "$result"
