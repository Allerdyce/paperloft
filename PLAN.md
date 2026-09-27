# P2 local engine plan

P1 local readiness independently passed at 5c4130b; tests and fixtures locked append-only. Formal release remains blocked. Each numbered work chunk is scoped to two hours or less and may be split further.

1. Preserve Vision row/column relationships; add generic geometric OCR tests; validate extracted dates, money, currency, kind and categories; bound filenames by UTF-8 bytes. Run fixture evals without changing the accepted corpus.
2. Implement safe journaled copy filing, collision handling, content hashes and duplicate review. Preserve original bytes; never overwrite a destination.
3. Add move/undo recovery with conservative conflict handling, durable history, metadata extended attributes, and a rebuildable local index.
4. Add randomized 1,000-operation property tests, an actual killed-process recovery integration test, and engine edge-case tests. Measure whole-target coverage; minimum75%.
5. Run parser/system fixture scoring and report optional private scores through eval.sh only. Independent verifier owns freshly generated holdout scoring. Do not inspect holdout/private data or alter thresholds.
6. Implement P2 gate, run self-check, then a fresh independent verifier. At most five fixes per failed item, three genuinely different technical approaches before parking. Advance only after applicable local checks pass.

Initial known failure: current Vision output loses spatial associations, giving parser total0% and system total71.85%. Improve the general pipeline, never special-case fixture IDs/vendors/layout IDs.

P2 OCR: row grouping first raised parser total to71.11%; oriented text-range rectangles alone did not fix rotated columns. Confident document segmentation plus perspective correction before OCR raised date100%, total99.26%, vendor100% on the locked corpus. All15 tests and clean Debug/Release builds pass. Frozen parser scorer exits0; its diagnostic difficulty line is nowFAIL (>98%) after engine improvement. Initial P1 difficulty acceptance remains documented at0%; fixtures remain unchanged and locked. The independent P2 review must evaluate this distinction.
