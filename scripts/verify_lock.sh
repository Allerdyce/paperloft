#!/bin/bash
# Verifies that the acceptance bar has not moved. Frozen: never edit this file.
#
# 1. The local acceptance-v1 tag is the one Ali pushed (checked against origin).
# 2. The frozen files are byte-identical to that tag.
# 3. Every file listed in ACCEPTANCE.lock still matches its SHA-256.
# 4. ACCEPTANCE.lock has only ever grown: no line was ever removed or changed,
#    in any commit (merges included) or in the working tree.
#
# Exit 0: all PASS.  Exit 1: something moved; stop and write HANDOFF.md.

set -u
cd "$(dirname "$0")/.." || exit 1

TAG="${ACCEPTANCE_TAG:-acceptance-v1}"
FROZEN="ACCEPTANCE.md AGENTS.md SPEC.md
  scripts/verify_lock.sh scripts/lock_add.sh scripts/score_eval.py
  .codex/agents/verifier.toml .codex/agents/qa_explorer.toml
  .codex/agents/critic.toml .codex/agents/release_checker.toml
  prompts/1-shakedown.md prompts/2-shakedown-after-reboot.md
  prompts/3-run.md prompts/4-final-verification.md"
bad=0

if ! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "FAIL tag $TAG is missing"
  exit 1
fi

export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10"
local_tag="$(git rev-parse "refs/tags/$TAG^{}" 2>/dev/null)"
remote_tag="$(git ls-remote origin "refs/tags/$TAG^{}" 2>/dev/null | awk '{print $1}')"
[ -n "$remote_tag" ] || remote_tag="$(git ls-remote origin "refs/tags/$TAG" 2>/dev/null | awk '{print $1}')"
if [ -z "$remote_tag" ]; then
  echo "WARN could not read $TAG from origin; relying on the local tag"
elif [ "$remote_tag" = "$local_tag" ]; then
  echo "PASS local $TAG matches origin"
else
  echo "FAIL local $TAG ($local_tag) differs from origin ($remote_tag)"
  bad=1
fi

for f in $FROZEN; do
  if [ -f "$f" ] && git diff --quiet "$TAG" -- "$f"; then
    echo "PASS $f matches $TAG"
  else
    echo "FAIL $f differs from $TAG or is missing"
    bad=1
  fi
done

if [ ! -f ACCEPTANCE.lock ]; then
  echo "FAIL ACCEPTANCE.lock is missing"
  bad=1
elif ! grep -q '[^[:space:]]' ACCEPTANCE.lock; then
  echo "PASS ACCEPTANCE.lock is empty (nothing locked yet)"
else
  if check_out="$(shasum -a 256 -c ACCEPTANCE.lock 2>&1)"; then
    echo "PASS $(grep -c '[^[:space:]]' ACCEPTANCE.lock) locked file(s) match their hashes"
  else
    echo "FAIL locked files changed:"
    echo "$check_out" | grep -v ': OK$' | sed 's/^/     /'
    bad=1
  fi
fi

removed="$( { git log -m --format= -p --no-renames -- ACCEPTANCE.lock; git diff HEAD -- ACCEPTANCE.lock; } 2>/dev/null \
  | grep -E '^-[0-9a-fA-F]{64}  ' )"
if [ -z "$removed" ]; then
  echo "PASS ACCEPTANCE.lock has only grown"
else
  echo "FAIL lines were removed from or changed in ACCEPTANCE.lock:"
  echo "$removed" | sed 's/^/     /'
  bad=1
fi

exit "$bad"
