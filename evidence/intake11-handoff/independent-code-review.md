# Independent scoped handoff code review

Result: PASS for reviewed local implementation; not a phase, privacy-certification, or release gate.

Reviewed package/extension commits c5bd146, a3f5b89, f9bab83 and traversal correction 1c26c6a, plus the root working-tree AppModel consumer, SharedInboxTests and privacy-check changes.

## Findings resolved

- External provider copying now pins ancestor descriptors using traversal-only access, refuses symlinks and nonregular files, copies in bounded chunks to exclusive destinations, and checks source identity/mutation. The traversal regression explicitly denies directory read permissions before copying.
- The app acquires a support-directory process-ownership lease before reading inbox state and retains it until process exit. This prevents a second process restoring a stale inbox and later overwriting accepted receipts. The production app has one model; same-process restoration test instances share ownership. A separate group lease spans recovery, claiming, ingestion and acknowledgment.
- Shared accepted-ID writes are capped at the same 8 MiB limit enforced on reads.

## Crash and compatibility review

- Owned payload publication precedes receiving-item snapshot, accepted-ID ledger, waiting-item snapshot, and handoff acknowledgment. Replay uses stable IDs; source bytes remain app-owned after acknowledgment. Receiving items with committed ledger IDs recover to waiting; missing ledgers can be repaired from outstanding claims.
- New optional inbox metadata remains compatible with old snapshots. The extension does not link the receipt engine package in its target dependencies; the activation predicate limits eligible types and group access is disabled by default for unsigned builds.
- SharedInboxTests cover ordinary durable intake/replay, interrupted receiving-state recovery, malformed ledger preservation, competing-owner rejection and optional metadata. Package tests include cross-process lease exclusion, source swap rejection and traversal-only ancestors.

## Evidence limits

- This reviewer read source and regression tests; did not rerun builds/tests, drive the GUI, or claim live native Share-menu or Continuity Camera success. Parent is running integrated validation. Agent-reported package test/provider smoke passes are not represented as independent execution here.
- Internal app-group metadata operations assume cooperating trusted processes. Guarantees concern process interruption, not sudden power loss. Actual process-kill integration remains separate verification.
- The privacy script checks entitlements/manifests, activation-rule restrictions and dynamic dependencies. Dynamic-link inspection alone cannot establish absence of statically linked code; current source dependency review supplies only the scoped package-dependency finding.

## Reviewed working-tree fingerprints

- `Apps/PaperloftApp/AppModel.swift` SHA-256 `7a92e7de8a883fa07be8908d87ae0ab76ae1c41b5c6e0fed841212e3a0b1fea9`
- `Tests/PaperloftAppTests/SharedInboxTests.swift` SHA-256 `a880ef0ccf0c4a223de009ed8be24f07380a4beb43091c8dec23e44db5ba868d`
- `scripts/privacy_check.sh` SHA-256 `2fa2161f03217deaba514e45c96d3fe570692c4a4ab15363639654aeab4ad72a`
