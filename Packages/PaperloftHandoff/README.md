# PaperloftHandoff

Local 1.1 foundation only. A standalone Swift package using Foundation and Darwin file descriptors: no model,
OCR, index, library, network or UI dependency. This is not the Share extension,
a watcher, app integration, or a completed 1.1 acceptance gate.

## Integration

Construct `HandoffStore(containerURL:)` with the resolved app-group container.
The caller owns entitlement/container lookup and security-scoped source access.

1. The extension assigns a UUID per input before calling `publish`. Keep the
   UUID on retry. `HandoffInput` carries URL, declared type, optional source app.
2. `availableItems()` exposes fully published metadata. `claim(id)` atomically
   moves an item into `.claimed` and returns its payload URL and metadata.
3. **Persist `claim.item.id` as a unique intake key in the same durable transaction
   as the destination inbox item.** Replaying that key must return the existing
   item. Copy the payload into app-owned durable storage before committing.
4. Only after that transaction succeeds, call `acknowledge(claim)`. A receipt is
   atomically written before the package removes its handoff copy.
5. On consumer launch, call `outstandingClaims()` and repeat steps 3–4 with each
   stable ID. Then claim new available items. Failed intake stays claimed for retry.

The package supplies at-least-once delivery with durable acknowledgements.
Exactly-once app effects require step 3: no filesystem package can atomically
commit an independent app database and its own acknowledgement. A crash after
app commit but before acknowledgement is deliberately replayed. A crash after
receipt creation but before deletion is cleaned during recovery. Receipts persist
indefinitely to retain retry identity; do not remove them without an explicit
application retention/idempotency policy.

Acquire `try await store.acquireConsumerLease()` before any recovery/claim batch.
A nil result means another process is consuming; return and retry later. Retain
the returned `HandoffConsumerLease` across every await in the complete batch:

```swift
guard let lease = try await store.acquireConsumerLease() else { return }
defer { withExtendedLifetime(lease) {} }
// Recover, claim, durably ingest and acknowledge while lease stays alive.
```

The descriptor holds nonblocking exclusive `flock`; deinit unlocks/closes it,
and process exit releases it. Never delete `Inbox/.consumer.lock`, whose stable
inode coordinates all processes. A symlink/nonregular/multiply-linked lock fails
closed. The lock covers consumers, not writers. Actors additionally serialize
operations within each store instance. `outstandingClaims` is startup recovery,
not an expiring claim lease.

## Files and limits

- At most 20 files per publish call; each file at most **200,000,000 bytes**.
- 256 KiB streaming copy buffer; payloads are never loaded whole into memory.
- Allowed declared types: PDF, JPEG, PNG, HEIC, TIFF, public email message and
  Apple Mail email. Declared types must match a supported filename extension.
  This is transport validation; main-app intake must decode and validate content.
- Metadata includes UUID, original filename, declared type, timestamp, source app
  if known, and copied byte count. Names/source labels have bounded length.
- Original names are display metadata only. Payload paths are generated internally.
  Paths containing traversal components or symlinks are rejected, as are directories
  used as payloads. Metadata and payload size are validated before claim/recovery.
- Writers copy into `Inbox/.incoming/<random-stage-id>`, synchronize payload and
  metadata, then rename to `Inbox/<item-id>` on the same filesystem.
- Publication is atomic **per item**, not per batch. If a batch throws, earlier
  items may already be published. Retry all inputs using the original UUIDs.
  IDs represent immutable submissions; never reuse one for a different document.
- External source/provider copies traverse directories with descriptor-relative
  `openat` and `O_NOFOLLOW`, then open the leaf without following symlinks.
  Only the fixed macOS root aliases `/var/` and `/tmp/` are mapped to `/private/`
  for system item-provider URLs; user-controlled symlinks are never resolved.
  `O_NONBLOCK` prevents a FIFO substitution from hanging before `fstat` rejects
  nonregular files. Size and nanosecond modification/change times are compared
  on the opened descriptor before/after copying; a final safe reopen verifies
  pathname identity. Destinations are exclusively created, never overwritten.
  The container's internal metadata, publication and cleanup still assume
  cooperating trusted app-group processes; they are not an adversarial sandbox.
- `cleanupStaleIncoming()` deletes only UUID-named staging directories older than
  24 hours. Run before starting writers, without overlapping writes in another
  process. Published items and claims never expire; originals are never modified.
- Crash handling covers process termination/restart, not a guarantee of storage
  durability across sudden power loss. Malformed published items throw an error
  for the app to report/quarantine; the package never silently deletes them.

## Validation

Run `swift test --package-path Packages/PaperloftHandoff` from the repository root.
Tests cover 1,000 seeded retry scenarios, crash windows around intake and receipt
commit, half-written stages, stale cleanup, corrupt metadata/payloads, byte/count
bounds, symlink/FIFO/racing-source rejection, partial-batch retries, unchanged
originals, and lease exclusivity/release across actors and a child process. A
20-file/100 MB copy test exercises streaming scale. Peak process memory, actual
process-kill tests, extension integration and all live Share-menu tests remain
separate validation work; these unit tests do not establish AC-109 or AC-111.
