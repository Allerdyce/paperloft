#!/bin/bash
# Verifier raw test run: every testable in the PaperloftApp scheme, warnings as errors, coverage on.
cd /Users/builder/Factory/paperloft/evidence/checkouts/p3-3dfb51d || exit 1
E=/Users/builder/Factory/paperloft/evidence/verifier-P3-20261001
export CLANG_MODULE_CACHE_PATH="$PWD/build/ModuleCache"
rm -rf build/Verifier-P3-20261001.xcresult
xcodebuild -project Paperloft.xcodeproj -scheme PaperloftApp -destination 'platform=macOS' \
  -configuration Debug -derivedDataPath build/TestDerivedData -enableCodeCoverage YES \
  -resultBundlePath build/Verifier-P3-20261001.xcresult SWIFT_TREAT_WARNINGS_AS_ERRORS=YES clean test > "$E/raw-test.log" 2>&1
echo "test exit=$?" > "$E/raw-test-exit.txt"
