#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="${1:-build/DerivedData/Build/Products/Release/Paperloft Receipts.app}"
python3 - "$app" <<'PY'
import plistlib, pathlib, sys, subprocess
resolved = list(pathlib.Path('.').rglob('Package.resolved'))
assert not resolved, 'Unexpected Package.resolved files: ' + ', '.join(map(str, resolved))
app=pathlib.Path(sys.argv[1])
assert app.is_dir(), f'Built app missing: {app}'
ent=plistlib.loads(subprocess.check_output(['codesign','-d','--entitlements',':-',str(app)],stderr=subprocess.DEVNULL))
assert ent.get('com.apple.security.app-sandbox') is True
assert not ent.get('com.apple.security.network.client', False)
assert ent.get('com.apple.security.files.user-selected.read-write') is True
manifest=app/'Contents/Resources/PrivacyInfo.xcprivacy'
privacy=plistlib.loads(manifest.read_bytes())
assert privacy.get('NSPrivacyTracking') is False
assert privacy.get('NSPrivacyCollectedDataTypes')==[]
exe=app/'Contents/MacOS/Paperloft Receipts'
linked=subprocess.check_output(['otool','-L',str(exe)],text=True)
for line in linked.splitlines()[1:]:
    library=line.strip().split(' (')[0]
    assert library.startswith(('/System/Library/','/usr/lib/')), f'Unexpected library: {library}'
for extension in (app/'Contents/PlugIns').glob('*.appex'):
    ent = plistlib.loads(subprocess.check_output(['codesign','-d','--entitlements',':-',str(extension)],stderr=subprocess.DEVNULL))
    assert ent.get('com.apple.security.app-sandbox') is True
    assert not ent.get('com.apple.security.network.client', False)
    info = plistlib.loads((extension/'Contents/Info.plist').read_bytes())
    rule = info['NSExtension']['NSExtensionAttributes']['NSExtensionActivationRule']
    assert 'TRUEPREDICATE' not in str(rule)
    privacy = plistlib.loads((extension/'Contents/Resources/PrivacyInfo.xcprivacy').read_bytes())
    assert privacy.get('NSPrivacyTracking') is False and privacy.get('NSPrivacyCollectedDataTypes') == []
    linked = subprocess.check_output(['otool','-L',str(extension/'Contents/MacOS'/info['CFBundleExecutable'])],text=True)
    assert not any(name in linked for name in ['SwiftData.framework', 'Vision.framework', 'FoundationModels.framework', 'PaperloftKit'])
    for line in linked.splitlines()[1:]:
        assert line.strip().split(' (')[0].startswith(('/System/Library/','/usr/lib/'))
print('PASS: app and embedded extensions sandboxed, no outgoing network, privacy manifests, activation rules, Apple system libraries only.')
PY
