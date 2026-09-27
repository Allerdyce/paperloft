# Paperloft status

P0–P2 independently accepted for local development. P3 remains active and independently FAILS. No further owner approval is needed for routine local work. Release and uploads remain blocked.

Independent fresh-clone checks at d17b2bf: Debug, Release and optimized QA builds pass without warnings; 50 tests pass, one accessibility audit fails, none are skipped. All32locked tests execute. Whole-kit coverage90.23%, privacy and protected-baseline checks pass. Evidence: evidence/gates/P3.md.

The default audit retains14findings:7missing descriptions,3contrast failures,2missing actions and2parent/child mismatches. Native PDF description and product picker problems are repaired. A minimal native app reproduces some remaining system issues, without waiving them. Last fully green CI commit remains d9454df. No P3 acceptance or phase tag.

Independent components continue in separate branches: Mail file-picker intake passes real UI and56package tests; promised-file drag verification is underway. Watched-folder scanner passes52tests and independent review; app integration is underway. App Intents production adapter passes16independent tests, but7system-framework tests fail metadata discovery. Actual100-document app-pipeline performance harness is being built. Purchase work remains parked on an Apple StoreKitTest SDK warning-as-error failure; no warnings suppressed.

Membership, signing, ASC, supervised shakedown and acceptance-v1 remain deferred. No release archives, uploads or submission.
