#!/bin/bash
# Local Debug/Release builds and all unit/UI tests. Never archives or uploads.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/ModuleCache evidence/ci
export CLANG_MODULE_CACHE_PATH="$PWD/build/ModuleCache"
args=(-project Paperloft.xcodeproj -scheme PaperloftApp -destination 'platform=macOS' -derivedDataPath build/DerivedData SWIFT_TREAT_WARNINGS_AS_ERRORS=YES)
for configuration in Debug Release; do
  xcodebuild "${args[@]}" -configuration "$configuration" clean build 2>&1 | tee "evidence/ci/$configuration.log"
done
result="build/Tests-$(date +%Y%m%d-%H%M%S).xcresult"
xcodebuild "${args[@]}" -configuration Debug -resultBundlePath "$result" test 2>&1 | tee evidence/ci/tests.log
printf 'Local CI passed. Results: %s\n' "$result"
