# Independent export component review

Result: **PASS — merge-ready component**, at `d5dad21fc4d9a345401c149cb9df3100a413c37b` against `d9454df`.

This is a component review only. It is not P4 acceptance, AC-01 fresh-clone acceptance, a UI/Intents check, or release authorization.

## Independently executed evidence

- Read AGENTS.md, LESSONS.md, SPEC.md section 6 and AC-12; reviewed the actual added AccountantPack.swift and ExportTests.swift and complete changed-file inventory.
- `scripts/preflight_check.sh --local --log`: exit 0; 38 PASS, 1 WARN (existing autorestart setting), 0 FAIL, 0 TFAIL, 16 MANUAL/deferred prerequisites. Local development only.
- Independent Python SHA-256 audit: exit 0; all 165 ACCEPTANCE.lock entries matched. All 13 protected baseline paths (ACCEPTANCE.md, SPEC.md, frozen scripts, baseline agent files and prompts) matched kit commit `640eab51a302cef28e57cd17f481673043c7dc9d`. All four lock revisions were append-only. AGENTS owner amendment is the authorized exception; it and all protected files/lock are unchanged in this component diff. acceptance-v1 remains deferred.
- `swift test --package-path Packages/PaperloftKit --scratch-path build/ExportIndependentDebug -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`: exit 0. Fresh Debug build completed in 14.04 seconds; 8 ExportTests passed, plus 31 Swift Testing tests passed. No compiler warnings. Existing corrupt-PDF resilience test emitted the expected CoreGraphics diagnostic and passed.
- `swift build --package-path Packages/PaperloftKit --scratch-path build/ExportIndependentRelease -c release -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`: exit 0; fresh Release build completed in 16.24 seconds, no compiler warnings.
- `git diff --exit-code d9454df..HEAD -- ACCEPTANCE.lock AGENTS.md SPEC.md ACCEPTANCE.md scripts .codex/agents prompts`: exit 0.

## Findings

No demonstrated merge-blocking defect in this component.

The eight independently rerun ExportTests meaningfully inspect generated artifacts: an independent quoted-CSV parser checks exact rows and escaped Unicode/comma/quote/newline values; independently accumulated CSV category and month amounts must appear in PDFKit-extracted summary text; every listed copied file is read and SHA-256 checked against its source. They exercise inclusive quarter/custom boundaries, leap-year construction, separate USD/EUR totals, JPY/KWD precision, overflow rejection, empty and multipage PDF output, Unicode and sanitization collisions, repeated exports preserving prior output, duplicate IDs, traversal, changed source bytes, source/destination symlinks, and ZIP extraction matching CSV and original bytes. These assertions do not simply reuse exporter totals as their oracle. No skips, disabled cases or fixture-special product branches were introduced.

Code review confirms integer checked aggregation and currency separation; atomic exclusive final directory rename; exclusive no-follow output creation; descriptor-relative source traversal rejecting symlinks and non-regular files; streaming hash validation; and copy-only behavior that preserves source and previous outputs on failures. Failed staging directories intentionally remain recoverable. Summary contains the required tax-advice disclaimer and both category and month totals. ZIP is optional and the ordinary folder remains available.

## Limits and integration follow-up

The parent must verify app and App Intent wiring, Pro gating, sandbox/security-scope behavior, the full Xcode build/test suite and fresh P4 acceptance separately. This run did not drive UI, read private samples/holdout, archive, upload or modify source/tests/scripts. Static symlink rejection was tested; adversarial concurrent pathname swaps during the Foundation ZIP coordination window were not stress-tested, so this report does not assert comprehensive race proof for the ZIP path. PDFKit validated readability/content; visual styling was not independently rendered in this no-UI component review.

The required preflight script incidentally refreshed tracked `evidence/preflight-latest.txt`; it was not manually edited or reverted. The only manually authored file is this report. Build/test artifacts are under ignored build/package build directories.
