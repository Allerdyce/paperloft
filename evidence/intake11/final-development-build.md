# Development build verification — 2026-09-29

Product sources at862caa1 (subsequent audit1133b81 is evidence only). Fresh build: `build/Intake11FinalDevelopment/Build/Products/Release/Paperloft Receipts.app`; log `build/intake11-final-development-build.log`.

Release using `config/PaulDevelopment.xcconfig`, Swift/GCC warnings as errors, succeeded. Signing is Apple Development for Paul Allerdyce, teamGQ4UA5C6RQ, bundleapp.paperloft.receipts.development. Strict deep code signature verification passed; privacy check passed for app and extension (sandboxed, no outgoing network entitlement, privacy manifests, Apple frameworks). Protected pre-tag baseline passed; formal acceptance baseline remains deferred.

One packaging warning: Xcode did not strip the already signed embedded extension. This is not a warning-free build claim. No compiler errors or warnings. Existing project-file working-tree changes are Xcode comment normalization/settings reordering only; no functional configuration delta was included.

This verifies compilation and development signing after PDF/parser fixes, not a distribution archive, uploaded build, formal gate, or replacement for runtime accuracy/accessibility testing. Current system80 diagnostic failures prevent readiness. No submission/public release action.
