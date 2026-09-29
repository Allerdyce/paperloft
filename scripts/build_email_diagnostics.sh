#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
repo="$PWD"
mkdir -p build/email-diagnostics
swift build --package-path Packages/PaperloftKit --scratch-path build/EmailDiagnosticsKit -c release --product PaperloftEval -Xswiftc -warnings-as-errors > build/email-diagnostics/build-kit.log 2>&1
bin="$(swift build --package-path Packages/PaperloftKit --scratch-path build/EmailDiagnosticsKit -c release --show-bin-path)"
if [ -f "$bin/PaperloftKit.o" ]; then
  modules="$bin"
  objects=("$bin/PaperloftKit.o")
else
  modules="$bin/Modules"
  objects=("$bin"/PaperloftKit.build/*.o)
fi
xcrun swiftc -swift-version 6 -strict-concurrency=complete -warnings-as-errors -parse-as-library -O \
  -I "$modules" "$repo/Apps/PaperloftApp/MailReviewPreparation.swift" \
  "$repo/Apps/PaperloftApp/EmailBodyRenderer.swift" "$repo/Tools/EmailDiagnostics/main.swift" \
  "${objects[@]}" -lsqlite3 -o build/email-diagnostics/EmailDiagnostics
python3 - <<'PYMETA'
import hashlib, json, pathlib, subprocess
root = pathlib.Path.cwd()
paths = [pathlib.Path("Apps/PaperloftApp/MailReviewPreparation.swift"), pathlib.Path("Apps/PaperloftApp/EmailBodyRenderer.swift"), pathlib.Path("Tools/EmailDiagnostics/main.swift"), pathlib.Path("scripts/build_email_diagnostics.sh"), pathlib.Path("scripts/project_email_diagnostics.py")]
paths += sorted(pathlib.Path("Packages/PaperloftKit/Sources/PaperloftKit").glob("*.swift"))
metadata = {"binarySHA256": hashlib.sha256(pathlib.Path("build/email-diagnostics/EmailDiagnostics").read_bytes()).hexdigest(), "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(), "dirty": bool(subprocess.check_output(["git", "status", "--porcelain", "--", "Apps", "Packages", "Tools/EmailDiagnostics", "scripts/build_email_diagnostics.sh"], text=True)), "sources": {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}}
pathlib.Path("build/email-diagnostics/build-manifest.json").write_text(json.dumps(metadata, sort_keys=True) + "\n")
PYMETA
printf '%s\n' "$repo/build/email-diagnostics/EmailDiagnostics"
