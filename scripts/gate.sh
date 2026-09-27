#!/bin/bash
# Formal P0 gate; local development does not bypass release prerequisites here.
set -euo pipefail
cd "$(dirname "$0")/.."
[ "${1:-}" = P0 ] || { echo 'Usage: scripts/gate.sh P0 (later gates not implemented)' >&2; exit 2; }
scripts/preflight_check.sh --log
scripts/verify_lock.sh
scripts/ci.sh
scripts/privacy_check.sh
echo 'P0 self-check commands passed; independent verifier decision is still required.'
