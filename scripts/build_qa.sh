#!/bin/bash
# Optimized local build with only the documented QA hooks. Never archive/upload.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build evidence/ci
xcodebuild -project Paperloft.xcodeproj -scheme PaperloftApp \
  -destination 'platform=macOS' -configuration QA -derivedDataPath build/QADerivedData \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build > evidence/ci/QA.log 2>&1 || {
    tail -80 evidence/ci/QA.log >&2
    exit 1
  }
if grep -E '(^|[[:space:]])warning:' evidence/ci/QA.log >&2; then
  echo 'FAIL: QA build emitted warnings' >&2
  exit 1
fi
printf '%s\n' "$PWD/build/QADerivedData/Build/Products/QA/Paperloft Receipts.app"
