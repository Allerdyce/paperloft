# Common owned intake: scoped local integration

Date: 2026-09-29. This is a local implementation check, not a 1.1 completion or release gate.

## Contract

Every new file import, drop, paste, scan, shared delivery, watched snapshot, sample and selected Mail candidate stages through `PaperloftKit.IntakeQueue`. OCR, preview and Copy use its validated owned bytes. Queue records are byte ownership metadata; Inbox membership and existing watched, Share and Message-ID proofs remain authoritative.

Direct imports retain original URL/bookmark separately for Move. Move checks the original against the hash of the reviewed owned bytes. Missing, renamed or changed originals fail with a Copy recovery action; successful Move and Undo still operate on the original location. Generated and watched documents file by Copy and preserve external originals.

`stagedSource` is never serialized. Relaunch validates the stored record, manifest and payload before exposing `documentURL`; missing or corrupt queued bytes become an Issue with filing disabled, without falling back to the original. Legacy Inbox items without queue records remain compatible.

Durable Inbox publication precedes in-memory membership and upstream acknowledgment. Ambiguous snapshot failures freeze mutation and require disk-authoritative recovery. Shared delivery retry additionally validates an extant owned item before deleting the retained upstream claim. Mail extraction uses staged candidate URLs and preserves committed-delivery transaction boundaries.

Limits remain adapter-specific: ordinary files and Share 200,000,000 bytes; EML 50 MiB; Mail attachments 16 MiB; watched files 32 MiB. Visible filenames survive queue payload naming.

## Validation

Warnings-as-errors native hostless unit run passed: 84 XCTest tests plus 101 Swift Testing tests, zero failures. Nine new `OwnedIntakeIntegrationTests` cover original deletion, rename/relaunch, changed-original Move refusal, successful Move/Undo, corrupted/forged staged URL recovery, ambiguous snapshot publication, shared TIFF stable-ID retry, retained Share claim when the owned payload is corrupt, and paste/scan provenance.

Existing Mail, watched-folder, shared delivery, startup restoration and operation tests also passed unchanged. An intermediate run exposed `testFailedInboxCommitLeavesSourceAndAllowsRetry`: after a correctly frozen failed snapshot, watcher polling returned at the busy guard before attempting recovery. The repair retries disk-authoritative startup recovery before polling and retains a live scanner's stability observations. The original assertion then passed; no existing test was weakened.

Local logs (ignored): `build/intake11/owned-intake-final.log`, `build/intake11/owned-intake-release.log`. Test bundle: `build/MailDedupDerivedData/Logs/Test/Test-PaperloftApp-2026.09.29_15-44-31--0700.xcresult`. Strict Release build passed. No private receipt contents or screenshots are part of this evidence.

## Remaining work

Owned records and some conversion/materialization scratch files are deliberately retained after filing, removal, discarded Mail candidates and parent replacement. Cleanup must follow a successful durable Inbox transaction plus secured delivery proofs, not the current best-effort `persist()`. No automatic orphan collection or temporary-EML retention completion is claimed here. Native app sandbox/UI integration remains the root verifier's work. Formal acceptance, full 1.1 readiness and release gates remain separate.
