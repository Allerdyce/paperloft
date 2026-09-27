#!/bin/bash
# Formal gates stay separate from owner-authorized local readiness checks.
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 scripts/gate_check.py "$@"
