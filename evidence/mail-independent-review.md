# Independent Mail component review

**PASS — scoped component merge review** at `5710c84144c0a328e6e1b9d2af94e38b09274606`, against `d9454df`. This is not full P4, UI, sandbox integration, performance acceptance, or release approval.

## Independent evidence

Read AGENTS.md and LESSONS.md; reviewed all added MailDocument.swift and MailDocumentTests.swift source and the actual component diff. Required local preflight exited 0: 38 PASS, 1 existing autorestart WARN, 0 FAIL, 0 TFAIL, 16 manual/deferred prerequisites. acceptance-v1 and distribution prerequisites remain deferred.

Independent hash audit passed all 165 ACCEPTANCE.lock entries and 13 protected baseline files against `640eab51a302cef28e57cd17f481673043c7dc9d`. Four lock revisions remain append-only. `git diff --exit-code d9454df..HEAD -- ACCEPTANCE.lock AGENTS.md SPEC.md ACCEPTANCE.md scripts .codex/agents prompts` exited 0. Only the intended new parser/tests, process note, and component evidence are committed in this branch.

Fresh independent commands, run after the author froze the corrected revision:

- `swift test --package-path Packages/PaperloftKit --scratch-path build/MailIndependentFinalDebug -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`: exit 0; fresh build 23.27 seconds, all 40 tests passed in 18.927 seconds. Nine MailDocumentTests included.
- `swift test --package-path Packages/PaperloftKit --scratch-path build/MailIndependentFinalRelease -c release -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`: exit 0; fresh build 32.41 seconds, all 40 tests passed in 15.950 seconds. Nine MailDocumentTests included.

No compiler warnings were emitted. The existing corrupt-PDF resilience case emits its expected CoreGraphics diagnostic and passes. An earlier run overlapped author edits and failed an obsolete HTML-notice assertion; it was discarded as a mixed snapshot and replaced by both fresh stable-revision runs above.

## Findings resolved during review

Independent stdin Swift probes initially reproduced rejection of an HTML-only receipt body and an application/octet-stream attachment named invoice.pdf. Both were scope gaps, not approved cuts. The corrected revision extracts HTML text without a renderer and preserves generic PDF attachment bytes after checking its filename and PDF signature.

Independent probes then found that a less-than comparison in script raw text swallowed its closing tag, and nested template elements leaked hidden wrong-total text. Both were repaired and included in regression assertions. Named accented entity support was also added; unknown semicolon entities in the supported recognition window produce an explicit unsupported error rather than silently substituting a vendor.

The final independent probe returned exactly `Total: 12.50` for each of:

- `<script>if (a < b) { run(); }</script><p>Total: 12.50</p>`
- `<template><template>ignore</template>Wrong Total: 999</template><p>Total: 12.50</p>`

It also returned `Café & Co` and `Total: 12.50` for the named-entity HTML example, and verified exact decoded `%PDF-1.7 example` bytes for the generic PDF example. Probe exit 0.

## Safety and test assessment

No remaining demonstrated merge-blocking defect in the reviewed component. The parser imports only Foundation and receives bytes; it has no file, mailbox, subprocess, web-renderer, or network access. Attachment names are bounded display hints, not output paths. Caller-provided bytes, MIME depth/part count, decoded text size, PDF size/count, header size, and hidden-HTML nesting have explicit limits. Whole-line multipart delimiters, transfer encodings, duplicate headers/parameters, invalid data, nested alternatives, binary bytes, and unsafe display names have meaningful assertions. Tests inspect expected literal text/bytes, not merely parser-generated expectations. No skips, disabled tests, or special fixture branches were added.

HTML attributes, scripts, styles, head/template content and comments are discarded without evaluating resources. The implementation is a bounded text extractor, not a browser. Plain alternatives are preferred and bodies are not duplicated.

## Integration obligations and limits

The caller still must bound the initial file read, retain the security-scoped source grant, preserve notices, validate PDF structure using the document reader, generate unique destination paths, and deliver bodies plus PDFs to review without losing originals. Signature checking in this parser is not full PDF validation. Encrypted/signed containers, unsupported character sets/encodings/entities and extended filename variations remain explicit supported-subset limitations, not a claim of general MIME conformance. Full app flow, drag-in, exact failure presentation and peak-memory acceptance require parent verification.

No GUI, private/holdout data, root-worktree mutations, source/test/script edits, archive, or upload were performed by this reviewer. The mandatory preflight refreshed the mail worktree's existing evidence/preflight-latest.txt. This report is the only manually authored review file; independent builds are in ignored build directories.
