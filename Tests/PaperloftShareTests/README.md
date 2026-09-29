# Share extension smoke checks

This headless harness uses synthetic item providers. It checks all seven activation
identifiers, exclusion of text/URLs/HTML, mixed selection, the 20-file cap/skips,
and preservation of a provider file inside its callback. It does not test Finder,
Preview, Photos, keyboard accessibility or screen-reader behavior.

From the repository root:

```sh
mkdir -p build/share-smoke
xcrun swiftc -swift-version 6 -warnings-as-errors -emit-library -emit-module -module-name PaperloftHandoff Packages/PaperloftHandoff/Sources/PaperloftHandoff/*.swift -emit-module-path build/share-smoke/PaperloftHandoff.swiftmodule -o build/share-smoke/libPaperloftHandoff.dylib
xcrun swiftc -swift-version 6 -warnings-as-errors -parse-as-library -I build/share-smoke -L build/share-smoke -lPaperloftHandoff -Xlinker -rpath -Xlinker @executable_path Apps/PaperloftShare/ShareViewController.swift Tests/PaperloftShareTests/ShareSmoke.swift -o build/share-smoke/ShareSmoke
build/share-smoke/ShareSmoke
```

Provider lifetime follows [Apple's loadFileRepresentation documentation](https://developer.apple.com/documentation/foundation/nsitemprovider/loadfilerepresentation(fortypeidentifier:completionhandler:)):
the provider-owned URL expires when the callback returns, so the extension finishes
its bounded streaming copy before returning that callback.

The extension omits Open Paperloft because sandboxed app-launch behavior has not
been verified in a properly signed extension. It does not attempt an unsupported
launch workaround. Live registration, App Group sharing, accessibility, peak
memory, and a signed end-to-end share remain unverified; no 1.1 gate is claimed.

The privacy manifest declares file metadata access inside owned/group containers
and for files selected by the user (C617.1 and 3B52.1), per [Apple's required-reason API documentation](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).

## Local signing configuration

Default builds use sandbox-only extension entitlements and the app's original
local entitlements, with `PaperloftAppGroupEnabled=NO`. They do not access an app
group, and the extension explains that sharing needs a signed build.

`config/PaulDevelopment.xcconfig` selects the `*Shared.entitlements` files and
sets `PaperloftAppGroupEnabled=YES` for the existing, owner-authorized development
team GQ4UA5C6RQ. It keeps distinct target-specific development bundle IDs. A local
build can select it with `-xcconfig config/PaulDevelopment.xcconfig` (development
signing only; do not archive or upload). The app-group identifier in both Info
files and shared entitlements remains `$(TeamIdentifierPrefix)app.paperloft.receipts`.
No portal changes or signing-capability verification were performed here.

For unsigned verification, omit that xcconfig and use `CODE_SIGNING_ALLOWED=NO`.
The default app/extension versions are 1.1 with provisional build 1; reconcile
build numbers with App Store Connect only when distribution is authorized.
