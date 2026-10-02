# Lessons

- Native Terminal preflight is authoritative for machine settings this restricted chat cannot observe.
- Preview Computer Use selection timed out without a document; opening the kit image through Finder made selection and screenshots succeed.
- ChatGPT cannot inspect its own UI through Computer Use; app preferences need manual confirmation.
- Use project-local package and module caches when possible. SwiftPM CLI still fails nested sandbox startup in this chat.
- Xcode UI opened the native project and completed its first Debug build successfully. This is not a CI or acceptance pass.

- Effective chat Full Access resolved SwiftPM sandbox failures. The custom package-cache option independently hid the local package; removing it restored CLI builds.
- Do not infer that unrelated windows in XCTest interruption logs prove a permission prompt is the cause; inspect the hit-point failure itself.

- XCTest macOS text content is exposed through value; wait for foreground state before clicking.
- App Intents metadata warnings are outside Swift warnings-as-errors; scan complete build logs too.
- A clean checkout caught reproducibility requirements independently of cached builds.
- Privacy checks must enforce absence of Package.resolved, not merely inspect current dependencies.
- Local readiness and formal distribution gates are separate under the owner-approved exception.

- P1 took longest in repeated on-device evaluations; stream progress and preserve exact revision IDs.
- Optional generated fields returned incomplete records; required fields with explicit unknown values made the pipeline reliable.
- Fixture layout diversity needed one independent fix cycle: fonts and widths were not distinct document structures.
- A visual layout inventory before generating the full corpus would have caught that problem earlier.
- The revised generator uses structural templates and merchant-appropriate content; accepted fixtures are now immutable.

- P2 spent most time in complete on-device regressions and independent fresh-set checks.
- The first private generator failed its own label audit; retain that evidence and repair evaluation before changing product code.
- Document type needed three fix cycles: broad guidance perturbed totals, then separate classification could refuse.
- Isolate field tasks and retain valid partial output with explicit diagnostics and mandatory review.
- Coverage needs retained instrumented binaries: use an isolated test build directory alongside ordinary Release builds.

- macOS open can reactivate an old running process after its on-disk app was rebuilt. Inspect running paths, gracefully quit project copies, explicitly launch the exact rebuilt binary, and verify the new PID/path before telling the owner it is current.
- Functional UX changes are not a visual redesign. Compare a populated window directly with the owner's reference; verify spacing, row surfaces, icons, filters and actions in both appearances.

- Real-world saved emails expose source-grounding and OCR failures absent from synthetic fixtures. Keep private evidence local, distinguish import success from field accuracy, and flag unsupported values rather than silently accepting them.

- A standalone WebKit renderer pass does not prove it can start in App Sandbox; test the native app before claiming body import works.
- Preserve the no-network entitlement when a local rendering service fails; native selectable PDF text can provide a bounded fallback with an explicit implementation deviation.
- Mail transport headers belong in the exported source context, not in confident receipt extraction; persist provenance when using them as missing-field hints.
- Email candidate policy changes require matching unlocked UI assertions; retain frozen acceptance tests and record the policy source.
- Treat Message-ID persistence as a committed-delivery transaction, not an eager seen-ID set; failed imports must remain retryable.

- Scripts that link prebuilt objects via `swift build --show-bin-path` must build first; a stale kit object silently tested old engine code.
- URL.resourceValues caches per URL instance; bound file reads by uncached stat plus the actual mapped/read length.
- The Xcode macOS UI-test runner is sandboxed by its standard entitlements; URL-backed IntentFile results failed there on sandbox-extension consumption, while bounded Data-backed results pass.
- A mutation check (temporarily restoring old code) is a cheap way to prove new regression tests discriminate.
- Integrate isolated components in a fresh worktree from the current root; preserve cosmetic root dirt via a saved patch and verify semantic equality.

- Check ACCEPTANCE.lock before editing any existing test file; add new test files instead. An edit to the frozen ExtractionTests.swift was caught and reverted before commit.
- Capture native FoundationModels error descriptions: "guardrailViolation" versus "refusal" pointed at the output rather than the input.
- Probe model behaviour with new, single-use synthetic inputs and disjoint arms; that respects no-retry/no-resubmission rules and still isolates causes.
- A bare enum response ("bill") can trip the output guardrail on benign text; changing the response shape (label plus heading) avoided it without touching guardrails.
- The Settings audit and live UI runs need a clear screen: the Claude window and stray app instances can cover test targets.
- XCUI reads a SwiftUI `Text` that has an accessibility identifier through `value`, not `label`. An assertion over `.label` compares empty strings and passes without testing anything; read `value` (or fall back to it).
- The UI-test Inbox and preferences persist across runs, and stub documents all share the vendor "Sample merchant". Identify documents by row or identifier, and have tests undo what they add (e.g. categories).
- Accessibility audits run right after a section switch catch toolbar animations and flag the window title. Wait for the new screen to settle before auditing. At 10 pt, captions trip the contrast heuristic; use callout.
- A SwiftUI menu command's `.disabled(...)` state can stay stale after launch, so its shortcut silently does nothing. Keep commands enabled and let the model explain, or queue the request until it's ready.
- XCUI reports the main window as "Disabled" even in passing runs. Don't gate a test on a window's `enabled` value.
- Wrapping text in List rows inside an HSplitView can feed back into split-view layout and raise AppKit's "Update Constraints in Window pass" exception. Keep row text single-line when row height would depend on pane width.
- Features that change persisted state (for example Undo returning documents to the Inbox) change what the next UI test launches into. Rerun the full suite in order, not just the new test.
- Load Development Receipts adds documents one at a time. Tests that count rows, pick a filter or open a menu right after it must wait for the Inbox to settle (`waitForInboxToSettle()`: Processing at 0 and the All count steady).
- Choosing Load Development Receipts before startup finishes is refused as busy ("Wait for the current operation…"). Create the sample library through Settings first, which waits for startup.
- When many unrelated UI tests fail at once with "Not hittable", look at the last frame of the screen recording before changing tests. On 2026-10-01 a macOS password prompt for a Claude app update covered the window; agents must not answer it.
- The release checker and privacy script default to `build/DerivedData/...` in the checkout you run them from. CI in a worktree leaves the main checkout's Release build stale, so pass the fresh app path explicitly. An AC-14 "pass" was briefly reported from a stale build.
- Background computer-use tools can't open the menu bar extra (a status item, maybe hidden by the notch). `MenuBarExtraTests` captures its panel as a Dialog element, without the rest of the screen, for design reviews.
- Before changing an element the critic marks below 4, check whether it came from the owner's reference design (REPORT.md 2026-09-27) or a locked test. If so, it's a PROPOSALS item, not a silent change.
- A SwiftUI view keyed with `.id(item.id)` directly inside an `HSplitView` replaces the split pane on every change and loses the divider position. Key a child inside one stable pane instead.
- The verifier fails any launch-argument check in product code that SPEC 6.7 doesn't list, even Debug/QA-only ones. Put test controls in a Debug menu (Debug/QA builds) instead, and keep `-PaperloftStoreMock` to exactly `YES`.
- UI-test mode creates a practice library at launch, so onboarding is unreachable there. Debug › Reset to First Launch leaves a one-launch request that skips it.
- XCUI drags on window edges and Accessibility-API resizes from the test runner don't resize windows on this Mac. A Debug menu command sizes the window for screenshots.
- After XCUI terminates the app, macOS may relaunch it with no window. Every test that relaunches needs the Window › Paperloft Receipts fallback.
