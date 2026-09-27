# Paperloft status

P0 and P1 independently PASS for local readiness. P2 engine is implemented but its independent accuracy gate remains open.

At 166c3cb, independent clean builds and all 30 tests pass; engine coverage is 89.53%. The 1,000-operation test and forced-crash recovery of 120 originals pass. Fixture accuracy passes all thresholds: date100%, total99.26%, vendor97.78%, kind98.67%, category100%.

The first holdout attempt was invalid because the reviewer's label audit failed; its evidence is preserved. A repaired, independently audited fresh set passed date98.15%, total96.30%, vendor100%, category100%, but kind83.33% failed the92% requirement. P2 stays open. Generic document-type guidance is improved; all30 tests and clean builds pass after that fix, fixture regression is running, and a fresh independent review follows. P3 has not started. No owner action needed.

Formal gates remain FAIL on deferred prerequisites. No release archive, distribution signing, upload, submission or phase-completion tags. Owner authorization covers continued local phases after independent checks without further local approval.

The first type-prompt fix regressed fixture totals to94.81% and was rejected. Approach2 separates type classification from the restored numeric extraction prompt; clean builds and all30 tests pass, with fixture accuracy still running.

The separate classifier caused16 omissions on its first regression run. Completed field extraction is now retained on optional classification failure, with explicit diagnostic counts and auto-file blocked. All32 tests and clean builds pass; full fixture regression is active before further independent scoring.
