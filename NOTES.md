# Implementation notes

P1 engine backends share ExtractionBackend and return ExtractedFields. DocumentRecognizer uses Vision for images and rasterized PDF pages; decoding downsamples images and rejects oversized input. The evaluator only sees document files, never label data. Frozen score_eval.py receives labels/predictions and owns scoring.

Initial parser misses were absent totals, not wrong amounts. Inspect OCR line grouping during P2 before changing parsing heuristics. The system model supports standard generation on this Mac but rejects the optional reasoning-level capability. Explicit required strings avoid omission of optional schema properties; empty strings map back to unknown fields.

Initial accuracy is not a P2 pass. Fixture realism and holdout independence await the P1 verifier.

## Owner-requested library usability (2026-09-27)

Owner requests double-click opening, direct receipt deletion, visible processing/ready pills, tax export, and clearer list hierarchy inspired by supplied Expensify reference. Direct reversible deletion is the primary library action; filing History remains available for prior recovery contracts. No permanent deletion is introduced. Export describes recorded tax, not deductible amounts or tax filing. Preserve native Mac controls and all locked acceptance tests.

Paul Allerdyce's development team is authorized as a temporary local signing option while EvidencePair D-U-N-S/enrollment is pending. Team membership type and real Team ID requested; no signing identity guessed or production App Store record transferred. Release/upload prohibition remains. Owner setup: Xcode Settings > Apple Accounts, add Paul account, select team, Manage Certificates > + > Apple Development. Keep credentials on-device; only Team ID is needed in chat. Use a separate development bundle identifier if configuring this team, retaining EvidencePair production legal identity.

### Temporary development signing verified
Owner confirmed paid Paul Allerdyce team `GQ4UA5C6RQ` and created the Mac's development certificate. `config/PaulDevelopment.xcconfig` is an opt-in local override using `app.paperloft.receipts.development`; default project, legal publisher, ASC secrets and production identity remain unchanged. Build with the ordinary PaperloftApp scheme and `-xcconfig config/PaulDevelopment.xcconfig`, using separate `build/PaulDevelopment` DerivedData. No provisioning update/upload flags are used. Actual Xcode build and deep strict code-signature verification passed with Apple Development: Paul Allerdyce and the requested TeamIdentifier. `security find-identity -v` initially listed0 valid despite certificate-chain verification and real signing succeeding; the actual signed app is authoritative evidence, not a reason to weaken certificate trust.

Owner also requested an app-specific theme switch: Settings > Appearance > System / Light / Dark, persisted across launches. System is the default; macOS settings are not modified.

## Library reference correction
Owner requested stronger resemblance to supplied expense-list reference. Implemented rounded warm rows, document icons colored by category, compact bounded filter menus, serif title, large search and row View actions. Root direct Computer Use now succeeds after retiring old app processes; exact updated app was opened and its actual library screen verified. Do not infer all prior automation blockers persist without checking the exact current app instance.
