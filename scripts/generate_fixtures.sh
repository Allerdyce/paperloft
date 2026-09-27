#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun swiftc -parse-as-library -swift-version 6 -strict-concurrency=complete -warnings-as-errors scripts/generate_fixtures.swift -o build/generate-fixtures
exec build/generate-fixtures "${1:-Tests/Fixtures}"
