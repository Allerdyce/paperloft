# Implementation notes

P1 engine backends share ExtractionBackend and return ExtractedFields. DocumentRecognizer uses Vision for images and rasterized PDF pages; decoding downsamples images and rejects oversized input. The evaluator only sees document files, never label data. Frozen score_eval.py receives labels/predictions and owns scoring.

Initial parser misses were absent totals, not wrong amounts. Inspect OCR line grouping during P2 before changing parsing heuristics. The system model supports standard generation on this Mac but rejects the optional reasoning-level capability. Explicit required strings avoid omission of optional schema properties; empty strings map back to unknown fields.

Initial accuracy is not a P2 pass. Fixture realism and holdout independence await the P1 verifier.

## Owner-requested library usability (2026-09-27)

Owner requests double-click opening, direct receipt deletion, visible processing/ready pills, tax export, and clearer list hierarchy inspired by supplied Expensify reference. Direct reversible deletion is the primary library action; filing History remains available for prior recovery contracts. No permanent deletion is introduced. Export describes recorded tax, not deductible amounts or tax filing. Preserve native Mac controls and all locked acceptance tests.

Paul Allerdyce's development team is authorized as a temporary local signing option while EvidencePair D-U-N-S/enrollment is pending. Team membership type and real Team ID requested; no signing identity guessed or production App Store record transferred. Release/upload prohibition remains. Owner setup: Xcode Settings > Apple Accounts, add Paul account, select team, Manage Certificates > + > Apple Development. Keep credentials on-device; only Team ID is needed in chat. Use a separate development bundle identifier if configuring this team, retaining EvidencePair production legal identity.
