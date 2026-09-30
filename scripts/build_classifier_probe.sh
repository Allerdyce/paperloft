#!/bin/bash
# Builds the bounded document-type probe against the current PaperloftKit (diagnostics only).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/classifier
swift build --package-path Packages/PaperloftKit --scratch-path build/ClassifierKit -c release --product PaperloftEval -Xswiftc -warnings-as-errors > build/classifier/build-kit.log 2>&1
bin="$(swift build --package-path Packages/PaperloftKit --scratch-path build/ClassifierKit -c release --show-bin-path)"
if [ -f "$bin/PaperloftKit.o" ]; then modules="$bin"; objects=("$bin/PaperloftKit.o"); else modules="$bin/Modules"; objects=("$bin"/PaperloftKit.build/*.o); fi
xcrun swiftc -swift-version 6 -strict-concurrency=complete -warnings-as-errors -parse-as-library -O \
  -I "$modules" Tools/ClassifierProbe/main.swift "${objects[@]}" -lsqlite3 -o build/classifier/ClassifierProbe
echo "$PWD/build/classifier/ClassifierProbe"
