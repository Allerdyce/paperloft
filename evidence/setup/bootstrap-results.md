# Bootstrap checks, September 26, 2026

- Xcode UI: Debug build succeeded; native app launched and sidebar clicked successfully in earlier Computer Use check.
- Xcode UI: four PaperloftKitTests passed (amountsKeepTheirCents, calendarValidation, decodedDatesAreValidated, filenameDoesNotTraversePaths).
- UI navigation test: FAIL, not skipped. Revised test finds content.title, then cannot hit sidebar.inbox; log identifies ChatGPT Computer Use dialog and other app windows as obstructions. Latest observed run: 18:15:05–18:15:24.
- Xcode UI: selected Run build configuration Release; Build Succeeded observed at 18:17. Restored Debug as the default Run configuration afterwards.
- scripts/privacy_check.sh against Xcode DerivedData Release/Paperloft Receipts.app: exit 0.
- scripts/verify_local_baseline.sh: exit 0. This is not a formal acceptance-tag gate.
- scripts/ci.sh: written, not passing/verified in this restricted session; CLI package resolution fails. No AC-01 or P0 PASS claimed.
