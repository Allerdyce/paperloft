# PaperloftHandoff

Local 1.1 foundation only. A standalone Foundation-only Swift package: no model,
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

One consumer owns claim recovery. `outstandingClaims` is startup recovery, not
an expiring lease, and must not race another live consumer. Writers may run in
other processes. Actors serialize operations within each store instance.

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
- The container is private to cooperating, trusted app-group processes. The
  Foundation path checks are not a security boundary against a hostile process
  continuously replacing filesystem nodes between validation and use.
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
bounds, symlink rejection, partial-batch retries and unchanged originals. A
20-file/100 MB copy test exercises streaming scale. Peak process memory, actual
process-kill tests, extension integration and all live Share-menu tests remain
separate validation work; these unit tests do not establish AC-109 or AC-111.
