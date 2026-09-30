# Mail routing after optional classifier failure — 2026-09-29

Branch `local/intake11-handoff`, based on root `2db08bd`. Implements the read-only-approved narrow boundary from NEXT-MODEL-HANDOFF task A. Candidate presentation only; no projector, scorer, prompt, model, assessment or extraction change, and no error is erased.

## Change

`Apps/PaperloftApp/MailReviewPreparation.swift`: the valid-`DocumentKind` check now precedes the `classificationError` check.

| Attachment result | Before | After |
| --- | --- | --- |
| read receipt/invoice/bill, refinement OK | receipt | receipt |
| read receipt/invoice/bill, refinement failed | unresolved (cover body rendered and added) | receipt (body suppressed); error kept, `classificationUnavailable` review, no auto-file |
| `not_receipt`, refinement failed | unresolved, visible | unchanged |
| `not_receipt`, refinement OK | other (omitted) | unchanged |
| invalid kind (±error) | unresolved | unchanged |
| read failure / blank OCR (throws) | unresolved with issue | unchanged |

## Verified

- New `Tests/PaperloftAppTests/MailRoutingRefinementTests.swift`: 6 tests, covering all three financial kinds with and without failure (attachment read once, body never rendered/read, error and `classificationUnavailable` preserved, `canAutoFile == false`), plus negative+failure, confirmed negative, invalid kind, thrown read failure, and a mixed email.
- Full app-hosted unit target (`-only-testing:PaperloftKitTests`, warnings as errors): 107 XCTest + 113 Swift Testing = **220 PASS**, 0 failures, 0 warning/error lines. `build/RoutingRepairUnit.xcresult`, `build/routing-repair-unit.log`. GUI lock held and released.
- Direct model-free StatusTests with updated policy (financial ⇒ attachment only / 0 body renders; negative+error ⇒ body+attachment / 1 render) PASS against a freshly rebuilt kit: `build/routing-repair-status3.log`.
- Mutation check: pre-change routing restored temporarily ⇒ StatusTests traps at the routing assertion (`build/routing-repair-mutation.log`); fix restored.
- Independent read-only review: PASS, no correctness findings. Its nits were applied: an explicit `classificationUnavailable` assertion in StatusTests, and an updated BUGS.md note. It confirmed none of the changed files is in ACCEPTANCE.lock, there's no auto-file path, and the diagnostics projector still treats a selected candidate with `classificationError` as not usable.
- Local preflight 39 PASS / 1 WARN / 0 FAIL / 0 TFAIL / 15 MANUAL; protected pre-tag baseline PASS.

## Not claimed

No model accuracy change: classifier refusals persist and still count as failed diagnostics. When the body is suppressed it is no longer read, so a refusal on a body that is no longer read can't be counted. No system80 rerun, full CI, native UI regression or formal gate.
