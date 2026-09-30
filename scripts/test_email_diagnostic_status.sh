#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Rebuild first: linking whatever object is already present can test stale engine code.
mkdir -p build/email-diagnostics
swift build --package-path Packages/PaperloftKit --scratch-path build/EmailDiagnosticsKit -c release --product PaperloftEval -Xswiftc -warnings-as-errors > build/email-diagnostics/status-build-kit.log 2>&1
bin="$(swift build --package-path Packages/PaperloftKit --scratch-path build/EmailDiagnosticsKit -c release --show-bin-path)"
if [ -f "$bin/PaperloftKit.o" ]; then
  modules="$bin"
  objects=("$bin/PaperloftKit.o")
else
  modules="$bin/Modules"
  objects=("$bin"/PaperloftKit.build/*.o)
fi
xcrun swiftc -swift-version 6 -strict-concurrency=complete -warnings-as-errors -parse-as-library \
  -I "$modules" Apps/PaperloftApp/MailReviewPreparation.swift Tools/EmailDiagnostics/Status.swift Tools/EmailDiagnostics/StatusTests.swift \
  "${objects[@]}" -lsqlite3 -o build/email-diagnostics/StatusTests
build/email-diagnostics/StatusTests
