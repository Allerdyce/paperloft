# Local export engine subtask evidence

Date: 2026-09-27. Branch: `local/export`. Parent integrates and independently reviews; this is not a P4 acceptance result, release gate, or phase-completion claim.

## Implemented API

- `ExportDateRange.year(_:)`, `.quarter(year:quarter:)`, and `init(start:end:)`: validated inclusive receipt-calendar dates.
- `AccountantPackExporter.export(documents:libraryRoot:destination:range:zip:)`: synchronous throwing, local copy-only operation suitable for an off-main-thread task. Returns `AccountantPackResult` with folder URL, optional ZIP URL, document count, category totals, and month totals.
- `AccountantPackExporter.totals(documents:range:byMonth:)`: checked integer minor-unit sums grouped separately by ISO currency. No currency conversion.
- Pack contains RFC-4180 UTF-8 CSV, paginated CoreText/CoreGraphics summary PDF with category/month totals and “Not tax advice,” and original file bytes in distinct safe category directories.
- Hash-verified streamed reads; descriptor-relative no-follow path handling; exclusive creation and publication. New UUID destination per invocation; no overwrites/deletions. Failed work remains in a hidden `.Paperloft-export-incomplete-*` directory. ZIP failure preserves the completed folder.
- ZIP uses Apple's `NSFileCoordinator` upload coordination API, then exclusive copied output. No shell commands or networking in product code.

## Verification performed

- `scripts/preflight_check.sh --local --log`: exit 0; 38 PASS, 1 WARN, 0 FAIL, 0 TFAIL, 16 MANUAL/deferred. See `preflight.txt`. Formal membership/acceptance-tag/release prerequisites remain deferred.
- `scripts/verify_local_baseline.sh`: exit 0; existing protected hashes verified. See `baseline.log`.
- `swift test --package-path Packages/PaperloftKit -Xswiftc -warnings-as-errors`: exit 0 on final implementation; 8 ExportTests and 31 existing Swift Testing tests passed. Includes existing 1,000-operation property test. No warnings/errors. See `swift-tests.log`.
- `swift build --package-path Packages/PaperloftKit -c release -Xswiftc -warnings-as-errors`: exit 0; no warnings/errors. See `release-build.log`.

ExportTests independently parse CSV with an RFC-4180 state machine, parse the produced PDF using PDFKit, aggregate CSV amounts and compare PDF category/month totals, compare source/output SHA-256 hashes, and extract the optional ZIP with `/usr/bin/unzip`. Cases cover inclusive/custom/year/quarter/leap dates, quote/comma/newline/Unicode values, sanitized and case-folded category collisions, repeat exports, traversal, source/directory/root symlinks, changed source hashes, duplicate IDs, integer overflow, JPY/KWD precision, empty output and multipage summaries.

## Integration limits

No GUI tests, App Intents, Pro gating, full Xcode app build, or P4 independent gate was claimed here; parent owns those checks. Caller must retain security-scoped access during the operation. Root/destination paths with symbolic-link ancestors are rejected, including `/var`; use physical paths for test temporary directories. Apple-coordinated temporary archive paths are canonicalized with `realpath` because Foundation leaves that OS alias unresolved.
