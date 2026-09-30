#!/bin/bash
# Synthetic NSSharingService host for local share-extension presentation diagnostics only.
set -euo pipefail
cd "$(dirname "$0")/.."
app=build/ShareHostProbe.app
mkdir -p "$app/Contents/MacOS"
python3 - "$app/Contents/Info.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1], 'wb') as handle:
    plistlib.dump(dict(CFBundleExecutable='ShareHostProbe', CFBundleIdentifier='app.paperloft.synthetic-share-host',
                      CFBundleName='Share Host Probe', CFBundlePackageType='APPL', CFBundleVersion='1',
                      NSPrincipalClass='NSApplication', NSHighResolutionCapable=True, LSMinimumSystemVersion='27.0'), handle)
PY
swiftc -swift-version 6 -warnings-as-errors Tests/Support/ShareHostProbe.swift -o "$app/Contents/MacOS/ShareHostProbe"
codesign --force --sign - "$app"
echo "$PWD/$app"
