#!/bin/bash
# Adds files to ACCEPTANCE.lock once the verifier has passed the gate that
# introduced them (acceptance tests, the fixture set, eval thresholds).
# Frozen: never edit this file. The lock is append-only.
#
# Usage: scripts/lock_add.sh <file-or-directory>...
# Paths are relative to the repo root. Directories are added file by file.
# Then commit with a message like: "lock: P1 fixtures (verifier PASS)".

set -eu
cd "$(dirname "$0")/.."

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <file-or-directory>..." >&2
  exit 2
fi

touch ACCEPTANCE.lock
added=0

lock_one() {
  local f="${1#./}"
  if cut -c67- ACCEPTANCE.lock | grep -qxF -- "$f"; then
    echo "already locked: $f"
    return
  fi
  shasum -a 256 -- "$f" >> ACCEPTANCE.lock
  added=$((added + 1))
}

for path in "$@"; do
  if [ -d "$path" ]; then
    while IFS= read -r -d '' f; do
      lock_one "$f"
    done < <(find "${path%/}" -type f ! -name '.DS_Store' -print0 | sort -z)
  elif [ -f "$path" ]; then
    lock_one "$path"
  else
    echo "not found: $path" >&2
    exit 1
  fi
done

echo "locked $added new file(s)"
