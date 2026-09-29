# Watched Mail and TIFF routing — local scoped verification

Watched `.eml` files now enter the same durable owned-copy inbox and Mail processing path as directly imported email. Stable supplied bytes receive bounded structural MIME validation before being accepted; malformed messages remain unacknowledged with an actionable issue. Scanner acknowledgment means Paperloft has durably taken ownership of an unchanged copy, not that extraction or filing succeeded. Failed Mail processing keeps that owned EML retryable and does not record its Message-ID as successfully delivered.

When the Mail parent is replaced by ready attachment/body candidates, each child retains the parent's watched-delivery proof in addition to its Message-ID proof. Startup can therefore reconstruct the watched ledger even after the original inbox row is gone. Watched origin remains visible in the Mail source label. Identity/hash sequencing, cooperative writer locking, stable observation requirements and process ownership are unchanged.

The scanner and app adapter now accept `.tif` and `.tiff`, matching direct intake. The normal recognition pipeline continues rejecting multipage TIFF rather than discarding later pages. Single-page TIFF source and filed bytes are preserved. The watched-folder 32 MiB file cap remains in place, so it is deliberately more restrictive than the Mail parser's 50 MiB cap.

Four new synthetic hostless app tests exercise:

- Valid watched EML through actual image recognition and the shared Mail review pipeline, with source-byte preservation, rename/relaunch dedup, missing watched-ledger recovery from a child proof, and changed email bytes sharing a committed Message-ID.
- A partially copied email whose metadata changes between observations, which cannot enter the inbox until the completed bytes are stable.
- Failed email intake that retains its owned EML and does not commit the Message-ID; correction in the watched source produces a successful new delivery while preserving the old failed copy.
- Actual TIFF recognition, review and filing with original/filed bytes preserved.

Only the extraction backend is injected for deterministic field results. Valid image bytes use the production recognizer, scanner, inbox persistence, Mail parsing/materialization and delivery ledgers. Existing tests remain unchanged, including malformed-mail, Pro entitlement, watched rename/content-cycle, snapshot/ledger failure, and 50-file burst coverage. The new app tests use a short explicit stability interval; existing burst tests continue using the production two-second interval.

This change does not introduce the full specified unified IntakeQueue architecture or declare Q1/AC-114 complete. It connects watched Mail to the existing common processing path and closes the known unsupported-input gap. No GUI, private receipts, mailboxes, uploads or release actions were used.

Validation: native warnings-as-errors unit tests passed 59 XCTest and 101 Swift Testing tests (`build/intake11/watched-mail-final.log`). The optimized strict Release build passed (`build/intake11/watched-mail-release.log`). Both final logs contain no build warnings/errors; `git diff --check` passed. Independent source review remains required before integration.
