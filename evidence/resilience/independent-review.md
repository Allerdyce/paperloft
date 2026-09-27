# Independent resilience component review

Scoped local component PASS at source commit `23bd3cc` (base `db1a3f3`). This is not a P3/P6 gate or full AC-09 pass.

Reviewed the three new AppModelResilienceTests and traced the real AppModel intake, ReceiptEngine and recognition paths. Tests do not mock the recognizer or alter product behavior. Five generated invalid documents reach distinct actionable failure messages, retain their original SHA256, cannot be filed, and survive model reconstruction with persisted status/messages. The missing-library and invalid-bookmark cases now start with a populated persisted inbox and verify byte preservation plus the previous item/message; startup reports recovery action and releases busy state. No blocking source-review findings remain.

Independent fresh strict Debug clean build and targeted run passed all 3 tests, 0 failures, in 0.608 seconds: `build/ResilienceIndependent.xcresult`, `build/resilience-independent.log`. Command used the PaperloftApp scheme, fresh `build/ResilienceIndependentDerivedData`, `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`, and `-only-testing:PaperloftKitTests/AppModelResilienceTests`. This targeted component run is not full CI and does not replace any suite.

The build log contains no compiler `warning:` or `error:` diagnostics. It does contain an Xcode-internal DVTAssertions launch diagnostic (“called without a completion handler”), before test execution, and the expected invalid-bookmark diagnostic. Accordingly this report does not claim a universally warning-free runtime log.

Local preflight passed 38 checks with 1 WARN, 0 FAIL and 0 TFAIL (`build/resilience-review-preflight.log`). Protected baseline/hash checks passed (`build/resilience-review-baseline.log`); formal acceptance tag remains deferred. No product, test, protected fixture, or private-sample files were changed/read by this review. Only evidence was written.

Limits: model reconstruction is not process relaunch; malformed bookmark bytes are not a real stale security-scoped grant. Tests cover invalid-input pre-extraction rejection, not successful Vision/model inference. They do not prove visible UI messages, external sandbox access, non-receipt behavior, crash recovery, or responsiveness acceptance. The 20-second test ceiling is a stall bound, not AC-10 performance evidence. Distribution, uploads and release remain blocked.
