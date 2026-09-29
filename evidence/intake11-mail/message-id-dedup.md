# Message-ID delivery ledger — scoped package work

The 1.1 intake specification requires the same Message-ID dragged twice to count as a duplicate alongside the existing content-hash check. Content hashes are not treated as substitutes for Message-ID. This component records successfully committed email deliveries; it does not change the app import flow by itself.

## API

- `MailDeliveryLedger(directory:)` uses a caller-provided private support directory.
- `MailDeliveryLedger.proof(messageID:deliveryID:)` returns a Codable proof for a supported bracketed Message-ID, or nil for missing/malformed IDs. It trims surrounding whitespace and preserves case. The persisted key is SHA-256 of the ID contents; no sender address or raw Message-ID is stored.
- `committedDelivery(messageID:)` returns the successful delivery UUID, or nil.
- `commit(proof)` is idempotent and preserves the first committed delivery. It does not record an attempted import or reserve an in-flight message.

The bounded JSON ledger permits 25,000 entries and at most 4 MiB. It fails closed on malformed, oversized, nonregular or symlink state files. A file lock serializes independent ledger instances; writes use a private temporary file, file fsync, atomic rename and directory fsync. It does not silently reset corrupt state or evict earlier IDs.

## Required app integration

1. Preserve the app's serialized `processWaiting` email processing. Before preparing candidates, query the ID; an existing committed ID should produce a visible duplicate result and avoid a second delivery. Missing/unsupported IDs retain the ordinary content-hash path.
2. If rendering/extraction/cancellation fails without a successfully delivered selection, do not commit an ID. A proof allocated in memory alone does not acknowledge anything.
3. On successful selected delivery, write the proof atomically inside the same durable inbox snapshot as the replacement items. This save must report failure; the current nonthrowing `persist()` cannot serve as the success boundary.
4. Only after that save succeeds, commit the proof to the ledger. If ledger writing fails, retain the durable proof, surface/retry the bookkeeping error, and block further imports until reconciliation succeeds rather than silently importing a second copy.
5. On launch, replay saved proofs before processing waiting mail or allowing removal of their items. This closes the crash interval between inbox persistence and ledger commit. The ledger then retains the ID even after the delivered items are filed or removed from the inbox.
6. Do not infer a successful delivery from a failed item. Decide and test partial candidate failure behavior at the app boundary; this package component does not select or retry attachments.

This is not a cross-process claim/reservation system. If future app architecture processes multiple emails concurrently, add explicit in-flight coordination rather than assuming a query followed by a commit prevents concurrent duplicate delivery.

## Verification

Seven synthetic tests cover changed message bodies sharing one ID, restart lookup, failed/cancelled attempt retry, durable inbox-proof replay after a simulated crash window, first-commit idempotence, independent ledger instances, malformed IDs, corruption recovery, symlink preservation and oversized-state rejection. They exercise the package contract; they are not app end-to-end tests. No original/frozen tests, real receipts, mailboxes or private sample data were touched.

Warnings-as-errors full package tests passed: 12 XCTest and 93 Swift Testing tests. The optimized package build with warnings as errors also passed.

Logs are ignored local artifacts in `build/intake11/mail-ledger-focused.log`, `mail-ledger-all.log`, and `mail-ledger-release.log`. App integration and independent review remain required; this document does not declare AC-102, full 1.1 or release readiness passed.
