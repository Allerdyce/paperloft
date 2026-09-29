# Continued intake hardening — 2026-09-29

Root product changes: e29bb76 preserves classificationUnavailable for negative assessments;5046d81 avoids copy-time stripping of a signed extension. Additive10000-case corpus mutation test39fd080 independently reviewed in053f527. No prompt/model-policy changes or refused-call retries. Existing UI field guidance and filing eligibility remain unchanged.

## Verified

- Root unit target:101XCTest+113Swift tests=214PASS,0failures. `build/Intake11HardeningUnit2.xcresult`, `build/intake11-hardening-unit2.log`. Includes actual StoredReview saved-payload/roundtrip checks and all existing unit tests. No excluded tests within target. An initial invocation incorrectly named a nonexistent PaperloftAppTests target and ran no tests; corrected invocation uses the scheme's PaperloftKitTests target. Initial result retained separately; not counted as pass.
- Fresh development-signed Release: `build/Intake11HardeningSigned/Build/Products/Release/Paperloft Receipts.app`, log `build/intake11-hardening-signed.log`. BUILD SUCCEEDED,0warning/error lines. Strict deep signature validation and app/extension privacy checks PASS. Development signing only; no archive/upload.
- Protected pre-tag baseline PASS: `build/intake11-hardening-baseline.log`. Formal acceptance baseline still deferred.
- Strict Release model-free focused tests4PASS. Corpus loop3159parsed/6841safe rejections in0.84seconds. Every harmless header insertion preserves original parsed content; rejection and nested/resource stress retain explicit limits. No peak-memory or formalAC102verdict.

## Remaining

System80 classification failures and existing full accessibility/integration/performance/formal gates remain open. No model accuracy repair, complete native UI rerun, full CI or launch-readiness claim. Last full green CI remainsd9454df. The user authorizes distribution signing/archives/uploads only after readiness; submission/public release stay blocked.
