#!/bin/bash
# Synthetic NSFilePromiseProvider source for local cross-app drag tests only.
set -euo pipefail
cd "$(dirname "$0")/.."
app=build/MailPromiseSource.app
mkdir -p "$app/Contents/MacOS"
python3 - "$app/Contents/Info.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1], 'wb') as handle:
    plistlib.dump(dict(CFBundleExecutable='MailPromiseSource', CFBundleIdentifier='app.paperloft.synthetic-mail-source',
                      CFBundleName='Synthetic Mail Promise', CFBundlePackageType='APPL', CFBundleVersion='1',
                      NSPrincipalClass='NSApplication', NSHighResolutionCapable=True, LSMinimumSystemVersion='27.0'), handle)
PY
swiftc -swift-version 6 -warnings-as-errors Tests/Support/MailPromiseSource.swift -o "$app/Contents/MacOS/MailPromiseSource"
codesign --force --sign - "$app"
echo "$PWD/$app"
