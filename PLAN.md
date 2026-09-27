# P1 local fixtures and evaluation

P0 local readiness independently passed; formal release prerequisites remain deferred.

1. Define extraction records and backend protocol; implement initial parser, deterministic stub and on-device backend (under two hours).
2. Add image/PDF OCR and a directory evaluation command; never read labels in extraction (under two hours).
3. Generate 150 synthetic documents across 12 layouts and 40 vendors, with required photo/long/non-receipt/confusable mix (under two hours).
4. Connect eval.sh to the frozen scorer, run parser/system evaluations, record honest scores (under two hours).
5. Independent verifier owns holdout generation and fixture difficulty review. Fix applicable findings before P2; lock accepted fixtures/tests append-only.

Cycle 1: independent P1 local FAIL on layout diversity. Replace still-unlocked corpus; preserve rejected-run evidence; rerun parser difficulty and system pipeline, then independent review. P2 remains unstarted.
