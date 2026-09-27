# Tax and accountant export — scoped implementation

Base: ea051b5. Worktree: paperloft-tax-export, branch local/tax-export.

## Changes

- Export sheet explicitly names Tax & Accountant Export and shows the three delivered items: transactions CSV, PDF summary, and copied filed originals. Existing quarter/custom controls, actions, identifiers, optional ZIP and destination chooser remain.
- Calendar year is named explicitly; custom dates support other accounting periods without inferring a jurisdiction's tax year.
- Added PDF recorded-tax totals separately by currency, with recorded and unknown receipt counts. All-unknown currency prints Unknown; explicit recorded zero remains zero. CSV schema and blank-for-unknown behavior remain unchanged.
- No deduction calculations, currency conversions, returns, account access, distribution or uploads.
- No preview count taken from the search-filterable AppModel.documents: exporter continues fetching all filed library records and applying the date range.
- Descriptor-relative copying, hash validation, staging publication and original-file preservation are unchanged.

## Verification

- Local full preflight: 38 PASS, 1 WARN, 0 FAIL, 0 TFAIL, 16 MANUAL; membership/signing deferred. Protected baseline PASS.
- `swift test --package-path Packages/PaperloftKit --filter 'TaxExportTests|ExportTests' -Xswiftc -warnings-as-errors`: 12 tests PASS (existing nine plus three new). Log: build/tax-export-tests.log.
- New checks cover inclusive boundaries, mixed currencies, unknown versus zero, three-decimal precision, tax aggregation overflow, exported PDF/CSV semantics and original bytes.
- Strict optimized unsigned app build: PASS. Logs build/tax-export-build.log and final incremental build/tax-export-build-final.log.
- Independent review and native visual verification remain required. This is not a phase gate, accessibility audit, or launch-readiness claim.
