#!/bin/bash
# Builds the AC-10 two-at-a-time concurrency diagnostic against the current PaperloftKit (diagnostics only).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/throughput
swift build --package-path Packages/PaperloftKit --scratch-path build/ThroughputKit -c release --product PaperloftEval -Xswiftc -warnings-as-errors > build/throughput/build-kit.log 2>&1
bin="$(swift build --package-path Packages/PaperloftKit --scratch-path build/ThroughputKit -c release --show-bin-path)"
if [ -f "$bin/PaperloftKit.o" ]; then modules="$bin"; objects=("$bin/PaperloftKit.o"); else modules="$bin/Modules"; objects=("$bin"/PaperloftKit.build/*.o); fi
xcrun swiftc -swift-version 6 -strict-concurrency=complete -warnings-as-errors -parse-as-library -O \
  -I "$modules" Tools/ConcurrencyProbe/main.swift "${objects[@]}" -lsqlite3 -o build/throughput/ConcurrencyProbe
echo "$PWD/build/throughput/ConcurrencyProbe"
