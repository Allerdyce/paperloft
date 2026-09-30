# Paperloft Receipts

A Mac App Store app by EvidencePair LLC that reads receipts, invoices and bills on your Mac, files them into a folder you choose, and exports an accountant pack. Everything runs on-device with Apple frameworks only; the app has no network access.

- User documentation: in-app Help (Help › Paperloft Help), [SUPPORT.md](SUPPORT.md) and [PRIVACY.md](PRIVACY.md).
- Product spec: [SPEC.md](SPEC.md). Acceptance criteria: [ACCEPTANCE.md](ACCEPTANCE.md). Run contract: [AGENTS.md](AGENTS.md).

## Requirements

macOS 27 or later on Apple silicon, with Xcode 27. The engine is the local Swift package `Packages/PaperloftKit`; the app, Share extension and App Intents live in `Paperloft.xcodeproj`. Understanding documents uses the on-device Apple Intelligence model when it's available and falls back to the built-in parser.

## Build and test

In Xcode, open `Paperloft.xcodeproj`, choose the PaperloftApp scheme and My Mac, then Product › Build or Product › Test.

From Terminal:

```sh
scripts/preflight_check.sh --local --log   # environment check for local development
scripts/ci.sh                               # clean Debug test build with coverage, all unit and UI tests, then clean Debug and Release builds (warnings are errors)
scripts/privacy_check.sh                    # entitlements, linked frameworks, privacy manifests
scripts/eval.sh --model system              # extraction accuracy on the 150 synthetic fixtures (frozen scorer)
```

- Local builds use ad-hoc signing. `PAPERLOFT_CI_XCCONFIG=config/PaulDevelopment.xcconfig scripts/ci.sh` uses development signing, which the App Intents framework tests need.
- Derived data and test results stay in `build/`.
- UI tests need an unlocked, unobstructed desktop and automation permissions: don't use the Mac while they run, and keep other windows clear of the app. Take the GUI lock (`mkdir ~/Factory/.gui.lock`) before any UI run.

## Release

Local checks never authorize distribution. Release requires the organization membership and credentials, the full `scripts/preflight_check.sh --log` with no FAIL, the `acceptance-v1` baseline with `scripts/verify_lock.sh` passing, and the verifier gates. See [docs/OWNER-RELEASE-SETUP.md](docs/OWNER-RELEASE-SETUP.md) and [evidence/release/readiness-20260929.md](evidence/release/readiness-20260929.md). Submission for review and public release are the owner's decision.
