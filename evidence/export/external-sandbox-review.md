# External sandbox export verification

Local QA build, ordinary launch (no UITestMode or model stub), observed through Computer Use. Both library and export destination selected through real NSOpenPanel dialogs under build/ExternalExportReview. Only bundled synthetic sample documents used.

- On-device model extracted Maple Desk Supply, 2026-09-04, USD25.92, tax1.92. Filed one copy into external Library/2026/Office supplies.
- Initial external ZIP export failed unsafePath. O_RDONLY ancestor-descriptor walk required directory-listing access outside the scoped grant. Error appeared only after closing export sheet; fixed by inline sheet error reporting.
- Changed ancestor opens to Darwin O_SEARCH (O_EXEC|O_DIRECTORY), retaining per-component O_NOFOLLOW, descriptor-relative operations, exclusive output creation and hash validation. Independent read-only export reviewer found no weakening; confirmed SDK definition/open(2) semantics.
- Rebuilt QA, relaunched normally with saved library bookmark. Selected external Packs directory, enabled ZIP, exported2026: app visibly reported Export complete,1document and CSV/PDF.
- View Summary opened Quick Look after export completion. Accessible PDF text showed category Office supplies USD25.92 and month2026-09 USD25.92. Destination grant is retained with export result so later preview has access.
- Shell inspection of these agent-created external outputs (not app container): one CSV row, minor units2592, copied original SHA256 matches, ZIP present and zipfile.testzip() returnsNone.

Output: build/ExternalExportReview/Packs/Accountant Pack 2026-01-01 to 2026-12-31 D3B206A1-9CC0-4EFC-8152-58DB616A2788 (and .zip). This is product-flow verification, not a P4 or release gate.
