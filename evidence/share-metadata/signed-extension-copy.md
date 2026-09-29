# Signed extension copy — local development verification

2026-09-29. Base `5769dd3`; isolated `local/signed-copy` worktree. Root session preflight: 39 PASS, 1 WARN, 0 FAIL, 0 TFAIL; protected baseline PASS (reported by root). No GUI, archive, upload or release performed.

## Cause and scoped change

Root `build/intake11-final-development-build.log` lines 1369–1372 shows the host Embed App Extensions phase invoking `builtin-copy -strip-unsigned-binaries` after PaperloftShare was signed. Xcode refuses to alter that signed executable and emits `warning: not stripping binary because it is signed`.

Set `COPY_PHASE_STRIP = NO` on PaperloftApp Debug, Release and QA only. This removes the copy-time stripping request. No warning filter, compiler diagnostic setting, signing setting, entitlement or extension target setting changes. The extension's own build/install stripping and deployment postprocessing settings remain unchanged. The host currently has one Copy Files phase, Embed App Extensions; the setting also affects host resource/module copy commands, whose contents do not need binary stripping.

Apple's [build settings reference](https://developer.apple.com/library/archive/documentation/DeveloperTools/Reference/XcodeBuildSettingRef/1-Build_Setting_Reference/build_setting_ref.html) documents `COPY_PHASE_STRIP` as stripping copied binaries and distinguishes it from `STRIP_INSTALLED_PRODUCT`. The [current reference](https://developer.apple.com/documentation/xcode/build-settings-reference) calls it “Strip Debug Symbols During Copy.”

Local Xcode 27 corroboration: `XCBSpecifications.ideplugin/Contents/Resources/PBXCp.xcspec`, under `/Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/PlugIns`, sets `PBXCP_STRIP_UNSIGNED_BINARIES` default to `$(COPY_PHASE_STRIP)`, maps YES to `-strip-unsigned-binaries`, and maps NO to no argument. This avoids an unnecessary operation rather than hiding its warning.

## Verification

Fresh derived data, actual Paul Apple Development signing:

```sh
xcodebuild -project Paperloft.xcodeproj -scheme PaperloftApp \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build/SignedCopyFresh \
  -xcconfig config/PaulDevelopment.xcconfig \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES build
```

- Exit 0, BUILD SUCCEEDED. Entire `build/signed-copy/release.log` contains zero `warning:` or `error:` lines.
- Embed command at line 1371 has no `-strip-unsigned-binaries`; extension is still signed before embedding. Main app App Intents metadata extraction remains present at line 1381.
- `codesign --verify --strict --verbose=2` passes host app, standalone Share extension and embedded Share extension. Host validation also validates its nested extension.
- Standalone and embedded extension Mach-O SHA256 both `b6a17f11e7b21a8a02dc21e24907aeedaf64b4ac90739bca43dfb8bd783caf27`; their CDHash and decoded entitlements also match.
- Both development bundle identifiers and TeamIdentifier are expected. Host and extension retain App Sandbox and the same `GQ4UA5C6RQ.app.paperloft.receipts` group. Development `get-task-allow` is present as expected; no network entitlement added.
- Detailed local checks: `build/signed-copy/verification.json`. Build outputs remain ignored; only this summary and three target settings are committed.

This is a signed local Release-configuration build check, not a distribution archive, notarization, App Store validation, full CI, formal gate or native behavior test. Debug and QA use the same explicit setting but were not rebuilt in this scoped verification. No product logic or frozen test changes.
