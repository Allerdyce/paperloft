# Share extension metadata extraction configuration

2026-09-29; Xcode 27.0 (27A266a), macOS 27 SDK. Local build configuration only; no release gate claim.

## Diagnosis and primary evidence

Fresh Release previously ran `ExtractAppIntentsMetadata` for `PaperloftShare`, whose source contains no App Intents declarations or dependency. The tool warned that metadata extraction was skipped because AppIntents.framework was not linked. Compiler warnings-as-errors does not turn this separate tool's warning into an error, but the unchanged strict CI warning check correctly rejects the log.

Apple's Swift Build source defines the boolean `LM_SKIP_METADATA_EXTRACTION` and checks it before constructing App Intents extraction tasks. This selects whether a target has that build task; it does not filter diagnostics. Pinned upstream sources:

- [BuiltinMacros declaration and registration](https://github.com/swiftlang/swift-build/blob/2cadc5ba829ab9e2d1e2564e9d98df2caece16c6/Sources/SWBCore/Settings/BuiltinMacros.swift#L910)
- [AppIntentsMetadataTaskProducer task guard](https://github.com/swiftlang/swift-build/blob/2cadc5ba829ab9e2d1e2564e9d98df2caece16c6/Sources/SWBApplePlatform/AppIntentsMetadataTaskProducer.swift#L55)

The installed Xcode 27 `SWBCore` binary contains the same `LM_SKIP_METADATA_EXTRACTION` macro string, and the fresh build demonstrates that this Xcode honors it. Binary: `/Applications/Xcode.app/Contents/SharedFrameworks/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/Frameworks/SWBCore.framework/Versions/A/SWBCore`.

The nearby `LM_FILTER_WARNINGS` option maps to `--quiet-warnings` and was not used. `LM_ENABLE_LINK_GENERATION=NO` maps to the processor's `-d` disable-output option and was also not used. No framework import, warning suppression, main-app extraction change, or verifier change was made.

## Change and verification

Only PaperloftShare's Debug, Release and QA configurations set `LM_SKIP_METADATA_EXTRACTION=YES`. Remove this opt-out if the extension later gains genuine App Intents declarations.

A new derived-data directory at `build/ShareMetadataFresh` ensured a fresh whole-app Release build, including the extension. Command:

```sh
xcodebuild -project Paperloft.xcodeproj -scheme PaperloftApp -configuration Release -destination 'platform=macOS' -derivedDataPath build/ShareMetadataFresh CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES build
```

Result: BUILD SUCCEEDED; the entire log contains no `warning:` or `error:` diagnostics. Share metadata extraction is absent. Main app extraction remains present (log line 1307); it executed and reported no relevant App Intents symbols, so no manifest was written. Package extraction tasks also remain unchanged. This verifies preserved task behavior, not implemented Shortcuts functionality.

Ignored local log: `build/share-metadata/fresh-release.log`. This was an unsigned local build; signed/sandbox runtime behavior and full CI remain integration checks. No UI tests were rerun for this three-setting change.
