# Startup retirement for explicitly removed receipts

2026-09-29. Scoped local implementation; no general orphan garbage collection.

A cold startup may retire an exact verified queue record only when the authoritative persisted Inbox explicitly marks its item `aside` (the user's Remove action), no active item references that record, and all Mail, Share and watched delivery proof recovery succeeded. Before deletion, a fresh fsynced Inbox snapshot clears those aside intake references while preserving their receipt/source metadata and delivery proofs. Deletion uses the queue's verified exact-record API and never touches original source URLs.

Missing or corrupt Inbox, corrupt proof history, ambiguous startup snapshot write, another process's consumer lease, another live same-process model, or an active unrecorded source URL inside owned storage prevents unsafe cleanup. Recovery within an already-started model never runs retirement. Invalid/corrupt candidate records and unknown paths remain untouched.

Absence from Inbox is deliberately insufficient deletion authority: a queue-only orphan may be an uncommitted scan/import's only recoverable bytes. Filed receipts currently lack a durable cleanup disposition and are retained, as are unselected candidate records and hidden incoming stages. A crash between reference clearing and exact discard leaks safe storage; there is no broad sweep or runtime timer.

Nine new `StartupIntakeRetirementTests` cover explicit removal vs live/orphan preservation, actual Remove/released-model relaunch, actual filed-without-proof preservation, corrupted Inbox, corrupted removed payload/unknown path, missing snapshot/corrupt proof ledger, ambiguous publication/recovery, same-process model/external consumer lease, and an active legacy owned URL.

Strict native hostless suite passed: 97 XCTest + 101 Swift Testing tests, zero failures. Existing tests remained unchanged. Strict Release build passed. Ignored logs: `build/intake11/startup-retirement-tests2.log`, `build/intake11/startup-retirement-release.log`.

Remaining retention requires explicit durable consumption/retirement proofs for filed or unselected documents. Full temporary-storage compliance and complete 1.1 readiness remain unclaimed.
