#!/bin/bash
# Read-only ASC connectivity probe. No upload or distribution operation implemented.
set -euo pipefail
cd "$(dirname "$0")/.."
[ "${1:-}" = ping ] || { echo 'Usage: scripts/asc.sh ping' >&2; exit 2; }
scripts/preflight_check.sh --fast
scripts/verify_lock.sh
set -a
source "${ASC_ENV_FILE:-$HOME/Factory/.secrets/asc.env}"
set +a
exec xcrun swift scripts/asc_ping.swift
