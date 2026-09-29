# Independent review: synthetic MIME corpus mutation test

Date: 2026-09-29

Result: **PASS for this bounded parser safety test.** This is not a complete MIME conformance, memory, AC102, or release-readiness gate.

## Reviewed scope

Read-only review of the final additive `Packages/PaperloftKit/Tests/PaperloftKitTests/MailCorpusMutationTests.swift` in the main checkout, plus the author's final execution log at ignored `build/intake11-mail-corpus-reviewed.log`. The reviewer did not independently execute this run or modify product code or frozen tests. The test uses only the 80 synthetic `Tests/MailFixtures/*.eml` seeds; it does not read labels, private receipts, holdouts, or invoke OCR, models, or GUI automation.

The test performs 10,000 deterministic cases. Its schedule reaches every seed for each of eight operator slots: unused-header insertion, truncation, byte changes, byte insertion, nested message wrappers, base64 wrapping, newline removal, and generated multipart part-count stress. The final operator replaces the seed with a generated multipart message rather than modifying its contents.

Meaningful assertions include attachment count and per-attachment byte bounds, handling only the expected `MailDocument.Failure` rejection type, accounting for all 10,000 cases, both acceptance and rejection occurring, sampled deterministic reparsing of accepted cases, and a 120-second loop limit. Unexpected thrown errors fail the test.

## Review improvements verified

- Corpus size uses throwing `#require(files.count == 80)`, preventing continued indexing/modulo operations after a missing or wrong-size corpus.
- All seeds are parsed before mutation. Adding an unused header must produce exactly the original parsed document, and rejection of that operator fails. This prevents generated multipart successes from concealing wholesale rejection of the seed corpus.

Both recommendations are present in the final reviewed source. No remaining blocker was identified within this test's scope.

## Execution evidence and limits

The author's strict Release run completed successfully. The inspected log reports 3,159 parsed and 6,841 expected parser rejections, with a 0.839616875-second mutation loop and a 0.856-second test duration. The log's four passing tests include this one mutation test plus three separate classification-assessment tests; it does not represent four mutation runs.

These are bounded stress results, not proof that every accepted document is semantically correct. Deterministic reparsing is sampled only among accepted cases; rejection determinism is not exhaustively checked. The operators do not exhaust malformed MIME behavior or all exact resource boundaries. Peak memory is not measured, and the elapsed loop timing is not end-to-end email intake performance. No accuracy percentage, private-data validation, formal acceptance-gate completion, or production readiness is claimed.
