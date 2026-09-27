# Paperloft Receipts

Native macOS receipt filing app by EvidencePair LLC. Early local-development bootstrap; receipt import and processing are not implemented yet.

## Requirements

macOS 27, Apple silicon and Xcode 27. Apple frameworks only; PaperloftKit is a local package.

## Build and test

Open `Paperloft.xcodeproj`, choose PaperloftApp / My Mac, then Product > Build or Product > Test. Local builds use ad-hoc signing without a developer team. The shared test scheme includes engine tests and UI navigation tests.

From Terminal:

```sh
scripts/preflight_check.sh --local
scripts/ci.sh
scripts/privacy_check.sh
```

CI performs clean Debug and Release builds, then all tests; it fails immediately on any failure. Derived data and test results stay in `build/`. UI testing requires an unlocked, unobstructed desktop and automation permissions. Do not interact with the Mac during UI tests. Some restricted agent sessions cannot launch SwiftPM's nested sandbox; that is not a product test pass.

## Release

`--local` never authorizes distribution signing, archives, upload or submission. Membership, credentials, full preflight, supervised shakedown, acceptance baseline and verifier gates must be completed first. See AGENTS.md.
