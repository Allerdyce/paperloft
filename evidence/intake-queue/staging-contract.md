# IntakeQueue owned staging — local component evidence

This additive PaperloftKit primitive is not yet unified application ingress. AppModel remains responsible for its single durable inbox, source-specific proofs, source permissions and acknowledgment ordering. No release or formal gate is claimed.

## Contract

- Caller supplies an app-private, stable container directory and retains process ownership. Queue-root or ancestor replacement while an instance exists is outside this contract. The caller serializes explicit discard against active readers/writers and first removes durable references.
- `enqueue` copies a regular source through no-follow descriptor traversal into a private hidden stage, hashes bounded 256 KiB chunks, checks original descriptor identity/size/mtime/ctime and current path identity, synchronizes payload/metadata/stage, exclusively renames the complete directory to its stable UUID, then synchronizes the queue root. Per-chunk autorelease pools bound Objective-C buffer lifetime; cancellation is checked before publication and each chunk.
- A matching stable-ID retry verifies original published metadata and payload hash and retries root synchronization. Conflicting content, origin, name, type or optional source metadata never overwrites the first publication. Original publication time is retained.
- Source metadata is descriptive, never authoritative extracted receipt fields. Encoded JSON is capped at 16 KiB, including escaping overhead; payload is capped at 200 MB or a lower caller limit.
- Restore calls `record(id:)` or `payloadURL(for:)`, which validate metadata, regular-file/no-follow path safety, payload size and streamed hash. Original URL/bookmark must remain separate so Move can validate and operate on the user's unchanged original.
- Copy failure/cancellation removes that invocation's hidden stage. A crash before rename may leave `.incoming-*` directories; these are never visible records and do not block same-ID retry. Offline cleanup is the caller's operational responsibility after exclusive process ownership establishes that no writers exist. There is deliberately no automatic published-record cleanup or second acceptance ledger.
- `discard` accepts only an exactly matching, verified record and its expected two owned files; it never accepts an arbitrary external source URL. A corrupt or unexpectedly populated record fails closed.
- A sync error after rename can leave a complete record. Retry the same ID; do not infer absence from an error. The tests simulate this window, not actual power loss.

## Checks

Preflight: 39 PASS, 1 WARN, 0 FAIL, 0 TFAIL (local mode). Protected baseline verification PASS; formal acceptance remains deferred.

Focused tests cover owned-copy independence, Codable restore, explicit discard, immutable-ID conflict, concurrent same-ID publication, size/empty/symlink/FIFO rejection, corruption, unexpected discard contents, traversal-only source ancestors, pre-copy and mid-copy cancellation cleanup, in-place source mutation, incomplete crash-stage invisibility/retry, escaped metadata expansion, and post-publication sync-error retry.

Warnings-as-errors package run PASS: 24 XCTest + 101 Swift Testing tests. Optimized warnings-as-errors package build PASS. After strengthening cancellation to actual Task cancellation and mutation to a same-size multi-chunk overwrite, all 12 focused queue tests PASS.

Logs (local, not committed): `build/intake-queue/tests-final.log`, `build/intake-queue/release-final.log`, `build/intake-queue/focused-final.log`. Native sandbox app integration and final independent review belong to the parent integration task.
