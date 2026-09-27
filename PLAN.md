# Autonomous local development plan

Owner approval for local phase progression is recorded in AGENTS.md. Never request it again. Distribution/upload remain blocked.

## Resume P0 after transient preflight clears
1. Add the required App Intents framework dependency; verify that metadata extraction no longer warns.
2. Extend CI to reject all emitted build warnings, not only Swift warnings. Keep all test flows and assertions.
3. Run clean Debug/Release builds and all tests.
4. Independent verifier: fresh-clone builds, raw tests, settings and integrity checks. Record local readiness separately from formal P0 failure caused by deferred prerequisites.
5. Lock accepted tests and save/push the checkpoint, without phase-completion tags.

## Next local phase: P1
Plan tasks no longer than two hours for generated receipts and labels, extraction backend protocol, evaluation CLI and frozen-scorer integration. Independent verifier owns holdout generation and fixture-difficulty review. Do not progress past failed applicable checks.

## Current temporary hold
Local preflight returns exit 3 on battery power. Automatic five-minute retries are active. No additional owner approval is required.
