
## 2026-09-26 — Owner-approved local development before membership

Added an explicit --local preflight mode and startup exception in AGENTS.md. Ali approved proceeding while the D-U-N-S/membership is pending. The native Terminal preflight had 38 PASS, 1 WARN and 10 FAIL; the failures were signing identities, placeholder ASC credentials/key/team and the postponed acceptance tag. Default preflight remains strict. Local mode defers only designated distribution prerequisites, skips distribution signing probes and ASC API calls, preserves machine/GitHub/product metadata checks, and clearly excludes release authorization. No acceptance criteria or verifier scripts were changed.

## P0 local build checks

Added native test targets, shared test scheme, local Debug/Release/test CI command and built-app privacy checks. The first four engine tests pass in Xcode. The initial UI test failed on window naming and reported a ChatGPT Computer Use dialog obstructing the app. Navigation now exposes explicit button identifiers and the test asserts content via a stable heading identifier; no test was skipped.

## Full Access retry
- Removed the custom `-packageCachePath` from CI. With effective Full Access, Xcode resolved PaperloftKit normally; supplying that custom cache returned an empty package graph and a missing-product error. DerivedData and compiler module caches remain inside build/.

## UI test repair
- Wait for foreground state before clicking; assert macOS static-text values rather than empty accessibility labels. No flow or assertion removed. Complete CI passes: build/Tests-20260926-185705.xcresult (4 engine tests and 1 navigation test).
