# Bounded temporary intake cleanup

2026-09-29, local scope only.

Successful Mail replacement now discards its owned EML parent after the child Inbox snapshot and Message-ID ledger transaction both return successfully. The processing EML has no Review/QuickLook consumer, all materialization/OCR readers have returned, and cleanup checks generation, active Inbox references and QuickLook before calling the queue's validated discard. Snapshot or ledger uncertainty preserves the parent. Watched proofs remain in the children and their existing ledger; user originals are never removed.

Mail materialization uses a unique app-created `MailScratch/<UUID>` attempt folder, removed only after its processing scope finishes. Share TIFF conversion similarly uses a unique attempt folder and retains the upstream Share claim on failure. Scan attempt folders and pasted images are removed after successful owned Inbox publication. Cleanup never enumerates user paths or deletes a source merely because it is internal. No old scratch directories are swept.

Four new `IntakeCleanupTests` pass: successful email parent cleanup plus restart; snapshot failure preserving retryable parent; ledger failure preserving parent across proof recovery; actual scan-adapter scratch removal while its owned receipt remains. Existing shared TIFF retry and all earlier ingress tests still pass.

Strict native hostless run: 88 XCTest + 101 Swift Testing tests, zero failures. Strict Release build passed. Logs remain ignored under `build/intake11/intake-cleanup-tests.log` and `intake-cleanup-release.log`.

Filed/removed records, unselected candidate records and abandoned uncertain-delivery records remain safely retained. Immediate deletion there needs durable removal plus explicit preview/QuickLook lifetime ownership, or a separate startup retirement design. No best-effort `persist()` authorizes deletion; no timers or broad GC were introduced. Full temporary-storage compliance and full 1.1 readiness remain unclaimed.
