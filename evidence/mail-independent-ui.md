# Independent Mail UI diagnostic

Root fresh build at bfa8fae plus new diagnostic tests: build/IndependentMailUI.xcresult. Local EML file-picker/body/attachment/relaunch/original-preservation test PASS. Two new tests FAIL; no full Mail promise component pass.

Menu-bar test closes the main window, finds/clicks the actual menubar.status and menubar.open controls, then no main window appears within10seconds. The next drag test fails its initial toolbar wait after relaunch, so its drag has not executed. Preserve this as an unresolved reopening/setup issue rather than claiming promise-delivery failure. Log build/independent-mail-ui.log. Fresh compile succeeded; logs also include Xcode internal diagnostics, so no blanket zero-runtime-warning claim.

The synthetic provider is reproducibly built with scripts/build_mail_promise_probe.sh (ad-hoc local signature only), public AppKit and no product hook. Tests use public XCUITest cross-app coordinate gestures. No Mail account or mailbox access.

Root ended its own windowless app process and released GUI lock. Product repair/recheck required before acceptance; no tests skipped or thresholds relaxed.

## Mail branch follow-up (2026-09-27)

Merged root diagnostic revision 05d3a00 normally. All following runs used the same strict Debug build settings and unchanged expected controls/timeouts. Three attempted product repairs were compiled and tested, then **fully reverted** because none repaired initial launch:

1. Resolve OpenWindowAction before the hosting boundary plus `.defaultLaunchBehavior(.presented)`: MailReopen1.xcresult and MailReopenTree.xcresult fail at the initial toolbar wait.
2. Add `.restorationBehavior(.disabled)`: MailReopen2.xcresult fails at the same initial toolbar wait.
3. Propagate the representable's context.environment into the nested NSHostingView: MailReopen3.xcresult fails at the same initial toolbar wait.

Full failure accessibility trees contain menus/status but no window, so this is not merely a changed main-window identifier. These experiments **did not reach the Open Inbox click** and cannot establish whether any one would repair that separate action. Product source is restored to 05d3a00.

A separate `testWindowMenuReopensWindowlessAppDiagnostic` uses the standard Window > Paperloft Receipts menu. Its first query was ambiguous because the global menu-item query matched duplicates; scoping it to the Window menu fixes the test query. MailWindowMenuDiagnostic2.xcresult **PASS**, 6.382 seconds: the native Window menu opens the real toolbar. No product hook or fallback was added to existing tests. This demonstrates live scene creation but does not establish launch or menu-bar recovery.

Recovered-baseline rerun `build/MailRecoveredBaseline.xcresult`: **FAIL, 3 tests**. File-picker (16.624s), menu-bar (17.829s), and promised-file drag (17.501s) all fail their initial toolbar wait after launch. The menu action and drag are not reached. Thus live Window-menu recovery does not persist across termination/relaunch; earlier independent file-picker passes remain historical evidence only. No current end-to-end pass, promise component acceptance or full P4 acceptance is claimed. Builds compile with warnings-as-errors; Xcode runtime logarchive diagnostics still occur, so no blanket zero-runtime-warning claim. All local bundles/logs are retained under build; no mailbox access.

Process-path caveat: post-run process inventory shows no Paperloft app/test runner remaining. Earlier live inventory showed only the intended mail-worktree Debug executable, but that observation followed CUA selection and does not prove the final baseline XCTest PID path. Existing test logs identify bundle ID and PID only. Added public NSWorkspace bundle/executable-path logging to the diagnostic test setup for a future run; this logging has not yet been exercised. Same-bundle-ID copies remain a diagnostic possibility, not an established cause.

## Isolated Open Inbox action diagnostic (2026-09-27)

`testWindowMenuPrimedMenuBarOpenInboxDiagnostic`, `build/MailPrimedMenuDiagnostic.xcresult`, **FAIL** (29.956 seconds). Exact public NSWorkspace output confirms PID16782 used `/Users/builder/Factory/paperloft-mail/build/MailIntegrationDebug/Build/Products/Debug/Paperloft Receipts.app`; a concurrent process inventory independently confirms the matching executable and test arguments, with no other Paperloft executable shown.

The separate diagnostic successfully opens the main window through standard Window > Paperloft Receipts, verifies toolbar and `main`, closes it and verifies absence, finds/clicks `menubar.status`, then finds/clicks `menubar.open`. No main window appears within10seconds. The complete post-click accessibility tree again contains no window under another identifier. XCTest logs report a fallback to the Open Inbox element center; thus this establishes failure of the real automated interaction, without claiming independent instrumentation of the SwiftUI action closure. It now reproduces the original failure independently of initial restored-window launch. Log: `build/mail-primed-menu.log`.

No product code changed or further repairs attempted. Existing acceptance tests remain unchanged; this is an additional diagnostic, not a phase gate. GUI released directly to mail_intake afterward. The new exact-path logging compiled and ran successfully; the earlier unexercised-logging caveat above applies only to its historical checkpoint.

## Captured OpenWindowAction retest on isolated failure (2026-09-27)

At root request, evaluated the previously unexercised narrow action-capture idea against the now-isolated interaction: resolve `openWindow` in MenuBarInbox.body before constructing MailDropContainer content, pass that local value to both buttons. No launch behavior, environment forwarding, hooks or test assertions changed.

`build/MailCapturedWindowAction.xcresult`: **FAIL**, 30.606seconds at the same main-window reopen assertion. Public process logging confirms intended mail-worktree Debug app PID19242. The standard Window menu priming and close succeeded, actual status/Open Inbox clicks were reached, and main did not appear within10seconds. Strict Debug compile passed. The product change was fully reverted; this evaluates the action capture on the actual failing behavior, unlike the earlier initial-launch failures. No further repair attempted; no promised-file drag executed. Log `build/mail-captured-window-action.log`. GUI/quiet window released to intents afterward.
