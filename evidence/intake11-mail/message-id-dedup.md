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

## App integration follow-up (2026-09-29)

The integration proposal above is now implemented in AppModel. Successful email replacement writes a synchronized atomic inbox snapshot carrying `mailDelivery` proofs, then commits the ledger without an actor suspension. Startup validates the ledger and replays all durable proofs before enabling inbox changes. The returned delivery UUID must equal the saved proof; a conflict blocks further changes rather than silently accepting inconsistent history.

The app shows an explicit Duplicate row/filter/detail for an already delivered Message-ID. Failed email imports offer Retry email. Selected-candidate delivery is all-or-nothing: if any selected candidate has no successful review, none of its siblings are published, the original EML remains retryable, and no Message-ID is acknowledged. Temporary grants stay local until successful publication.

If snapshot writing or ledger commitment fails, including failure after snapshot rename, all inbox mutations pause. Retry recovery reloads disk as authority, replays committed proofs, and only then permits intake, editing/removal, Confirm or library changes. Background refresh, shared intake and watched delivery recheck the mutation guard after asynchronous work. Email boundaries wait for in-flight filing/library operations so a committed file outcome cannot be lost behind an unrelated email recovery freeze. Parent IDs and statuses are revalidated after waiting; removed emails cannot be resurrected.

Nine new hostless app tests cover successful relaunch and explicit duplicate state; partial failure/retry; snapshot failure before and after rename; ledger failure after saved replacement with blocked edits/intake; startup UUID conflict; commit-return UUID conflict; library-mutation overlap; and removal before late delivery. These are synthetic tests without GUI interaction. Native visual verification and an integrated end-to-end Mail drag remain separate checks.

Final native strict unit run passed 55 XCTest plus 100 Swift Testing tests (`build/intake11/mail-app-final2.log`); strict optimized Release build passed (`build/intake11/mail-app-release-final.log`). Both logs contain no compiler/build warnings or errors. `COPY_PHASE_STRIP=NO` avoids stripping the already-signed embedded extension in these local builds. No UI tests were run for this scoped integration.
