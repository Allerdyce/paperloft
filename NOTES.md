# Implementation notes

P1 engine backends share ExtractionBackend and return ExtractedFields. DocumentRecognizer uses Vision for images and rasterized PDF pages; decoding downsamples images and rejects oversized input. The evaluator only sees document files, never label data. Frozen score_eval.py receives labels/predictions and owns scoring.

Initial parser misses were absent totals, not wrong amounts. Inspect OCR line grouping during P2 before changing parsing heuristics. The system model supports standard generation on this Mac but rejects the optional reasoning-level capability. Explicit required strings avoid omission of optional schema properties; empty strings map back to unknown fields.

Initial accuracy is not a P2 pass. Fixture realism and holdout independence await the P1 verifier.
