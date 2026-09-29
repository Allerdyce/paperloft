# Independent IntakeQueue component review

2026-09-29. **PASS for the documented owned-staging component**, author commit `5d52f43`. This is not unified-ingress integration, native sandbox verification, a full phase gate or distribution readiness.

Reviewed independently in `/Users/builder/Factory/paperloft-intake11-handoff` after cherry-picking the author's three scoped files. No product changes were made by this review. Added three independent adversarial tests in `IntakeQueueReviewTests.swift`.

## Resolved review findings

1. Per-field UTF-8 bounds did not bound escaped JSON size. Enqueue could previously publish metadata exceeding its own 16 KiB read limit. It now checks encoded bytes before publication and tests escape expansion rejection without publication.
2. Existing-ID retry did not repeat root-directory synchronization after a previous post-rename error. It now synchronizes before returning the original record. A deterministic regression injects the post-rename failure, verifies the complete publication remains, and requires retry synchronization before success.

## Verified

- Independently executed all 12 author queue tests with Swift warnings-as-errors and complete strict concurrency: PASS.
- Independently added and executed 3 adversarial tests: PASS. A symlink in a source ancestor cannot publish; replacing the source path with an equal-size/equal-content different inode during copying cannot publish; a symlinked manifest cannot authorize discard or delete external metadata. Assertions verify original/replacement bytes remain unchanged by the queue.
- Reviewed fixed 256 KiB streaming buffers, incremental SHA-256, regular-file checks, no-follow path-component traversal, traversal-only ancestor descriptors, size limits, source pre/post size/mtime/ctime and final path identity, exclusive atomic rename, payload/metadata/directory synchronization, cancellation before publication, immutable-ID conflict handling, and explicit verified discard.
- Tests cover actual task cancellation after a partial chunk, same-size 600 KB in-place mutation during a multi-chunk copy, crash-leftover invisibility, complete-record reopening, two-actor same-ID publication, and post-publication synchronization failure/retry.

Commands (run from this worktree):

```
swift test --package-path Packages/PaperloftKit --scratch-path build/QueueReview -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete --filter IntakeQueueTests
swift test --package-path Packages/PaperloftKit --scratch-path build/QueueReview -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete --filter IntakeQueueReviewTests
```

Logs: `build/queue-review-tests.log`, `build/queue-review-adversarial-tests.log`. Author separately reports full package and optimized build passes in `staging-contract.md`; this reviewer independently reran the scoped tests above.

## Required integration boundaries

- Root must be an app-private stable directory. Concurrent replacement of its path/ancestors is explicitly outside the API contract; some operations are descriptor-relative and others resolve the trusted path. This queue is not a general arbitrary-directory file service.
- Caller retains original URL/bookmark identity, commits the one durable inbox and source-specific proofs, and acknowledges upstream sources only afterward. Owned payloads do not by themselves authorize moving original files.
- Caller must serialize discard against references/readers/writers. Published records are never automatically removed.
- Pre-rename crashes may leave hidden incoming directories. They cannot be consumed as records and do not block retries, but safe offline cleanup remains documented operational debt. Do not add age-only cleanup while another process may be writing.
- Failure injection tests establish process-level publication/retry behavior, not physical power-loss guarantees. Live app integration and sandbox-native workflow validation remain pending with the parent.
