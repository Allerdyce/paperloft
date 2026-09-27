# Local 1.1 Mail and watched-folder audit

This is a scoped package improvement under the owner's explicit authorization to start local 1.1 work. It is not a phase gate, full 1.1 acceptance result, release archive or upload authorization. The supplied add-on document's release/run instructions were treated as reference, not executed.

## Implemented

- `message/rfc822` parts now recurse through the same MIME decoder with shared global depth, part and text limits; nested PDFs remain byte-identical.
- EML input limit is 50 MiB; bounded reads continue rejecting symbolic links, special files and growth beyond the limit. Existing PDF/text/part limits stay in force.
- `MailImport.Result.envelope` exposes display-only From, To, Date, Subject and Message-ID metadata. Common RFC 2047 B/Q words decode for UTF-8, Latin-1, Windows-1252 and ASCII. These values never replace receipt extraction or cause network access.
- Watched-folder acknowledgments record file identity (device/inode) with content hash, in addition to backward-compatible filename history. An acknowledged file renamed on the same volume remains consumed after restart.
- Scanner reads respect an exclusive advisory file lock held by a cooperative writer, in addition to stable metadata and before/after identity/hash checks.

## Verified

Warnings-as-errors package tests: 12 XCTest plus 73 Swift Testing tests passed. New focused coverage includes three nested-message transfer encodings, three encoded subject variants, folded encoded words, 50 MiB boundary reads, remote-reference stripping, selectable PDF text, and 50 watched files added in bursts using the real two-second stability interval. The burst test also holds a writer lock, confirms all complete bytes, acknowledges all 50, renames a file, restarts, and observes no repeat.

10,000 bounded MIME mutations completed in 0.242 seconds with no test failure. This narrow deterministic mutation corpus is not the complete fixture/fuzz coverage or instrumented memory proof required by AC-102.

Logs: ignored `build/intake11/tests.log`, `baseline-tests.log`, `release.log`. No owner receipts, private samples, holdout fixtures, app containers or real mailboxes were accessed for this work. All added fixtures are synthetic and inline. Existing frozen tests were unchanged.

## Remaining gaps

**AC-102 — partial.** No complete three-per-case fixture corpus. RFC 2231 attachment names and image attachments/candidate selection are missing. Unsupported or malformed encoded words remain literal display text. HTML preference/rendering is still the existing plain-text tokenizer; no claim of complete email fidelity.

**AC-106 — open.** CoreText creates selectable local PDFs, and the tokenizer/CoreText path has no URL/resource loader. The synthetic test verifies remote references are discarded; it does not count WebKit requests. Full HTML rendering with blocked remote loads and a rendered From/To/Date/Subject block remain app-layer work. Envelope metadata is available for that work.

**AC-114 — partial.** The 50-file stable-burst/cooperative-writer/acknowledged-rename scenario passes. Stable metadata plus advisory locks cannot prove an uncooperative writer has closed if it pauses longer than two seconds. Legacy filename-only history cannot identify a rename until identity information is recorded. Pending rename before durable inbox acknowledgment also needs queue-wide identity-based idempotence: the current app delivery key uses a filename. `Candidate.fileIdentity` is now available, but this scoped change does not alter AppModel or introduce the unified intake queue.

Share extension, Continuity Camera, TIFF handling, UI source labels, free-limit accounting, live Mail drag, app-group signing, device testing, accessibility, fresh final verification, release and uploads are outside this change.

Optimized package build with warnings as errors also passed. A final focused strict run passed all five new tests after making parsed envelope metadata read-only to callers. Independent source review and integrated app regression remain required before merging this branch.
