#!/bin/bash
# Pre-tag integrity check. This is not a replacement for the formal lock gate.
set -euo pipefail
cd "$(dirname "$0")/.."
if git rev-parse -q --verify refs/tags/acceptance-v1 >/dev/null; then
  exec scripts/verify_lock.sh
fi
baseline=640eab51a302cef28e57cd17f481673043c7dc9d
git diff --exit-code "$baseline" -- ACCEPTANCE.md SPEC.md scripts/verify_lock.sh scripts/lock_add.sh scripts/score_eval.py .codex/agents prompts
if [ -s ACCEPTANCE.lock ]; then shasum -a 256 -c ACCEPTANCE.lock; fi
removed="$( { git log -m --format= -p --no-renames -- ACCEPTANCE.lock; git diff HEAD -- ACCEPTANCE.lock; } | grep -E '^-[0-9a-fA-F]{64}  ' || true)"
[ -z "$removed" ] || { echo 'FAIL: locked hashes removed or changed'; exit 1; }
echo 'PASS: pre-tag protected files and existing hashes. Formal acceptance baseline is still deferred.'
